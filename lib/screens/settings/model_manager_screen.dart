import 'package:flutter/material.dart';

import '../../i18n/geny_i18n.dart';
import '../../services/local_llm_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';

/// Offline AI Model Manager — download light/heavy on-device models and
/// switch Geny to 100% offline inference.
class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final _local = LocalLlmService.instance;
  final _settings = SettingsService.instance;
  final _customUrlCtrl = TextEditingController();
  String? _installedId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _customUrlCtrl.text = _local.customUrl ?? '';
    _refresh();
    _local.stateTick.addListener(_refresh);
  }

  @override
  void dispose() {
    _local.stateTick.removeListener(_refresh);
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = await _local.installedModelId();
    if (mounted) {
      setState(() {
        _installedId = id;
        _loading = false;
      });
    }
  }

  Future<void> _download(String modelId) async {
    setState(() => _loading = true);
    try {
      final ok = await _local.downloadModel(
        modelId,
        customUrl: modelId == 'custom' ? _customUrlCtrl.text.trim() : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Model downloaded and loaded. Offline mode ready!'
              : 'Download finished but the model did not load.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
    await _refresh();
  }

  Future<void> _delete(String modelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete model?'),
        content: const Text(
            'The downloaded model file will be removed from your device. You can download it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t(S.cancel))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _local.deleteModel(modelId);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offlineMode = _settings.offlineAiMode;
    final downloadingId = _local.downloadingModelId;

    return Scaffold(
      appBar: AppBar(title: Text(S.t(S.offlineModels))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline mode switch card
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.offline_bolt_rounded,
                color: offlineMode ? AppTheme.success : scheme.onSurfaceVariant,
              ),
              title: const Text('100% Offline Mode',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                _local.isReady
                    ? 'Geny runs on your device. Nothing leaves your phone.'
                    : 'Download a model below, then switch offline mode on.',
              ),
              value: offlineMode,
              onChanged: _local.isReady
                  ? (v) async => await _settings.setOfflineAiMode(v)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (_local.isReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Model loaded and ready (on-device inference active).',
                      style: TextStyle(color: AppTheme.success, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          // Model cards
          for (final model in LocalLlmService.catalog)
            _ModelCard(
              model: model,
              installed: _installedId == model.id,
              selected: offlineMode && _installedId == model.id,
              downloading: downloadingId == model.id,
              progress: downloadingId == model.id ? _local.progress : 0,
              downloadedBytes:
                  downloadingId == model.id ? _local.downloadedBytes : 0,
              totalBytes: downloadingId == model.id ? _local.totalBytes : 0,
              isBusy: _loading,
              onDownload: () => _download(model.id),
              onDelete: () => _delete(model.id),
              customUrlCtrl: model.id == 'custom' ? _customUrlCtrl : null,
              onCustomUrlSaved: model.id == 'custom'
                  ? () => _local.setCustomUrl(_customUrlCtrl.text)
                  : null,
            ),
          const SizedBox(height: 12),
          Card(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(children: [
                    Icon(Icons.lock_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Private by design',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  SizedBox(height: 6),
                  Text(
                    'Once a model is downloaded, everything — chat, reasoning, '
                    'translations — runs on your phone. No internet, no server, '
                    'no data collection. Models are provided by the open-source '
                    'LiteRT community (Google Gemma).',
                    style: TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final LocalModel model;
  final bool installed;
  final bool selected;
  final bool downloading;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final TextEditingController? customUrlCtrl;
  final VoidCallback? onCustomUrlSaved;

  const _ModelCard({
    required this.model,
    required this.installed,
    required this.selected,
    required this.downloading,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.isBusy,
    required this.onDownload,
    required this.onDelete,
    this.customUrlCtrl,
    this.onCustomUrlSaved,
  });

  String _fmtBytes(int b) {
    if (b >= 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(b / (1024 * 1024)).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: model.heavy
                        ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.indigo])
                        : AppTheme.genieGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    model.heavy ? Icons.psychology_rounded : Icons.bolt_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(model.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15.5),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (installed) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 17),
                        ],
                      ]),
                      Text(
                        model.id == 'custom'
                            ? 'Advanced — bring your own model'
                            : '${model.sizeLabel} · ${model.heavy ? "heavy" : "light"}',
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(model.description,
                style: const TextStyle(fontSize: 13, height: 1.45)),
            if (customUrlCtrl != null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: customUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Model URL (.task)',
                  hintText: 'https://huggingface.co/.../model-int4.task',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save_rounded),
                    onPressed: onCustomUrlSaved,
                  ),
                ),
              ),
            ],
            if (downloading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  minHeight: 8,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.fuchsia),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totalBytes > 0
                    ? '${_fmtBytes(downloadedBytes)} / ${_fmtBytes(totalBytes)}  (${(progress * 100).toStringAsFixed(0)}%)'
                    : 'Downloading… ${_fmtBytes(downloadedBytes)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (downloading)
                  OutlinedButton.icon(
                    onPressed: () => LocalLlmService.instance.cancelDownload(),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: Text(S.t(S.cancel)),
                  )
                else if (installed) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => LocalLlmService.instance.loadActiveModel(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Load'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppTheme.danger),
                    label: Text('Delete',
                        style: TextStyle(color: AppTheme.danger)),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: isBusy ? null : onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(model.id == 'custom'
                        ? 'Download custom model'
                        : 'Download ${model.sizeLabel}'),
                  ),
                const Spacer(),
                if (selected)
                  Chip(
                    avatar: const Icon(Icons.wifi_off_rounded,
                        size: 15, color: AppTheme.success),
                    label: const Text('ACTIVE OFFLINE', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppTheme.success.withValues(alpha: 0.12),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
