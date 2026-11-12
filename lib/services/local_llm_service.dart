import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';

/// A downloadable on-device AI model.
class LocalModel {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final String fileName;
  final int approxSizeBytes;
  final bool heavy;

  const LocalModel({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.fileName,
    required this.approxSizeBytes,
    required this.heavy,
  });

  String get sizeLabel {
    final gb = approxSizeBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    return '${(approxSizeBytes / (1024 * 1024)).round()} MB';
  }
}

/// Manages downloadable on-device AI models (light / heavy) and runs them
/// fully offline through the native MediaPipe GenAI bridge.
///
/// Flow:
///   1. User downloads a model from the Model Manager (streamed with progress)
///   2. File is stored in the app's documents directory (no permissions needed)
///   3. [loadActiveModel] loads it into the native runtime
///   4. When SettingsService.offlineAiMode is ON, [AiService] routes chat
///      generation to [generate] — 100% on-device, no data leaves the phone.
class LocalLlmService {
  LocalLlmService._();
  static final LocalLlmService instance = LocalLlmService._();

  static const MethodChannel _channel = MethodChannel('com.privateagent/local_llm');

  static const String _modelsDirName = 'geny_models';
  static const String _selectedModelKey = 'local_llm_selected_model';

  /// Built-in catalog: light vs heavy on-device models.
  static const List<LocalModel> catalog = [
    LocalModel(
      id: 'gemma3-1b',
      name: 'Gemma 3 1B — Light',
      description:
          'Fast on-device model. Great for chat, translations and quick answers in all Geny languages. Recommended for most phones.',
      downloadUrl:
          'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
      fileName: 'gemma3-1b-it-int4.task',
      approxSizeBytes: 556 * 1024 * 1024,
      heavy: false,
    ),
    LocalModel(
      id: 'gemma3-4b',
      name: 'Gemma 3 4B — Heavy',
      description:
          'Stronger reasoning and richer answers, but slower and needs a flagship phone with ~6 GB free RAM/storage.',
      downloadUrl:
          'https://huggingface.co/litert-community/Gemma3-4B-IT/resolve/main/gemma3-4b-it-int4.task',
      fileName: 'gemma3-4b-it-int4.task',
      approxSizeBytes: 2480 * 1024 * 1024,
      heavy: true,
    ),
    LocalModel(
      id: 'custom',
      name: 'Custom model (.task)',
      description:
          'Advanced: point Geny to any MediaPipe-compatible .task model URL (e.g. from Hugging Face). Set the URL in the field below.',
      downloadUrl: '',
      fileName: 'custom-model.task',
      approxSizeBytes: 0,
      heavy: true,
    ),
  ];

  // Download state (single download at a time)
  bool _downloading = false;
  String? _downloadingModelId;
  double _progress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  http.Client? _downloadClient;

  bool get isDownloading => _downloading;
  String? get downloadingModelId => _downloadingModelId;
  double get progress => _progress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;

  String? _customUrl;
  String? get customUrl => _customUrl;

  bool _ready = false;
  bool get isReady => _ready;
  String? _loadedPath;

  final ValueNotifier<int> _stateTick = ValueNotifier<int>(0);
  ValueNotifier<int> get stateTick => _stateTick;

  LocalModel modelById(String id) => catalog.firstWhere(
        (m) => m.id == id,
        orElse: () => catalog.first,
      );

