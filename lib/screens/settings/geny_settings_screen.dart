import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../services/app_usage_service.dart';
import '../../services/commute_traffic_service.dart';
import '../../services/conversational_memory_service.dart';
import '../../services/hermes_evolution_service.dart';
import '../../services/geny_service.dart';
import '../../services/local_llm_service.dart';
import '../../services/macro_recorder_service.dart';
import '../../services/personality_service.dart';
import '../../services/phone_storage_service.dart';
import '../../services/proactive_agent_service.dart';
import '../../services/sentry_service.dart';
import '../../services/code_black_service.dart';
import '../../services/floating_copilot_service.dart';
import '../../services/settings_service.dart';
import '../../services/smart_home_service.dart';
import '../../services/system_diagnostics_service.dart';
import '../../services/vision_perception_service.dart';
import '../../services/voice_service.dart';
import '../../services/workflow_service.dart';
import '../../widgets/air_gestures_hud_widget.dart';
import '../../widgets/airspace_radar_dialog.dart';
import '../../widgets/arc_reactor_charging_dialog.dart';
import '../../widgets/network_audit_dialog.dart';
import '../../widgets/optical_solver_dialog.dart';
import '../../widgets/polyglot_diplomat_dialog.dart';
import '../../theme/app_theme.dart';
import '../security/code_black_screen.dart';
import 'model_manager_screen.dart';
import 'permissions_screen.dart';
import 'voice_language_screen.dart';

/// Dedicated configuration suite for all G.E.N.Y. autonomous capabilities:
/// - Always-On Voice & Speech Synthesis
/// - Personality & Emotional Intelligence
/// - Self-Evolving Workflows (Hermes Engine)
/// - Conversational Memory & Data Governance
/// - Hermes Self-Evolving tri-partite context (SOUL.md, USER.md, AGENT.md)
class GenySettingsScreen extends StatefulWidget {
  const GenySettingsScreen({super.key});

  @override
  State<GenySettingsScreen> createState() => _GenySettingsScreenState();
}

class _GenySettingsScreenState extends State<GenySettingsScreen> {
  final _settings = SettingsService.instance;
  final _hermes = HermesEvolutionService.instance;

  @override
  void initState() {
    super.initState();
    _hermes.init().then((_) {
      if (mounted) setState(() {});
    });
    _hermes.addListener(_onHermesChanged);
    SentryService.instance.addListener(_onHermesChanged);
  }

  @override
  void dispose() {
    _hermes.removeListener(_onHermesChanged);
    SentryService.instance.removeListener(_onHermesChanged);
    super.dispose();
  }

