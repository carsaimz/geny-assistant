import 'dart:ui';
import 'package:flutter/material.dart';

import '../../services/personality_service.dart';
import '../../services/settings_service.dart';
import '../../services/telegram_service.dart';
import '../../widgets/glass_widgets.dart';
import 'geny_settings_screen.dart';
import 'model_manager_screen.dart';
import 'permissions_screen.dart';
import 'voice_language_screen.dart';

/// Next-Generation Liquid Glass Settings Screen.
/// Clean, executive grouped hierarchy with frosted glass translucency and modern controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  final _telegram = TelegramService.instance;

  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _tokenController;
  late final TextEditingController _chatsController;

  bool _obscureKey = true;
  bool _obscureToken = true;

  String _lastSyncedProvider = '';

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: _settings.baseUrl);
    _apiKeyController = TextEditingController(text: _settings.apiKey);
    _modelController = TextEditingController(text: _settings.model);
    _tokenController = TextEditingController(text: _settings.telegramToken);
    _chatsController =
        TextEditingController(text: _settings.telegramAllowedChats.join(', '));
    _lastSyncedProvider = _settings.provider;

    PersonalityService.instance.init().then((_) {
      if (mounted) setState(() {});
    });

    for (final c in [
      _baseUrlController,
      _apiKeyController,
      _modelController,
    ]) {
      c.addListener(_onAiFieldChanged);
    }
    for (final c in [
      _tokenController,
      _chatsController,
    ]) {
      c.addListener(_onTelegramFieldChanged);
    }
    _settings.addListener(_onSettingsChanged);
    _telegram.addListener(_onTelegramChanged);
    PersonalityService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _telegram.removeListener(_onTelegramChanged);
    PersonalityService.instance.removeListener(_onServiceChanged);
    for (final c in [
      _baseUrlController,
      _apiKeyController,
      _modelController,
    ]) {
      c.removeListener(_onAiFieldChanged);
    }
    for (final c in [
      _tokenController,
      _chatsController,
    ]) {
      c.removeListener(_onTelegramFieldChanged);
    }
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _tokenController.dispose();
    _chatsController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (_settings.provider != _lastSyncedProvider) {
      _lastSyncedProvider = _settings.provider;
      _baseUrlController.text = _settings.baseUrl;
      _modelController.text = _settings.model;
    }
    setState(() {});
  }

  void _onTelegramChanged() {
    if (mounted) setState(() {});
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _onAiFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onTelegramFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _aiDirty =>
      _baseUrlController.text.trim() != _settings.baseUrl ||
      _apiKeyController.text.trim() != _settings.apiKey ||
      _modelController.text.trim() != _settings.model;

  bool get _telegramDirty =>
      _tokenController.text.trim() != _settings.telegramToken ||
      _chatsController.text.trim() != _settings.telegramAllowedChats.join(', ');

  Future<void> _saveTelegramSettings() async {
    await _settings.setTelegramToken(_tokenController.text.trim());
    await _settings.setTelegramAllowedChats(
      _chatsController.text
          .split(RegExp(r'[,\s]+'))
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    if (_settings.telegramEnabled) {
      await _telegram.restart();
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
              SizedBox(width: 10),
              Text('Telegram configuration saved & reloaded'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  Future<void> _saveAiSettings() async {
    await _settings.setBaseUrl(_baseUrlController.text);
    await _settings.setApiKey(_apiKeyController.text);
    await _settings.setModel(_modelController.text);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
              SizedBox(width: 10),
              Text('AI provider settings saved successfully'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x60090E17)
                  : const Color(0x60F1F5F9),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: 40,
            right: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _sectionHeader(
                  icon: Icons.psychology_rounded,
                  title: 'AI Intelligence Engine',
                  color: const Color(0xFF818CF8),
                ),
                _aiProviderCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.shield_rounded,
                  title: 'Autonomous G.E.N.Y. Core',
                  color: const Color(0xFF00E5FF),
                ),
                _genyCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.security_rounded,
                  title: 'Permissions & Telemetry Inboxes',
                  color: const Color(0xFF38BDF8),
                ),
                _permissionsCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.smart_toy_rounded,
                  title: 'Device Automation Agent',
                  color: const Color(0xFFA78BFA),
                ),
                _agentCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.send_rounded,
                  title: 'Telegram Remote Bridge',
                  color: const Color(0xFF0EA5E9),
                ),
                _telegramCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Voice & Language',
                  color: const Color(0xFFD946EF),
                ),
                _voiceLanguageCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.offline_bolt_rounded,
                  title: 'Offline AI Models',
                  color: const Color(0xFF22D3EE),
                ),
                _offlineModelsCard(),
                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.palette_outlined,
                  title: 'Appearance & Visual Theme',
                  color: const Color(0xFFF472B6),
                ),
                _appearanceCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiProviderCard() {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model Provider Preset',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in SettingsService.providers.entries)
                GlassPill(
                  label: entry.value.label,
                  isSelected: _settings.provider == entry.key,
                  onTap: () => _settings.setProvider(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GlassTextField(
            controller: _baseUrlController,
            labelText: 'Base URL',
            hintText: 'https://api.example.com/v1',
            prefixIcon: const Icon(Icons.link_rounded, size: 20),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _apiKeyController,
            labelText: 'API key',
            obscureText: _obscureKey,
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _modelController,
            labelText: 'Model',
            hintText: 'deepseek-chat',
            prefixIcon: const Icon(Icons.psychology_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          // Save button with liquid glass styling
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _aiDirty ? _saveAiSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _aiDirty
                    ? const Color(0xFF6366F1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _aiDirty ? 4 : 0,
              ),
              icon: Icon(
                _aiDirty ? Icons.save_rounded : Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                _aiDirty ? 'Save changes' : 'Saved',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
          if (_aiDirty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Unsaved changes — tap Save to persist your API key and model.',
                  style: TextStyle(fontSize: 11.5, color: Colors.amber),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          GlassSwitchTile(
            title: 'Send system prompt',
            subtitle: 'Recommended — teaches model precise phone action schema',
            icon: Icons.code_rounded,
            value: _settings.useSystemPrompt,
            onChanged: (v) => _settings.setUseSystemPrompt(v),
          ),
          const SizedBox(height: 6),
          GlassSliderRow(
            label: 'Temperature (Creativity)',
            value: _settings.temperature,
            min: 0,
            max: 2,
            divisions: 20,
            displayValue: _settings.temperature.toStringAsFixed(1),
            onChanged: (v) => _settings.setTemperature(v),
          ),
          GlassSliderRow(
            label: 'Max Response Tokens',
            value: _settings.maxTokens.toDouble(),
            min: 256,
            max: 4096,
            divisions: 15,
            displayValue: _settings.maxTokens.toString(),
            onChanged: (v) => _settings.setMaxTokens(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _genyCard() {
    final theme = Theme.of(context);
    final isAlwaysOn = _settings.genyAlwaysOn;
    final persona = PersonalityService.instance.archetype.name.toUpperCase();
    final voice = _settings.genyNeuralVoice.split('-').length > 2
        ? _settings.genyNeuralVoice.split('-')[2].replaceAll('Neural', '')
        : 'Ryan';

    return GlassCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      borderColor: const Color(0xFF00E5FF).withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const GenySettingsScreen()),
              )
              .then((_) => setState(() {}));
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          const Color(0xFF00E5FF).withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF00E5FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'G.E.N.Y.',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isAlwaysOn
                                    ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isAlwaysOn
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isAlwaysOn ? 'ALWAYS-ON ACTIVE' : 'STANDBY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isAlwaysOn
                                      ? const Color(0xFF00E5FF)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Always-on ears, studio neural voice, personality, workflows & memory',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF00E5FF),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  GlassPill(
                    icon: const Icon(Icons.mic_rounded, size: 13, color: Color(0xFF00E5FF)),
                    label: isAlwaysOn ? 'Hands-Free Receptors' : 'Tap to Talk',
                    color: const Color(0xFF00E5FF),
                  ),
                  GlassPill(
                    icon: const Icon(Icons.record_voice_over_rounded, size: 13, color: Color(0xFFFFD700)),
                    label: '$voice Studio Voice',
                    color: const Color(0xFFFFD700),
                  ),
                  GlassPill(
                    icon: const Icon(Icons.psychology_outlined, size: 13, color: Color(0xFFBA68C8)),
                    label: '$persona Tone',
                    color: const Color(0xFFBA68C8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionsCard() {
    return GlassCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PermissionsScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Permissions & Inboxes',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Microphone, SMS stream, Email inbox & Accessibility service',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  GlassPill(
                    icon: Icon(Icons.sms_outlined, size: 13, color: Colors.blueAccent),
                    label: 'SMS Inbox',
                    color: Colors.blueAccent,
                  ),
                  GlassPill(
                    icon: Icon(Icons.mark_email_unread_outlined, size: 13, color: Colors.amber),
                    label: 'Email Stream',
                    color: Colors.amber,
                  ),
                  GlassPill(
                    icon: Icon(Icons.mic_rounded, size: 13, color: Color(0xFF00E5FF)),
                    label: 'Mic Receptor',
                    color: Color(0xFF00E5FF),
                  ),
                  GlassPill(
                    icon: Icon(Icons.accessibility_new_rounded, size: 13, color: Color(0xFF818CF8)),
                    label: 'Screen Touch',
                    color: Color(0xFF818CF8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agentCard() {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          GlassSliderRow(
            label: 'Maximum Task Steps',
            value: _settings.maxSteps.toDouble(),
            min: 3,
            max: 40,
            divisions: 37,
            displayValue: '${_settings.maxSteps} steps',
            onChanged: (v) => _settings.setMaxSteps(v.round()),
          ),
          GlassSliderRow(
            label: 'Step Delay Buffer',
            value: _settings.stepDelayMs.toDouble(),
            min: 200,
            max: 5000,
            divisions: 24,
            displayValue: '${(_settings.stepDelayMs / 1000).toStringAsFixed(1)}s',
            onChanged: (v) => _settings.setStepDelayMs(v.round()),
          ),
          const SizedBox(height: 4),
          GlassSwitchTile(
            title: 'Skill Memory (Macro Fast Replay)',
            subtitle: 'Replay known sequences without invoking AI model',
            icon: Icons.auto_awesome_rounded,
            value: _settings.skillsEnabled,
            onChanged: (v) => _settings.setSkillsEnabled(v),
          ),
          GlassSwitchTile(
            title: 'Spoken Voice Feedback',
            subtitle: 'Vocalize automation progress and task results aloud',
            icon: Icons.record_voice_over_rounded,
            value: _settings.voiceFeedback,
            onChanged: (v) => _settings.setVoiceFeedback(v),
          ),
        ],
      ),
    );
  }

  Widget _voiceLanguageCard() {
    final lang = _settings.assistantLanguage;
    final langLabel = switch (lang) {
      'pt' => 'Português',
      'fr' => 'Français',
      'es' => 'Español',
      _ => 'English',
    };
    return GlassCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      borderColor: const Color(0xFFD946EF).withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const VoiceLanguageScreen()),
              )
              .then((_) => setState(() {}));
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFFD946EF).withValues(alpha: 0.35),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: Color(0xFFD946EF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settings.genyName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$langLabel · Female voice · Tap to customize',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offlineModelsCard() {
    final offline = _settings.offlineAiMode;
    return GlassCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      borderColor: const Color(0xFF22D3EE).withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              )
              .then((_) => setState(() {}));
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF22D3EE).withValues(alpha: 0.35),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.offline_bolt_rounded,
                  color: offline ? const Color(0xFF22C55E) : const Color(0xFF22D3EE),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offline ? 'Offline mode ON' : 'Download an offline model',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offline
                          ? '100% on-device AI — no internet needed'
                          : 'Light or heavy model, runs fully on-device',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telegramCard() {
    final running = _telegram.isRunning;
    final owner = _settings.telegramOwnerChatId;

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassSwitchTile(
            title: 'Enable Telegram Remote Bridge',
            subtitle: running ? 'Bot actively polling for commands' : 'Bot service stopped',
            icon: Icons.send_rounded,
            value: _settings.telegramEnabled,
            onChanged: (v) async {
              await _settings.setTelegramEnabled(v);
              if (v) {
                await _telegram.start();
              } else {
                _telegram.stop();
              }
            },
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _tokenController,
            labelText: 'Telegram Bot Token (from @BotFather)',
            obscureText: _obscureToken,
            prefixIcon: const Icon(Icons.key_outlined, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _chatsController,
            labelText: 'Allowed Chat IDs',
            hintText: 'Comma-separated (leave empty for auto-pairing)',
            prefixIcon: const Icon(Icons.group_outlined, size: 20),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _telegramDirty ? _saveTelegramSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _telegramDirty
                    ? const Color(0xFF0EA5E9)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _telegramDirty ? 4 : 0,
              ),
              icon: Icon(
                _telegramDirty ? Icons.save_rounded : Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                _telegramDirty ? 'Save Telegram settings' : 'Telegram saved',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (owner.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 18, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paired Owner Device',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.greenAccent,
                          ),
                        ),
                        Text(
                          'Chat ID: $owner',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 15),
                    label: const Text('Unpair', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () async {
                      await _settings.setTelegramOwnerChatId('');
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Telegram owner pairing unlinked'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_outlined, size: 18, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status: Unpaired',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amberAccent,
                          ),
                        ),
                        Text(
                          'Send /start or /pair to your bot in Telegram to auto-pair, or enter Chat IDs above.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _appearanceCard() {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme Preference',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _themeOption(
                  mode: ThemeMode.system,
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeOption(
                  mode: ThemeMode.light,
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeOption(
                  mode: ThemeMode.dark,
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required ThemeMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _settings.themeMode == mode;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _settings.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