  Future<Directory> _modelsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_modelsDirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customUrl = prefs.getString('local_llm_custom_url');
    // If a model was loaded in a previous app run, reload it.
    final selected = prefs.getString(_selectedModelKey);
    if (selected != null && selected.isNotEmpty) {
      final file = await installedFileFor(selected);
      if (file != null && file.existsSync()) {
        await loadActiveModel();
      }
    }
  }

  /// Returns the downloaded file for a model id, or null if not present.
  Future<File?> installedFileFor(String modelId) async {
    try {
      final dir = await _modelsDir();
      if (modelId == 'custom') {
        final customName = SettingsService.instance.customModelFileName;
        if (customName.isEmpty) return null;
        final f = File('${dir.path}/$customName');
        return f.existsSync() ? f : null;
      }
      final m = modelById(modelId);
      final f = File('${dir.path}/${m.fileName}');
      return f.existsSync() ? f : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> installedModelId() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_selectedModelKey);
    if (selected != null && await installedFileFor(selected) != null) {
      return selected;
    }
    // Fallback: scan for any known model file
    for (final m in catalog) {
      if (m.id == 'custom') continue;
      if (await installedFileFor(m.id) != null) return m.id;
    }
    return null;
  }

  Future<void> setCustomUrl(String url) async {
    _customUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_llm_custom_url', _customUrl ?? '');
    _stateTick.value++;
  }

  Future<void> selectModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelId);
    _stateTick.value++;
  }

  /// Streams a model download to disk with progress reporting.
  Future<bool> downloadModel(String modelId, {String? customUrl}) async {
    if (_downloading) return false;
    final model = modelById(modelId);
    final url = modelId == 'custom' ? (customUrl ?? _customUrl ?? '') : model.downloadUrl;
    if (url.isEmpty) {
      throw Exception('No download URL configured for this model.');
    }

    _downloading = true;
    _downloadingModelId = modelId;
    _progress = 0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _stateTick.value++;
    _downloadClient = http.Client();

    try {
      final dir = await _modelsDir();
      final fileName = modelId == 'custom'
          ? (SettingsService.instance.customModelFileName.isNotEmpty
              ? SettingsService.instance.customModelFileName
              : 'custom-model-${DateTime.now().millisecondsSinceEpoch}.task')
          : model.fileName;
      final target = File('${dir.path}/$fileName');
      final sink = target.openWrite();

      final request = http.Request('GET', Uri.parse(url));
      final response = await _downloadClient!.send(request).timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw Exception('Download timed out connecting to server.'),
          );

      if (response.statusCode != 200) {
        await sink.close();
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      _totalBytes = response.contentLength ?? 0;
      int received = 0;
      int lastTick = 0;

      await for (final chunk in response.stream) {
        received += chunk.length;
        _downloadedBytes = received;
        if (_totalBytes > 0) {
          _progress = received / _totalBytes;
        } else {
          // Unknown total: fake a creeping progress so the UI stays alive
          _progress = (received % (200 * 1024 * 1024)) / (200 * 1024 * 1024) * 0.99;
        }
        if (received - lastTick > 512 * 1024) {
          lastTick = received;
          _stateTick.value++;
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      _progress = 1;
      _stateTick.value++;
      await selectModel(modelId);
      // Auto-load right after download for a smooth "download and use" flow.
      await loadActiveModel();
      return true;
    } finally {
      _downloading = false;
      _downloadingModelId = null;
      _downloadClient?.close();
      _downloadClient = null;
      _stateTick.value++;
    }
  }

  void cancelDownload() {
    _downloadClient?.close();
    _downloadClient = null;
  }

  Future<void> deleteModel(String modelId) async {
    final f = await installedFileFor(modelId);
    if (f != null && f.existsSync()) {
      await f.delete();
    }
    if (_loadedPath == f?.path) {
      unload();
    }
    _stateTick.value++;
  }

  /// Loads the currently selected (downloaded) model into the native engine.
  Future<bool> loadActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_selectedModelKey);
    if (selected == null) return false;
    final file = await installedFileFor(selected);
    if (file == null) return false;
    try {
      final res = await _channel
          .invokeMethod<Map>('loadModel', {
        'path': file.path,
        'maxTokens': SettingsService.instance.maxTokensLocalModel,
        'temperature': 0.7,
      })
          .timeout(const Duration(minutes: 3));
      final ok = res?['ok'] == true;
      _ready = ok;
      _loadedPath = ok ? file.path : null;
      _stateTick.value++;
      return ok;
    } catch (e) {
      debugPrint('[LocalLlm] load failed: $e');
      _ready = false;
      _stateTick.value++;
      return false;
    }
  }

  void unload() {
    try {
      _channel.invokeMethod('unload');
    } catch (_) {}
    _ready = false;
    _loadedPath = null;
    _stateTick.value++;
  }

  /// Runs a full generation with the loaded on-device model.
  Future<String> generate(String prompt, {Duration timeout = const Duration(minutes: 3)}) async {
    if (!_ready) throw Exception('Offline model not loaded.');
    try {
      final res = await _channel
          .invokeMethod<Map>('generate', {'prompt': prompt})
          .timeout(timeout);
      if (res?['ok'] == true) {
        return (res?['text'] ?? '').toString();
      }
      throw Exception((res?['error'] ?? 'generation failed').toString());
    } on TimeoutException {
      throw Exception('The on-device model took too long to answer.');
    }
  }

  /// Streams generation chunks (typewriter effect for offline chat).
  Stream<String> generateStream(String prompt) async* {
    if (!_ready) throw Exception('Offline model not loaded.');
    final completer = Completer<void>();
    final chunks = <String>[];
    var listenerAttached = false;
    late final StreamController<String> controller;

    void handleEvent(Map data) {
      if (data['error'] != null) {
        if (!completer.isCompleted) completer.complete();
        controller.close();
        return;
      }
      final partial = (data['partial'] ?? '').toString();
      final done = data['done'] == true;
      if (partial.isNotEmpty) chunks.add(partial);
      controller.add(partial);
      if (done && !completer.isCompleted) completer.complete();
    }

    controller = StreamController<String>(
      onListen: () async {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onStream') {
            handleEvent(Map<String, dynamic>.from(call.arguments as Map));
          } else if (call.method == 'onStreamError') {
            final args = call.arguments as Map?;
            debugPrint('[LocalLlm] stream error: ${args?['error']}');
            if (!completer.isCompleted) completer.complete();
            await controller.close();
          }
        });
        listenerAttached = true;
        try {
          await _channel.invokeMethod('generateStream', {'prompt': prompt});
        } catch (e) {
          debugPrint('[LocalLlm] generateStream failed: $e');
          if (!completer.isCompleted) completer.complete();
          await controller.close();
        }
      },
      onCancel: () {
        if (listenerAttached) {
          _channel.setMethodCallHandler(null);
        }
      },
    );

    await for (final chunk in controller.stream) {
      yield chunk;
      // End when native signals done
      if (completer.isCompleted && chunks.isNotEmpty) break;
    }
    if (!completer.isCompleted) await completer.future;
  }

  /// Free disk space in bytes on the internal storage, best effort.
  /// Returns -1 when unknown (UI hides the label in that case).
  Future<int> freeDiskSpace() async {
    // dart:io does not expose free space portably — report unknown.
    return -1;
  }
}
