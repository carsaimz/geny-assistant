import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/geny_i18n.dart';
import '../../services/edge_tts_service.dart';
import '../../services/settings_service.dart';
import '../../services/voice_catalog_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';

/// Voice & Language studio: assistant name, operator name, app language,
/// neural voice picker (female-first) and offline voice data downloads.
class VoiceLanguageScreen extends StatefulWidget {
  const VoiceLanguageScreen({super.key});

  @override
  State<VoiceLanguageScreen> createState() => _VoiceLanguageScreenState();
}

class _VoiceLanguageScreenState extends State<VoiceLanguageScreen> {
  final _settings = SettingsService.instance;
  late final TextEditingController _assistantNameCtrl;
  late final TextEditingController _operatorNameCtrl;

  @override
  void initState() {
    super.initState();
    _assistantNameCtrl = TextEditingController(text: _settings.genyName);
    _operatorNameCtrl = TextEditingController(text: _settings.operatorName);
  }

  @override
  void dispose() {
    _assistantNameCtrl.dispose();
    _operatorNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLanguage() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Choose Geny\'s language',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            for (final lang in GenyVoiceCatalog.languages)
              ListTile(
                leading: Text(lang.label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                title: Text(lang.englishName),
                trailing: lang.code == _settings.assistantLanguage
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppTheme.fuchsia)
                    : null,
                onTap: () => Navigator.pop(ctx, lang.code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != _settings.assistantLanguage) {
      await _settings.setAssistantLanguage(chosen);
      // Auto-switch to the language's female default voice.
      await _settings.setGenyNeuralVoice(GenyVoiceCatalog.language(chosen).defaultNeuralVoice);
      await VoiceService.instance.reconfigureVoice();
      if (mounted) setState(() {});
    }
  }

  Future<void> _previewVoice(String voiceId) async {
    final lang = GenyVoiceCatalog.language();
    final sample = switch (lang.code) {
      'pt' => 'Olá! Eu sou a Geny, sua assistente pessoal. Esta é a minha nova voz.',
      'fr' => 'Bonjour ! Je suis Geny, votre assistante personnelle. Voici ma nouvelle voix.',
      'es' => '¡Hola! Soy Geny, tu asistente personal. Esta es mi nueva voz.',
      _ => 'Hi! I\'m Geny, your personal assistant. This is my new voice.',
    };
    try {
      await VoiceService.instance.stopSpeaking();
      final played = await EdgeTtsService.instance.speak(sample, voice: voiceId);
      if (!played && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Neural preview unavailable offline — using the device voice instead.')));
        await VoiceService.instance.speak(sample);
      }
    } catch (_) {
      await VoiceService.instance.speak(sample);
    }
  }

  Future<void> _openSystemTtsSettings() async {
    bool ok = false;
    try {
      const ch = MethodChannel('com.privateagent/speech');
      ok = await ch.invokeMethod('openTtsSettings') == true;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'System voice settings opened — download the voice data pack for your language.'
            : 'Could not open system TTS settings on this device.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = GenyVoiceCatalog.language();

    return Scaffold(
      appBar: AppBar(title: const Text('Voice & Language')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.genieGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.face_retouching_natural_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Assistant identity',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _assistantNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assistant name',
                      hintText: 'Geny',
                      prefixIcon: Icon(Icons.auto_awesome_rounded),
                    ),
                    onSubmitted: (v) async {
                      await _settings.setGenyName(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _operatorNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your name (how Geny calls you)',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    onSubmitted: (v) async {
                      await _settings.setOperatorName(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.translate_rounded,
                  color: AppTheme.fuchsia),
              title: Text(S.t(S.language),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${lang.label} · ${lang.englishName}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickLanguage,
            ),
          ),
          const SizedBox(height: 12),

          // Neural voices for the selected language
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: AppTheme.fuchsia),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Neural voice (${lang.label})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15.5),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Ultra-realistic studio voices. Geny is female by default — pick any voice you like.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  ...lang.neuralVoices.map((v) {
                    final active = _settings.genyNeuralVoice == v.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        v.female
                            ? Icons.face_3_rounded
                            : Icons.face_6_rounded,
                        color: active
                            ? AppTheme.fuchsia
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(v.displayName,
                          style: const TextStyle(fontSize: 14.5)),
                      subtitle: Text(
                          '${v.female ? "female" : "male"} · ${v.locale}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Preview',
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          onPressed: () => _previewVoice(v.id),
                        ),
                        if (active)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.fuchsia)
                        else
                          Radio<String>(
                            value: v.id,
                            groupValue: _settings.genyNeuralVoice,
                            onChanged: (id) async {
                              if (id == null) return;
                              await _settings.setGenyNeuralVoice(id);
                              if (mounted) setState(() {});
                            },
                          ),
                      ]),
                      onTap: () async {
                        await _settings.setGenyNeuralVoice(v.id);
                        if (mounted) setState(() {});
                      },
                    );
                  }),
                  const Divider(height: 22),
                  // Offline (system) voices
                  Row(children: [
                    const Icon(Icons.download_for_offline_rounded,
                        color: AppTheme.cyan),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Offline voices',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Download system voice & speech data packs so Geny can listen and speak without internet.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _openSystemTtsSettings,
                      icon: const Icon(Icons.settings_voice_rounded, size: 18),
                      label: const Text('Download voice data'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Offline TTS profile
          Card(
            child: ListTile(
              leading: const Icon(Icons.spatial_audio_off_rounded,
                  color: AppTheme.cyan),
              title: const Text('Offline voice style',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Used when neural voices are off or internet is unavailable.'),
              trailing: DropdownButton<String>(
                value: ['femaleWarm', 'femaleBright', 'maleCalm', 'maleDeep']
                        .contains(_settings.genyVoice)
                    ? _settings.genyVoice
                    : 'femaleWarm',
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'femaleWarm', child: Text('Female · warm')),
                  DropdownMenuItem(value: 'femaleBright', child: Text('Female · bright')),
                  DropdownMenuItem(value: 'maleCalm', child: Text('Male · calm')),
                  DropdownMenuItem(value: 'maleDeep', child: Text('Male · deep')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await _settings.setGenyVoice(v);
                  await VoiceService.instance.reconfigureVoice(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
