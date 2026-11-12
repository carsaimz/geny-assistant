import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ai_service.dart';

/// Structured inspection result from Geny Eye optical perception.
class VisionAnalysisResult {
  final String description;
  final String spokenSummary;
  final String? imagePath;
  final DateTime timestamp;
  final bool isSuccess;

  String get summary => description;

  const VisionAnalysisResult({
    required this.description,
    required this.spokenSummary,
    this.imagePath,
    required this.timestamp,
    this.isSuccess = true,
  });

  factory VisionAnalysisResult.failure(String message) => VisionAnalysisResult(
        description: message,
        spokenSummary: message,
        timestamp: DateTime.now(),
        isSuccess: false,
      );
}

/// 👁️ "Geny Eye" — Multimodal Camera & Optical Perception
///
/// Captures high-resolution optical snapshots via native camera or intent,
/// synthesizes visual telemetry through multimodal LLM inference, and
/// delivers articulate, conversational insights in Tony Stark's assistant style.
class VisionPerceptionService extends ChangeNotifier {
  VisionPerceptionService._();
  static final VisionPerceptionService instance = VisionPerceptionService._();

  static const _channel = MethodChannel('com.privateagent/accessibility');

  VisionAnalysisResult? _lastResult;
  VisionAnalysisResult? get lastResult => _lastResult;

  bool _isInspecting = false;
  bool get isInspecting => _isInspecting;

  /// Captures an optical snapshot using the device camera and analyzes it.
  Future<VisionAnalysisResult> inspectPhysicalEnvironment({String? query}) =>
      inspectOpticalSnapshot(customPrompt: query);

  /// [customPrompt] can specify what to look for (e.g. "read the total on this receipt", "identify this component").
  Future<VisionAnalysisResult> inspectOpticalSnapshot({
    String? customPrompt,
    String? mockBase64,
  }) async {
    _isInspecting = true;
    notifyListeners();

    try {
      String? base64Data = mockBase64;
      String? photoPath;

      if (base64Data == null) {
        // Call native camera capture
        final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('captureCameraPhoto');
        if (raw == null) {
          throw Exception('Optical sensor capture returned empty data.');
        }
        base64Data = raw['base64'] as String?;
        photoPath = raw['path'] as String?;
      }

      if (base64Data == null || base64Data.isEmpty) {
        throw Exception('Optical capture did not contain valid image bytes.');
      }

      final prompt = customPrompt?.trim().isNotEmpty == true
          ? customPrompt!
          : 'Inspect this image thoroughly. Identify key objects, text, errors, components, or documents, and summarize your observations in 2 to 3 natural sentences for the operator.';

      final analysis = await AiService.instance.completeMultimodal(
        prompt: prompt,
        base64Image: base64Data,
      );

      final result = VisionAnalysisResult(
        description: analysis,
        spokenSummary: analysis,
        imagePath: photoPath,
        timestamp: DateTime.now(),
        isSuccess: true,
      );

      _lastResult = result;
      _isInspecting = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('[VisionPerceptionService] Capture error: $e');
      final errorMsg = 'Optical sensor scan was interrupted: ${e.toString().replaceAll('Exception:', '').trim()}.';
      final result = VisionAnalysisResult.failure(errorMsg);
      _lastResult = result;
      _isInspecting = false;
      notifyListeners();
      return result;
    }
  }

  /// Manually set inspection result (useful for tests or simulated feeds)
  void setAnalysisResult(VisionAnalysisResult result) {
    _lastResult = result;
    notifyListeners();
  }
}