  void _onHermesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'G.E.N.Y.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _sectionTitle('🗣️ Voice & Language'),
          _voiceLanguageCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🧠 Offline AI Models (On-Device)'),
          _offlineModelsCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('GENY Screen (HUD Visual Style)'),
          _screenStyleCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('Always-On Voice & Speech Synthesis'),
          _voiceCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('Personality & Emotional Intelligence'),
          _personalityCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('Self-Evolving Workflows (Hermes Engine)'),
          _workflowsCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🛡️ Sentry Mode (Tactical Anti-Theft Watchdog)'),
          _sentryCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('⚡ Floating Arc-Reactor HUD (System-Wide Hologram)'),
          _arcReactorHudCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('📁 Direct Storage & System Telemetry (No UI Taps)'),
          _directToolsCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('👁️ "Geny Eye" — Multimodal Camera Perception'),
          _genyEyeCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🚀 Stark Superpowers & Cyber Suite'),
          _starkSuperpowersCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🪄 Autonomous "Macro Recorder" (Hermes Skills)'),
          _macroRecorderCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🏠 Smart Home & IoT Automation (Home Assistant)'),
          _smartHomeCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🗺️ Proactive Commute & Real-Time Traffic Warnings'),
          _commuteCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('🗣️ Proactive Autonomous Voice & Scheduled Nudges'),
          _proactiveVoiceCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('Memory & Privacy Governance'),
          _privacyCard(theme),
          const SizedBox(height: 20),
          _sectionTitle('Hermes Self-Evolving Context (SOUL, USER, AGENT)'),
          _hermesEvolutionCard(theme),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // Voice & Language card
  // ---------------------------------------------------------------------------
  Widget _voiceLanguageCard(ThemeData theme) {
    return Card(
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
                    gradient: AppTheme.genieGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.record_voice_over_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Name, language & voice studio',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose Geny\'s name, her voice (female by default) and the app language: English, Português, Français or Español.',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VoiceLanguageScreen()),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Voice & Language studio'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline AI models card
  // ---------------------------------------------------------------------------
  Widget _offlineModelsCard(ThemeData theme) {
    final offline = _settings.offlineAiMode;
    return Card(
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
                    gradient: LinearGradient(colors: [
                      AppTheme.cyan.withValues(alpha: 0.85),
                      AppTheme.indigo
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.offline_bolt_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    offline
                        ? 'Offline mode is ON — Geny runs 100% on your phone'
                        : 'Download an AI model to use Geny offline',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Light (~0.55 GB) or heavy (~2.5 GB) model, downloaded inside the app. Once installed, chat works with zero internet.',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Open Model Manager'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 0. GENY Screen (Visual Style) Card
  // ---------------------------------------------------------------------------
  Widget _screenStyleCard(ThemeData theme) {
    final currentStyle = _settings.genyScreenStyle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: const Icon(
                    Icons.view_in_ar_rounded,
                    size: 20,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GENY Screen Mode',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose your visual hologram display for GENY mode',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _screenStyleOption(
                    theme: theme,
                    title: 'Arc Reactor',
                    subtitle: '3D Spherical Core & Gyroscope',
                    icon: Icons.blur_circular_rounded,
                    isSelected: currentStyle == GenyScreenStyle.arcReactor,
                    onTap: () async {
                      await _settings.setGenyScreenStyle(GenyScreenStyle.arcReactor);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _screenStyleOption(
                    theme: theme,
                    title: 'Geny',
                    subtitle: '3D Iron Man Hologram Suit',
                    icon: Icons.accessibility_new_rounded,
                    isSelected: currentStyle == GenyScreenStyle.geny,
                    onTap: () async {
                      await _settings.setGenyScreenStyle(GenyScreenStyle.geny);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _screenStyleOption({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF00E5FF);
    final borderColor = isSelected ? activeColor : theme.colorScheme.outline.withValues(alpha: 0.25);
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected ? activeColor : theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected ? activeColor : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Voice & Speech Synthesis Card
  // ---------------------------------------------------------------------------
  Widget _voiceCard(ThemeData theme) {
    final neuralVoiceOptions = [
      ('en-GB-RyanNeural', 'Ryan (British Neural - Authentic Geny)', 'Paul Bettany style, warm, articulate & human'),
      ('en-GB-ThomasNeural', 'Thomas (British Neural - Conversational)', 'Natural UK cadence and smooth phrasing'),
      ('en-US-GuyNeural', 'Guy (US Neural - Studio Male)', 'Polished, authoritative US broadcaster tone'),
      ('en-US-ChristopherNeural', 'Christopher (US Neural - Confident)', 'Direct, crisp and focused'),
      ('en-IE-EmilyNeural', 'Emily (Irish Neural - F.R.I.D.A.Y.)', 'Charming, brisk Irish accent'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always-on Hands-free toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Always-On Continuous Listening',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Desk mode: listens silently in the background, ignores room chatter, and wakes on "Hey Geny"',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.genyAlwaysOn,
              onChanged: (val) async {
                await _settings.setGenyAlwaysOn(val);
                if (val) {
                  GenyService.instance.ensureAlwaysOnRunning();
                } else {
                  GenyService.instance.stopAlwaysOn();
                }
                setState(() {});
              },
            ),
            const Divider(height: 24),

            // Ultra-Realistic Neural Voice Toggle & Selector
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ultra-Realistic Studio Neural Voice',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Broadcast-grade natural human voice synthesis (auto-falls back offline)',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.useNeuralVoice,
              onChanged: (val) async {
                await _settings.setUseNeuralVoice(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),

            const Text(
              'Voice Model & Personality',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the studio human voice for Geny spoken responses.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _settings.genyNeuralVoice,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: neuralVoiceOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.$1,
                        child: Text(
                          opt.$2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newVoice) async {
                      if (newVoice != null) {
                        await _settings.setGenyNeuralVoice(newVoice);
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Test voice',
                  icon: const Icon(Icons.volume_up_rounded, size: 22),
                  onPressed: () async {
                    await VoiceService.instance.speak(
                      'All systems operational. Standing by for your command.',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Personality & Tone Card
  // ---------------------------------------------------------------------------
  Widget _personalityCard(ThemeData theme) {
    final personality = PersonalityService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personality Archetype',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              personality.archetypeDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<PersonalityArchetype>(
              segments: const [
                ButtonSegment(
                  value: PersonalityArchetype.geny,
                  label: Text('GENY', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.shield_outlined, size: 16),
                ),
                ButtonSegment(
                  value: PersonalityArchetype.companion,
                  label: Text('Friend', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.favorite_outline, size: 16),
                ),
                ButtonSegment(
                  value: PersonalityArchetype.cyberpunk,
                  label: Text('Cyber', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.terminal, size: 16),
                ),
                ButtonSegment(
                  value: PersonalityArchetype.executive,
                  label: Text('Exec', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.business_center_outlined, size: 16),
                ),
              ],
              selected: {personality.archetype},
              onSelectionChanged: (val) async {
                await personality.setArchetype(val.first);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Formality & Cadence',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SegmentedButton<FormalityLevel>(
              segments: const [
                ButtonSegment(
                  value: FormalityLevel.casual,
                  label: Text('Casual', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: FormalityLevel.balanced,
                  label: Text('Balanced', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: FormalityLevel.formal,
                  label: Text('Formal', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {personality.formality},
              onSelectionChanged: (val) async {
                await personality.setFormality(val.first);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Humor & Wit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SegmentedButton<HumorLevel>(
              segments: const [
                ButtonSegment(
                  value: HumorLevel.none,
                  label: Text('None', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: HumorLevel.subtle,
                  label: Text('Subtle', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: HumorLevel.high,
                  label: Text('High Wit', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {personality.humor},
              onSelectionChanged: (val) async {
                await personality.setHumor(val.first);
                setState(() {});
              },
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Emotional Intelligence & Sensing',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Detects urgency, stress, and fatigue from phrasing and dynamically adapts conversational empathy',
                style: TextStyle(fontSize: 12),
              ),
              value: personality.emotionalAwarenessEnabled,
              onChanged: (val) async {
                await personality.setEmotionalAwarenessEnabled(val);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Self-Evolving Workflows Card (Hermes Engine)
  // ---------------------------------------------------------------------------
  Widget _workflowsCard(ThemeData theme) {
    final workflows = WorkflowService.instance.workflows;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Self-Evolving Skills & Workflows',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Hermes Engine: automatically detects user intent and engages hardware protocols',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.genyWorkflowsEnabled,
              onChanged: (val) async {
                await _settings.setGenyWorkflowsEnabled(val);
                setState(() {});
              },
            ),
            if (_settings.genyWorkflowsEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'ACTIVE HARDWARE PROTOCOLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              for (final wf in workflows) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        wf.id == 'study'
                            ? Icons.school_outlined
                            : (wf.id == 'night'
                                ? Icons.bedtime_outlined
                                : (wf.id == 'cinema'
                                    ? Icons.movie_outlined
                                    : Icons.work_outline)),
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wf.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              wf.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Voice trigger: "${wf.triggerKeywords.take(3).join('", "')}"',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await WorkflowService.instance.executeWorkflow(wf);
                          await VoiceService.instance
                              .speak(wf.spokenConfirmation);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Triggered ${wf.name}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child:
                            const Text('Test', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3a-1. Sentry Mode (Tactical Anti-Theft Watchdog) Card
  // ---------------------------------------------------------------------------
  Widget _sentryCard(ThemeData theme) {
    final sentry = SentryService.instance;
    final isArmed = sentry.isArmed;
    final ownerChat = _settings.telegramOwnerChatId;
    final hasTelegram = ownerChat.isNotEmpty;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isArmed
              ? const Color(0xFFFF5252).withValues(alpha: 0.7)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isArmed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isArmed
                        ? const Color(0xFFFF5252).withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isArmed ? Icons.shield : Icons.shield_outlined,
                    color: isArmed ? const Color(0xFFFF5252) : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tactical Sentry Watchdog',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isArmed
                            ? 'ARMED // Monitoring accelerometer & perimeter'
                            : 'STANDBY // Motion sensors disarmed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isArmed ? const Color(0xFFFF5252) : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isArmed,
                  activeThumbColor: const Color(0xFFFF5252),
                  onChanged: (val) async {
                    if (val) {
                      await sentry.armSentry();
                    } else {
                      await sentry.disarmSentry();
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Armed watchdog detects unauthorized handling, speaks an imposing security warning, captures a silent front-camera snapshot, and immediately transmits the photo to your paired Telegram terminal.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasTelegram
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasTelegram
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasTelegram ? Icons.telegram : Icons.warning_amber_rounded,
                    color: hasTelegram ? Colors.greenAccent : Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasTelegram
                          ? 'Telegram Uplink: Connected (Chat ID: $ownerChat)'
                          : 'Telegram Uplink: Not paired. Configure in Settings for photo dispatch.',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasTelegram ? Colors.greenAccent : Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (sentry.lastBreachTime != null) ...[
              const SizedBox(height: 10),
              Text(
                'Last breach incident: ${sentry.lastBreachTime}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF5252), fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3a-2. Floating Arc-Reactor HUD Hologram Card
  // ---------------------------------------------------------------------------
  Widget _arcReactorHudCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Color(0xFF00E5FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floating Arc-Reactor HUD',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'System-Wide Holographic Overlay',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFF00E5FF),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Toggle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (await FlutterOverlayWindow.isActive()) {
                      await FlutterOverlayWindow.closeOverlay();
                    } else {
                      final granted = await FlutterOverlayWindow.isPermissionGranted();
                      if (!granted) {
                        await FlutterOverlayWindow.requestPermission();
                      }
                      await FlutterOverlayWindow.showOverlay(
                        enableDrag: true,
                        overlayTitle: 'G.E.N.Y. HUD',
                        overlayContent: 'Stark Arc Reactor Core Active',
                        flag: OverlayFlag.defaultFlag,
                        visibility: NotificationVisibility.visibilityPublic,
                        positionGravity: PositionGravity.auto,
                        width: 110,
                        height: 110,
                      );
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Floats over any browser or app. Glows Cyan on standby, turns Emerald Green when listening to your voice, and transitions to Solar Gold when computing or speaking.\n\nTap "Summarize Screen" from any webpage or article to receive an articulate executive briefing spoken aloud by G.E.N.Y.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3a-3. Direct Storage & Telemetry (No UI Taps) Card
  // ---------------------------------------------------------------------------
  Widget _directToolsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed, color: Colors.tealAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Hardware & Storage Tools',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Zero UI Taps // Native System APIs',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'G.E.N.Y. no longer navigates phone settings or taps the screen for routine diagnostic tasks. Hardware specifications, top launcher applications, screen time statistics, and file system creation execute via direct Android APIs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.memory, size: 14),
                  label: const Text('Check Specs', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    final spoken = await SystemDiagnosticsService.instance.getDiagnosticsSpoken();
                    await VoiceService.instance.speak(spoken);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(spoken), duration: const Duration(seconds: 4)),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.apps, size: 14),
                  label: const Text('Top Apps', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    final spoken = await AppUsageService.instance.getInstalledAppsSpoken();
                    await VoiceService.instance.speak(spoken);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(spoken), duration: const Duration(seconds: 3)),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pie_chart_outline, size: 14),
                  label: const Text('Screen Time', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    final spoken = await AppUsageService.instance.getTopUsedAppsSpoken();
                    await VoiceService.instance.speak(spoken);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(spoken), duration: const Duration(seconds: 4)),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_outlined, size: 14),
                  label: const Text('Write Song File', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    const song = 'Electric Horizons by G.E.N.Y.\nNeon pulses through the titanium frame...';
                    final res = await PhoneStorageService.instance.createFile(
                      fileName: 'song.txt',
                      content: song,
                      folder: 'Download',
                    );
                    const msg = 'Created song.txt directly in Download folder!';
                    await VoiceService.instance.speak('I have created song.txt directly in your Download folder.');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['success'] == true ? msg : 'Error: ${res['message']}')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3b. "Geny Eye" Multimodal Camera & Optical Perception Card
  // ---------------------------------------------------------------------------
  Widget _genyEyeCard(ThemeData theme) {
    final vision = VisionPerceptionService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Geny Eye Optical Perception',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Real-time camera snapshot & optical analysis (inspects objects, documents, physical errors, receipts, circuit boards) with LLM visual synthesis',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.genyEyeEnabled,
              onChanged: (val) async {
                await _settings.setGenyEyeEnabled(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: vision.isInspecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.remove_red_eye_outlined, size: 18),
                label: Text(vision.isInspecting
                    ? 'Scanning Optical Target...'
                    : 'Test Geny Eye Snapshot'),
                onPressed: vision.isInspecting
                    ? null
                    : () async {
                        final result = await vision.inspectOpticalSnapshot();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.spokenSummary),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          setState(() {});
                        }
                      },
              ),
            ),
            if (vision.lastResult != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.radar_outlined,
                          size: 14,
                          color: Color(0xFF00E5FF),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LATEST OPTICAL TELEMETRY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xFF00E5FF),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${vision.lastResult!.timestamp.hour.toString().padLeft(2, '0')}:${vision.lastResult!.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00E5FF),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vision.lastResult!.spokenSummary,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3b-2. Stark Superpowers & Cyber Suite Card
  // ---------------------------------------------------------------------------
  Widget _starkSuperpowersCard(ThemeData theme) {
    const cyan = Color(0xFF00E5FF);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: cyan, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Stark Tactical Superpowers Suite',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Zero-touch proximity gestures, Arc Reactor plug-in telemetry, live diplomatic voice translation, overhead airspace radar, and cyber defense network auditing.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const Divider(height: 24),

            // 1. Air Gestures
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pan_tool_outlined, color: cyan),
              title: const Text('Iron Man Zero-Touch Air Gestures'),
              subtitle: const Text('Wave or hover hand above proximity sensor to skip, pause, or screenshot'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan.withValues(alpha: 0.15),
                  foregroundColor: cyan,
                  side: const BorderSide(color: cyan, width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.65),
                    builder: (_) => const AirGesturesHudWidget(),
                  );
                },
                child: const Text('Air HUD'),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Arc Reactor Charging Telemetry
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bolt, color: Color(0xFFFFD54F)),
              title: const Text('Arc Reactor Charging Telemetry'),
              subtitle: const Text('Cinematic glowing HUD & vocal wattage telemetry upon charger connection'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFFD54F),
                  side: const BorderSide(color: Color(0xFFFFD54F), width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.7),
                    builder: (_) => const ArcReactorChargingDialog(),
                  );
                },
                child: const Text('Test HUD'),
              ),
            ),
            const SizedBox(height: 8),

            // 3. Polyglot Diplomat
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.translate, color: Color(0xFF64B5F6)),
              title: const Text('Polyglot Diplomat (Live Translator)'),
              subtitle: const Text('Two-way real-time voice interpreter between 14+ international languages'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF64B5F6).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF64B5F6),
                  side: const BorderSide(color: Color(0xFF64B5F6), width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.65),
                    builder: (_) => const PolyglotDiplomatDialog(),
                  );
                },
                child: const Text('Translate'),
              ),
            ),
            const SizedBox(height: 8),

            // 4. Code Black Deceptive Lockout
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_person_outlined, color: Colors.redAccent),
              title: const Text('"Code Black" Deceptive Lockout'),
              subtitle: const Text('Simulates catastrophic kernel panic. Unlock: 4 taps in top-right corner or voice override'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.18),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
                onPressed: () {
                  CodeBlackService.instance.arm();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CodeBlackScreen()),
                  );
                },
                child: const Text('Arm Black'),
              ),
            ),
            const SizedBox(height: 8),

            // 5. Floating Co-Pilot
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_in_picture_alt, color: Color(0xFFBA68C8)),
              title: const Text('Holographic Floating Co-Pilot'),
              subtitle: const Text('Universal Arc Reactor bubble over other apps (WhatsApp, Chrome, Amazon)'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA68C8).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFBA68C8),
                  side: const BorderSide(color: Color(0xFFBA68C8), width: 1.0),
                ),
                onPressed: () async {
                  await FloatingCopilotService.instance.activateOverlay();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Floating Co-Pilot overlay active on screen'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Launch'),
              ),
            ),
            const SizedBox(height: 8),

            // 6. Overhead Airspace Radar
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radar, color: Color(0xFF00E676)),
              title: const Text('Airspace & Satellite Radar'),
              subtitle: const Text('"Geny, what\'s flying above me?" — Live ADS-B flights and ISS orbital passes'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00E676),
                  side: const BorderSide(color: Color(0xFF00E676), width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.7),
                    builder: (_) => const AirspaceRadarDialog(),
                  );
                },
                child: const Text('Radar'),
              ),
            ),
            const SizedBox(height: 8),

            // 7. Optical HUD Solver
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.document_scanner_outlined, color: Color(0xFFFFB300)),
              title: const Text('Real-Time Optical HUD Solver'),
              subtitle: const Text('Point camera at math equations, monitor stack traces, or split dinner bills'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFFB300),
                  side: const BorderSide(color: Color(0xFFFFB300), width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.7),
                    builder: (_) => const OpticalSolverDialog(),
                  );
                },
                child: const Text('Solve AR'),
              ),
            ),
            const SizedBox(height: 8),

            // 8. Network Cyber Security Audit
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security, color: cyan),
              title: const Text('Network Security & Wi-Fi Scanner'),
              subtitle: const Text('Sweeps local subnet, parses ARP MAC addresses, probes RTSP IP cameras and SSH ports'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan.withValues(alpha: 0.15),
                  foregroundColor: cyan,
                  side: const BorderSide(color: cyan, width: 1.0),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.7),
                    builder: (_) => const NetworkAuditDialog(),
                  );
                },
                child: const Text('Audit LAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3c. Autonomous "Macro Recorder" (Hermes Skills) Card
  // ---------------------------------------------------------------------------
  Widget _macroRecorderCard(ThemeData theme) {
    final recorder = MacroRecorderService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Autonomous Macro Recording',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Record user interaction sequences across other apps via accessibility events and codify them into named executable skills in AGENT.md',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.macroRecorderEnabled,
              onChanged: (val) async {
                await _settings.setMacroRecorderEnabled(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            if (recorder.isRecording) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          size: 14,
                          color: Color(0xFFFF5252),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RECORDING: "${recorder.activeMacroGoal}"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF5252),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Demonstrate actions across any app. Accessibility events are being mapped into TaskSteps.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                        ),
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('Stop & Codify into AGENT.md'),
                        onPressed: () async {
                          final skill = await recorder.stopRecording();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Codified "${skill?.goal}" into AGENT.md!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.fiber_manual_record_outlined, size: 16),
                  label: const Text('Start Recording Macro Demonstration'),
                  onPressed: () {
                    _showStartMacroDialog();
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'CODIFIED MACRO SKILLS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  '${recorder.recordedMacros.length} stored',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recorder.recordedMacros.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No macros recorded yet. Tap "Start Recording" or say "Geny, record macro <name>" to demonstrate an autonomous skill.',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              ...recorder.recordedMacros.take(5).map(
                    (skill) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_outlined, size: 16, color: Color(0xFFBA68C8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  skill.goal,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${skill.steps.length} atomic actions • Used ${skill.successCount}x',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow_outlined, size: 20),
                            tooltip: 'Replay Macro',
                            onPressed: () async {
                              await recorder.replaySkill(skill);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Delete Macro',
                            onPressed: () async {
                              await recorder.deleteSkill(skill.id);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showStartMacroDialog() {
    final controller = TextEditingController(text: 'Open Spotify and play workout');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record New Autonomous Macro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the natural language goal of this macro. Once recording starts, perform the actions in any app on your phone:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Macro Goal',
                border: OutlineInputBorder(),
                hintText: 'e.g. Order usual coffee in Starbucks',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.fiber_manual_record, size: 16),
            label: const Text('Start Recording'),
            onPressed: () async {
              final goal = controller.text.trim();
              Navigator.pop(ctx);
              if (goal.isNotEmpty) {
                await MacroRecorderService.instance.startRecording(goal);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3d. Smart Home & IoT Automation Card
  // ---------------------------------------------------------------------------
  Widget _smartHomeCard(ThemeData theme) {
    final smartHome = SmartHomeService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Smart Home & IoT Controls',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Local network REST/webhook controls for Home Assistant (lights, switches, scenes) with voice triggers & Night/Cinema protocol integration',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.smartHomeEnabled,
              onChanged: (val) async {
                await _settings.setSmartHomeEnabled(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.homeAssistantUrl,
              decoration: const InputDecoration(
                labelText: 'Home Assistant Base URL',
                hintText: 'http://homeassistant.local:8123',
                prefixIcon: Icon(Icons.link, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) async {
                await _settings.setHomeAssistantUrl(val);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _settings.homeAssistantToken,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Long-Lived Access Token (Bearer)',
                hintText: 'eyJhbGciOi...',
                prefixIcon: Icon(Icons.key_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) async {
                await _settings.setHomeAssistantToken(val);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _settings.smartHomeDefaultEntity,
              decoration: const InputDecoration(
                labelText: 'Default Target Entity ID',
                hintText: 'light.living_room',
                prefixIcon: Icon(Icons.lightbulb_outline, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) async {
                await _settings.setSmartHomeDefaultEntity(val);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: smartHome.isConnecting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, size: 16),
                    label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                    onPressed: smartHome.isConnecting
                        ? null
                        : () async {
                            final res = await smartHome.checkConnection();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setState(() {});
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () async {
                    await smartHome.turnOn();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dispatched Light ON signal'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Turn ON', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () async {
                    await smartHome.turnOff();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dispatched Light OFF signal'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Turn OFF', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3e. Proactive Commute & Real-Time Traffic Warnings Card
  // ---------------------------------------------------------------------------
  Widget _commuteCard(ThemeData theme) {
    final commute = CommuteTrafficService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Proactive Commute & Traffic Warnings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Computes real-time drive times & rush-hour congestion linked with calendar meetings to warn you proactively when to depart',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.proactiveCommuteEnabled,
              onChanged: (val) async {
                await _settings.setProactiveCommuteEnabled(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.commuteHomeAddress,
              decoration: const InputDecoration(
                labelText: 'Home / Origin Address',
                hintText: 'e.g. 10 Downing Street or Downtown',
                prefixIcon: Icon(Icons.home_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) async {
                await _settings.setCommuteHomeAddress(val);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _settings.commuteWorkAddress,
              decoration: const InputDecoration(
                labelText: 'Work / Standard Destination',
                hintText: 'e.g. Tech Park or Stark Tower',
                prefixIcon: Icon(Icons.business_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) async {
                await _settings.setCommuteWorkAddress(val);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: commute.isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_car_outlined, size: 16),
                label: Text(commute.isChecking
                    ? 'Calculating Live Route...'
                    : 'Check Live Commute & Traffic'),
                onPressed: commute.isChecking
                    ? null
                    : () async {
                        final status = await commute.checkCommute();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(status.spokenSummary),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          setState(() {});
                        }
                      },
              ),
            ),
            if (commute.lastStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.traffic_outlined,
                          size: 15,
                          color: commute.lastStatus!.trafficSeverity == TrafficSeverity.heavy
                              ? const Color(0xFFFF5252)
                              : (commute.lastStatus!.trafficSeverity == TrafficSeverity.moderate
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFF00E676)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          commute.lastStatus!.severityLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: commute.lastStatus!.trafficSeverity == TrafficSeverity.heavy
                                ? const Color(0xFFFF5252)
                                : (commute.lastStatus!.trafficSeverity == TrafficSeverity.moderate
                                    ? const Color(0xFFFFB300)
                                    : const Color(0xFF00E676)),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${commute.lastStatus!.distanceKm} km',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      commute.lastStatus!.spokenSummary,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3f. Proactive Autonomous Voice & Scheduled Nudges Card
  // ---------------------------------------------------------------------------
  Widget _proactiveVoiceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Autonomous Proactive Voice Prompts',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Geny speaks aloud to prompt you about night mode, study sessions, upcoming meetings, and remaining to-dos',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.genyAutoSpeakEnabled,
              onChanged: (val) async {
                await _settings.setGenyAutoSpeakEnabled(val);
                setState(() {});
              },
            ),
            if (_settings.genyAutoSpeakEnabled) ...[
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Hands-Free Voice Confirmation',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Geny opens an active listening window after asking a question so you can reply "Yes" or "No" without touching the device',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveVoiceConfirmationEnabled,
                onChanged: (val) async {
                  await _settings.setProactiveVoiceConfirmationEnabled(val);
                  setState(() {});
                },
              ),
              const Divider(height: 20),
              const Text(
                'AUTONOMOUS TIME & SCHEDULE TRIGGERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '🌙 Night Mode Auto-Speak',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '"It\'s night time. Should I turn on the night mode?" (9:00 PM – 11:30 PM)',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveNightModePrompt,
                onChanged: (val) async {
                  await _settings.setProactiveNightModePrompt(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '📚 Study & Focus Protocol Prompt',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Asks to engage Study Protocol and silence distractions during afternoon focus sessions (2:00 PM – 4:30 PM)',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveStudyPrompt,
                onChanged: (val) async {
                  await _settings.setProactiveStudyPrompt(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '📅 Upcoming Meeting & Calendar Reminders',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Warns 15–30m before scheduled calendar events with briefing & traffic check',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveMeetingReminders,
                onChanged: (val) async {
                  await _settings.setProactiveMeetingReminders(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '📋 Remaining Tasks Review',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Evening check-in on remaining high-priority agenda items (5:00 PM – 7:30 PM)',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveTaskReminderPrompt,
                onChanged: (val) async {
                  await _settings.setProactiveTaskReminderPrompt(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '☀️ Morning Briefing Routine',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Asks to deliver weather, calendar & top headlines upon waking (7:00 AM – 9:30 AM)',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveMorningBriefingPrompt,
                onChanged: (val) async {
                  await _settings.setProactiveMorningBriefingPrompt(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '🔋 Low Battery Telemetry Warning',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Warns when battery drops below 20% and offers to engage Battery Saver protocol',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.proactiveBatteryAlert,
                onChanged: (val) async {
                  await _settings.setProactiveBatteryAlert(val);
                  setState(() {});
                },
              ),
              const Divider(height: 24),
              const Text(
                'TEST PROACTIVE AUTONOMOUS PROMPTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap any prompt to test Geny speaking aloud and awaiting your hands-free voice confirmation ("Yes" / "No"):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_round, size: 14),
                    label: const Text('Test Night Mode', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ProactiveAgentService.instance.testProactivePrompt('night');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing Night Mode auto-speak... Say "Yes" or "No" to Geny.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book, size: 14),
                    label: const Text('Test Study Protocol', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ProactiveAgentService.instance.testProactivePrompt('study');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing Study Protocol prompt... Say "Yes" or "No" to Geny.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: const Text('Test Meeting Alert', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ProactiveAgentService.instance.testProactivePrompt('meeting');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing Meeting Alert... Say "Yes" or "No" to Geny.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Test Tasks Review', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ProactiveAgentService.instance.testProactivePrompt('todo');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing Tasks Review... Say "Yes" or "No" to Geny.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Memory & Privacy Governance Card
  // ---------------------------------------------------------------------------
  Widget _privacyCard(ThemeData theme) {
    final memory = ConversationalMemoryService.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Local-First Privacy Mode',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Forces 100% on-device AI via Ollama (127.0.0.1:11434) & offline TTS — zero data sent outside your device',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.localFirstPrivacyMode,
              onChanged: (val) async {
                await _settings.setLocalFirstPrivacyMode(val);
                setState(() {});
              },
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Permission Confirmation for Sensitive Actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Asks for explicit confirmation before sending messages, making calls, or executing high-impact device actions',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.confirmRiskyActions,
              onChanged: (val) async {
                await _settings.setConfirmRiskyActions(val);
                setState(() {});
              },
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'App & Inbox Permissions Hub',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Audit and grant permissions for SMS inbox, email stream, mic & screen automation',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                );
              },
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conversational Memory & Facts',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${memory.facts.length} remembered facts stored locally',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.manage_search_rounded, size: 18),
                  label: const Text('Manage', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showMemoryFactsSheet(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Wipe All Conversational Memory'),
                onPressed: () => _confirmWipeMemory(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemoryFactsSheet() {
    final addController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final memory = ConversationalMemoryService.instance;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Remembered Facts & Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addController,
                            decoration: const InputDecoration(
                              hintText: 'Add a new fact (e.g. "Favorite team is Arsenal")',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () async {
                            final text = addController.text.trim();
                            if (text.isNotEmpty) {
                              await memory.addFact(text);
                              addController.clear();
                              setModalState(() {});
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: memory.facts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No facts stored yet.'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: memory.facts.length,
                              itemBuilder: (context, i) {
                                final f = memory.facts[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(f.fact, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(
                                    '${f.category} • ${f.createdAt.toString().split('.').first}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await memory.deleteFact(f.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmWipeMemory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe All Memory?'),
        content: const Text(
          'This will permanently delete all cross-session dialogue history, learned preferences, and stored facts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ConversationalMemoryService.instance.wipeAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All memory wiped successfully.')),
                );
                setState(() {});
              }
            },
            child: const Text('Wipe All'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Hermes Self-Evolving tri-partite context (SOUL.md, USER.md, AGENT.md)
  // ---------------------------------------------------------------------------
  Widget _hermesEvolutionCard(ThemeData theme) {
    final soulLines = _hermes.soulMd.trim().split('\n').length;
    final userLines = _hermes.userMd.trim().split('\n').length;
    final agentLines = _hermes.agentMd.trim().split('\n').length;

    final lastEvolved = _hermes.lastEvolvedAt != null
        ? 'Last evolved: ${_hermes.lastEvolvedAt!.toLocal().toString().split('.').first}'
        : 'Default Hermes templates active';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_motion_rounded,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Hermes Self-Evolution Engine',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                width: 0.7,
                              ),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00E5FF),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tri-partite context files (SOUL, USER, AGENT) based on Nous Research Hermes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lastEvolved,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 20),

            // SOUL.md Card
            _hermesFileTile(
              theme: theme,
              fileName: 'SOUL.md',
              slotBadge: 'SLOT 1',
              badgeColor: const Color(0xFF00E5FF),
              icon: Icons.shield_outlined,
              description:
                  'Defines agent persona, poise, salutation style, behavioral guardrails, and ethics.',
              metrics: '$soulLines lines • ${_hermes.soulMd.length} chars',
              content: _hermes.soulMd,
              onTap: () => _openMarkdownEditor(
                fileName: 'SOUL.md',
                title: 'Core Identity & Behavioral Constitution',
                slotBadge: 'SLOT 1',
                initialContent: _hermes.soulMd,
                onSave: (val) => _hermes.updateSoul(val),
                onReset: () => _hermes.resetSoul(),
              ),
            ),
            const SizedBox(height: 10),

            // USER.md Card
            _hermesFileTile(
              theme: theme,
              fileName: 'USER.md',
              slotBadge: 'SLOT 2',
              badgeColor: const Color(0xFFFFB300),
              icon: Icons.person_outline_rounded,
              description:
                  'Operator profile, cadence preferences, daily routines, and dynamically synthesized memory facts.',
              metrics: '$userLines lines • ${_hermes.userMd.length} chars',
              content: _hermes.userMd,
              onTap: () => _openMarkdownEditor(
                fileName: 'USER.md',
                title: 'Operator Profile & Learned Preferences',
                slotBadge: 'SLOT 2',
                initialContent: _hermes.userMd,
                onSave: (val) => _hermes.updateUser(val),
                onReset: () => _hermes.resetUser(),
              ),
            ),
            const SizedBox(height: 10),

            // AGENT.md Card
            _hermesFileTile(
              theme: theme,
              fileName: 'AGENT.md',
              slotBadge: 'SLOT 3',
              badgeColor: const Color(0xFF7C4DFF),
              icon: Icons.smart_toy_outlined,
              description:
                  'Operational protocols (Study, Night, Work, Cinema), hardware actuators, and self-evolved skills.',
              metrics: '$agentLines lines • ${_hermes.agentMd.length} chars',
              content: _hermes.agentMd,
              onTap: () => _openMarkdownEditor(
                fileName: 'AGENT.md',
                title: 'Operating Protocols & Self-Evolving Skills',
                slotBadge: 'SLOT 3',
                initialContent: _hermes.agentMd,
                onSave: (val) => _hermes.updateAgent(val),
                onReset: () => _hermes.resetAgent(),
              ),
            ),
            const SizedBox(height: 16),

            // Evolutionary Action Buttons
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.auto_mode_rounded, size: 18),
                label: const Text('Evolve Now (Synthesize Memories & Skills)'),
                onPressed: () async {
                  await _hermes.evolveContext();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hermes Engine evolved SOUL.md, USER.md & AGENT.md with latest telemetry!'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restore_page_outlined, size: 18),
                label: const Text('Reset All Context Files to Defaults'),
                onPressed: () => _confirmResetHermesAll(),
              ),
            ),

            if (_hermes.evolutionLog.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 16),
              Text(
                'RECENT SELF-EVOLUTION LOGS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in _hermes.evolutionLog.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.commit, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hermesFileTile({
    required ThemeData theme,
    required String fileName,
    required String slotBadge,
    required Color badgeColor,
    required IconData icon,
    required String description,
    required String metrics,
    required String content,
    required VoidCallback onTap,
  }) {
    final snippet = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .take(2)
        .join(' ')
        .trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: badgeColor),
                const SizedBox(width: 8),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.6),
                  ),
                  child: Text(
                    slotBadge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  metrics,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View & Edit Markdown',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openMarkdownEditor({
    required String fileName,
    required String title,
    required String slotBadge,
    required String initialContent,
    required Future<void> Function(String) onSave,
    required Future<void> Function() onReset,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _HermesMarkdownEditorSheet(
        fileName: fileName,
        title: title,
        slotBadge: slotBadge,
        initialContent: initialContent,
        onSave: onSave,
        onReset: onReset,
      ),
    );
  }

  void _confirmResetHermesAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Hermes Files?'),
        content: const Text(
          'This will revert SOUL.md, USER.md, and AGENT.md to their default Nous Research templates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _hermes.resetAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All Hermes context files reset to defaults.')),
                );
                setState(() {});
              }
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }
}

class _HermesMarkdownEditorSheet extends StatefulWidget {
  final String fileName;
  final String title;
  final String slotBadge;
  final String initialContent;
  final Future<void> Function(String) onSave;
  final Future<void> Function() onReset;

  const _HermesMarkdownEditorSheet({
    required this.fileName,
    required this.title,
    required this.slotBadge,
    required this.initialContent,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<_HermesMarkdownEditorSheet> createState() =>
      _HermesMarkdownEditorSheetState();
}

class _HermesMarkdownEditorSheetState
    extends State<_HermesMarkdownEditorSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _controller.text;
    final lines = text.split('\n').length;
    final chars = text.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.fileName,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.slotBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                widget.title,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Edit Markdown'),
              Tab(icon: Icon(Icons.preview_outlined, size: 18), text: 'Rendered Preview'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '$lines lines • $chars chars',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.restore, size: 14),
                    label: const Text('Reset File', style: TextStyle(fontSize: 11)),
                    onPressed: () async {
                      await widget.onReset();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reset ${widget.fileName} to default template')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Edit
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter markdown content...',
                      ),
                    ),
                  ),
                  // Tab 2: Rendered Preview
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        code: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Changes to ${widget.fileName}'),
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await widget.onSave(_controller.text);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved changes to ${widget.fileName}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

