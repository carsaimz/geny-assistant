import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/air_gesture_service.dart';
import '../services/geny_service.dart';
import '../services/macro_recorder_service.dart';
import '../services/proactive_agent_service.dart';
import '../services/settings_service.dart';
import 'air_gestures_hud_widget.dart';
import 'brain_dump_dialog.dart';

/// Next-Generation Stark Industries G.E.N.Y. 3D Hologram Consciousness Core.
///
/// Features:
/// - Movie-accurate floating 3D spherical AI consciousness matrix from Iron Man / Avengers (jarvi.jpg).
/// - Zero floor pedestal / zero bottom light: floats freely in zero-gravity space.
/// - Pure OLED Obsidian Black void backdrop with subtle celestial quantum field.
/// - Mid-Screen Tap-to-Talk activation with tactile haptic and holographic sonic ripple feedback.
/// - Zero on-screen chat message clutter or bottom mic docks — pure cinematic holographic entity.
/// - Dynamic real-time color shifting:
///   * LISTENING / IDLE: Electric Arc-Reactor Cyan (0xFF00E5FF).
///   * SPEAKING: Radiant Stark Amber / Solar Gold (0xFFFFB300) directly matching jarvi.jpg.
///   * COMPUTING / THINKING: High-Energy Quantum Fusion Violet-Gold (0xFFBA68C8).
/// - Ultra-cool, interesting 3D live animation:
///   * Multi-axis gyroscopic 3D rotation with precession & perspective depth.
///   * 360-degree circular radial audio equalizer frequency spectrum dancing around the sphere.
///   * Triple-ring 3D armillary gyroscope orbital bands with degree tick notches and orbiting satellite photons.
///   * Pulsating white-hot quantum singularity core with concentric acoustic shockwaves and multi-ray coronal flares.
///   * Orbiting quantum data nodes and floating photon spark particles.
///   * Organic spatial floating & pacing, plus full interactive touch drag anywhere on screen.
class GenyHudWidget extends StatefulWidget {
  const GenyHudWidget({super.key});

  @override
  State<GenyHudWidget> createState() => _GenyHudWidgetState();
}

class _GenyHudWidgetState extends State<GenyHudWidget>
    with TickerProviderStateMixin {
  final _geny = GenyService.instance;

  late final AnimationController _pacingController;
  late final AnimationController _ringsController;
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final AnimationController _sparkController;
  late final AnimationController _colorController;
  late final AnimationController _rippleController;

  Offset _dragOffset = Offset.zero;
  Offset _panStartPosition = Offset.zero;
  bool _hasPanned = false;
  Offset? _tapPosition;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    // Smooth conversational pacing across the screen
    _pacingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // Multi-axis 3D spherical data rings & core gyroscopic rotation
    _ringsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Breathing aura back-glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // High-frequency live vocal equalizer, acoustic ripples & radial spikes
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..repeat(reverse: true);

    // Rising energy spark particles
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Dynamic color transition between Cyan (0.0) and Gold (1.0)
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: _geny.phase == GenyPhase.speaking ? 1.0 : 0.0,
    );

    // Sonic ripple expanding from mid-screen tap location
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _geny.addListener(_onGenyUpdate);
    SettingsService.instance.addListener(_onSettingsUpdate);
    ProactiveAgentService.instance.addListener(_onProactiveUpdate);
    ProactiveAgentService.instance.evaluateProactiveNeeds();
    _geny.onEnterGenyMode();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _geny.removeListener(_onGenyUpdate);
    SettingsService.instance.removeListener(_onSettingsUpdate);
    ProactiveAgentService.instance.removeListener(_onProactiveUpdate);
    _geny.onExitGenyMode();
    _pacingController.dispose();
    _ringsController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _sparkController.dispose();
    _colorController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _handleMidScreenTap(Offset localPosition) {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 350) return;
    _lastTapTime = now;
    HapticFeedback.lightImpact();
    setState(() {
      _tapPosition = localPosition;
    });
    _rippleController.forward(from: 0.0);
    _geny.toggleListening();
  }

  void _onProactiveUpdate() {
    if (mounted) setState(() {});
  }

  void _onGenyUpdate() {
    if (!mounted) return;
    final phase = _geny.phase;

    // Smoothly morph color based on current state
    if (phase == GenyPhase.speaking) {
      _colorController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else if (phase == GenyPhase.listening) {
      _colorController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else if (phase == GenyPhase.thinking) {
      _colorController.animateTo(
        0.5,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _colorController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    setState(() {});
  }

  /// Interpolates the theme color smoothly between Cyan and Gold
  Color _getDynamicThemeColor(double goldFactor) {
    const cyanColor = Color(0xFF00E5FF);
    const purpleColor = Color(0xFFBA68C8);
    const goldColor = Color(0xFFFFB300);

    if (goldFactor <= 0.5) {
      return Color.lerp(cyanColor, purpleColor, goldFactor * 2.0)!;
    } else {
      return Color.lerp(purpleColor, goldColor, (goldFactor - 0.5) * 2.0)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorController,
      builder: (context, _) {
        final goldFactor = _colorController.value;
        final themeColor = _getDynamicThemeColor(goldFactor);
        final isListening = _geny.phase == GenyPhase.listening;

        return Container(
          color: const Color(0xFF000000),
          child: Stack(
            children: [
              // 1. Quantum Holographic Starfield / Matrix Grid
              Positioned.fill(
                child: CustomPaint(
                  painter: GenyCyberGridPainter(color: themeColor),
                ),
              ),

              // 2. Corner HUD Brackets
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GenyCornerBracketsPainter(color: themeColor),
                  ),
                ),
              ),

              // 3. Subtle Corner Telemetry
              Positioned(
                left: 16,
                top: 18,
                child: _buildSideTelemetryLeft(themeColor),
              ),
              Positioned(
                right: 16,
                top: 18,
                child: _buildSideTelemetryRight(themeColor),
              ),

              // 4. Main Arena Column
              SafeArea(
                child: Column(
                  children: [
                    // Top status badge (listening / computing / executing)
                    _buildDynamicStatusPill(),

                    // Proactive intelligent recommendation banner
                    _buildProactiveBanner(themeColor),

                    // Mid-air gesture detection banner
                    ValueListenableBuilder<String?>(
                      valueListenable: AirGestureService.instance.activeGestureBanner,
                      builder: (context, banner, _) {
                        if (banner == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00E5FF), width: 1.4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pan_tool, color: Color(0xFF00E5FF), size: 15),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  banner,
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Central Zero-Gravity Floating Hologram Stage
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final arenaWidth = constraints.maxWidth;
                          final arenaHeight = constraints.maxHeight;

                          // Cinematic 3D sphere diameter
                          final sphereDiameter =
                              (arenaWidth * 0.78).clamp(280.0, 360.0);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              _handleMidScreenTap(details.localPosition);
                            },
                            onPanStart: (details) {
                              _panStartPosition = details.localPosition;
                              _hasPanned = false;
                            },
                            onPanUpdate: (details) {
                              final dist =
                                  (details.localPosition - _panStartPosition)
                                      .distance;
                              if (dist > 8.0) {
                                _hasPanned = true;
                                setState(() {
                                  _dragOffset += details.delta;
                                  final maxX = arenaWidth * 0.45;
                                  final maxY = arenaHeight * 0.40;
                                  _dragOffset = Offset(
                                    _dragOffset.dx.clamp(-maxX, maxX),
                                    _dragOffset.dy.clamp(-maxY, maxY),
                                  );
                                });
                              }
                            },
                            onPanEnd: (details) {
                              if (!_hasPanned) {
                                _handleMidScreenTap(_panStartPosition);
                              }
                            },
                            onDoubleTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _dragOffset = Offset.zero;
                              });
                            },
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _pacingController,
                                _ringsController,
                                _pulseController,
                                _waveController,
                                _sparkController,
                                _colorController,
                                _rippleController,
                              ]),
                              builder: (context, _) {
                                return CustomPaint(
                                  foregroundPainter: GenyTapRipplePainter(
                                    tapPosition: _tapPosition,
                                    progress: _rippleController.value,
                                    color: themeColor,
                                  ),
                                  child: SettingsService.instance.genyScreenStyle ==
                                          GenyScreenStyle.geny
                                      ? _buildHologramSuitStage(
                                          arenaWidth: arenaWidth,
                                          arenaHeight: arenaHeight,
                                        )
                                      : _buildLivingSphereStage(
                                          arenaWidth: arenaWidth,
                                          arenaHeight: arenaHeight,
                                          sphereDiameter: sphereDiameter,
                                        ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Futuristic Action Pods: Always-On, Multitask Decoupler, Self-Evolution, Air Gestures & Macros
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Always-On Continuous Listening Receptor
                            ListenableBuilder(
                              listenable: SettingsService.instance,
                              builder: (context, _) {
                                final isAlwaysOn = SettingsService.instance.genyAlwaysOn;
                                final onColor = const Color(0xFF00E5FF);
                                final offColor = Colors.white.withValues(alpha: 0.45);
                                final color = isAlwaysOn ? onColor : offColor;

                                return GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    final next = !isAlwaysOn;
                                    await SettingsService.instance.setGenyAlwaysOn(next);
                                    if (next) {
                                      GenyService.instance.ensureAlwaysOnRunning();
                                    } else {
                                      GenyService.instance.stopAlwaysOn();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isAlwaysOn
                                          ? onColor.withValues(alpha: 0.18)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isAlwaysOn
                                            ? onColor.withValues(alpha: 0.8)
                                            : Colors.white.withValues(alpha: 0.25),
                                        width: isAlwaysOn ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isAlwaysOn
                                          ? [
                                              BoxShadow(
                                                color: onColor.withValues(alpha: 0.35),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAlwaysOn ? Icons.hearing : Icons.hearing_disabled,
                                          size: 13,
                                          color: color,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isAlwaysOn ? 'ALWAYS-ON: ON' : 'ALWAYS-ON',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),

                            // 2. Chaotic Brain Dump Multi-Task Decoupler
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withValues(alpha: 0.65),
                                  builder: (_) => const BrainDumpDialog(),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.alt_route_rounded,
                                      size: 13,
                                      color: Color(0xFF00E5FF),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'MULTITASK',
                                      style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. Hermes Self-Evolution Trigger
                            GestureDetector(
                              onTap: () async {
                                HapticFeedback.mediumImpact();
                                _geny.processCommand('self evolve');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBA68C8).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFBA68C8).withValues(alpha: 0.55),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.psychology_rounded,
                                      size: 13,
                                      color: Color(0xFFBA68C8),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'SELF EVOLVE',
                                      style: TextStyle(
                                        color: Color(0xFFBA68C8),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 4. Air Gestures
                            ListenableBuilder(
                              listenable: AirGestureService.instance,
                              builder: (context, _) {
                                final isAir = AirGestureService.instance.isEnabled;
                                final airColor = isAir ? const Color(0xFF00E5FF) : themeColor;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withValues(alpha: 0.65),
                                      builder: (_) => const AirGesturesHudWidget(),
                                    );
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    AirGestureService.instance.toggleAirGestures();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isAir ? airColor.withValues(alpha: 0.20) : airColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isAir ? airColor : airColor.withValues(alpha: 0.40),
                                        width: isAir ? 1.6 : 1.2,
                                      ),
                                      boxShadow: isAir
                                          ? [
                                              BoxShadow(
                                                color: airColor.withValues(alpha: 0.4),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAir ? Icons.pan_tool : Icons.pan_tool_outlined,
                                          size: 13,
                                          color: airColor,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'AIR GESTURES',
                                          style: TextStyle(
                                            color: airColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),

                            // 5. Screen Style (Geny vs Arc)
                            ListenableBuilder(
                              listenable: SettingsService.instance,
                              builder: (context, _) {
                                final style = SettingsService.instance.genyScreenStyle;
                                final isArc = style == GenyScreenStyle.arcReactor;
                                final podColor = isArc ? const Color(0xFF00E5FF) : const Color(0xFF64FFDA);

                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    final next = isArc ? GenyScreenStyle.geny : GenyScreenStyle.arcReactor;
                                    SettingsService.instance.setGenyScreenStyle(next);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: podColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: podColor.withValues(alpha: 0.45),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isArc ? Icons.blur_circular_rounded : Icons.accessibility_new_rounded,
                                          size: 13,
                                          color: podColor,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isArc ? 'ARC' : 'GENY',
                                          style: TextStyle(
                                            color: podColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),

                            // 6. Macro Recorder
                            ListenableBuilder(
                              listenable: MacroRecorderService.instance,
                              builder: (context, _) {
                                final isRec = MacroRecorderService.instance.isRecording;
                                final color = isRec ? const Color(0xFFFF5252) : const Color(0xFFBA68C8);
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    if (isRec) {
                                      _geny.processCommand('save macro');
                                    } else {
                                      _geny.processCommand('record macro Custom Task');
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.45),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isRec ? Icons.fiber_manual_record : Icons.auto_awesome,
                                          size: 13,
                                          color: color,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isRec ? 'SAVE' : 'MACRO',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sleek Minimalist Bottom Activator Cue
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        isListening
                            ? 'LISTENING // TAP TO FINISH'
                            : (_geny.phase == GenyPhase.thinking
                                ? 'COMPUTING RESPONSE...'
                                : 'TAP SCREEN TO COMMUNICATE'),
                        style: TextStyle(
                          color: themeColor.withValues(
                            alpha: isListening || _geny.phase == GenyPhase.thinking ? 0.55 : 0.22,
                          ),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the 3D sentient spherical consciousness hologram from jarvi.jpg with
  /// multi-axis rotation, 360-degree radial audio visualizer, dynamic color morphing (Cyan vs Gold),
  /// and zero floor base/light beam for pure levitating zero-gravity visuals.
  Widget _buildLivingSphereStage({
    required double arenaWidth,
    required double arenaHeight,
    required double sphereDiameter,
  }) {
    final phase = _geny.phase;
    final isSpeaking = phase == GenyPhase.speaking;
    final isListening = phase == GenyPhase.listening;
    final isThinking = phase == GenyPhase.thinking;
    final soundLevel = _geny.soundLevel;

    final t = _pacingController.value * 2 * math.pi;
    final goldFactor = _colorController.value;
    final themeColor = _getDynamicThemeColor(goldFactor);

    // Conversational pacing kinematics with 3D gyroscopic precession
    double pacingX;
    double pacingY;
    double tiltX;
    double tiltY;
    double tiltZ;
    double scale;

    if (isSpeaking) {
      // Fluid pacing across screen: walks/floats left and right while speaking!
      pacingX = math.sin(t) * (arenaWidth * 0.22) +
          math.sin(t * 2.1) * (arenaWidth * 0.05);
      pacingY = math.cos(t * 0.75) * 14.0 + math.sin(t * 1.5) * 5.0;

      // 3D gyroscopic tilt and precession: sphere orients toward the user
      tiltY = -(pacingX / (arenaWidth * 0.30)).clamp(-1.0, 1.0) * 0.18 +
          math.sin(t * 0.6) * 0.08;
      tiltX = math.sin(t * 1.1) * 0.08 + 0.04;
      tiltZ = (pacingX / (arenaWidth * 0.30)).clamp(-1.0, 1.0) * 0.04 +
          math.cos(t * 0.8) * 0.04;
      scale = 1.04 + math.sin(t * 0.6) * 0.05; // leans in toward user
    } else if (isListening) {
      // Attentive listening stance: leans closer, hovering calmly
      pacingX = math.sin(t * 0.5) * 10.0;
      pacingY = math.cos(t * 0.7) * 6.0 - 4.0;
      tiltY = math.sin(t * 0.6) * 0.06;
      tiltX = 0.08;
      tiltZ = 0.0;
      scale = 1.05;
    } else if (isThinking) {
      // Pensive hovering: slight elevation and thoughtful angle
      pacingX = math.cos(t * 1.1) * 16.0;
      pacingY = math.sin(t * 1.1) * 12.0 - 8.0;
      tiltY = math.cos(t * 1.1) * 0.09;
      tiltX = -0.04;
      tiltZ = -0.02;
      scale = 0.98;
    } else {
      // Calm, breathing hover float
      pacingX = math.sin(t * 0.45) * 14.0;
      pacingY = math.cos(t * 0.55) * 9.0;
      tiltY = math.sin(t * 0.3) * 0.04;
      tiltX = 0.03;
      tiltZ = math.sin(t * 0.4) * 0.02;
      scale = 1.0;
    }

    // Voice amplitude scale pulse
    final normalizedSound = (soundLevel.abs().clamp(0.0, 10.0)) / 10.0;
    if (isSpeaking) {
      scale += normalizedSound * 0.08;
    }

    final entityCenterX = (arenaWidth / 2) + _dragOffset.dx + pacingX;
    final entityCenterY = (arenaHeight * 0.50) + _dragOffset.dy + pacingY;

    return Stack(
      children: [
        // The 3D Sentient Levitation Consciousness Sphere
        Positioned(
          left: entityCenterX - (sphereDiameter / 2),
          top: entityCenterY - (sphereDiameter / 2),
          width: sphereDiameter,
          height: sphereDiameter,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(tiltX)
              ..rotateY(tiltY)
              ..rotateZ(tiltZ)
              ..scaleByDouble(scale, scale, 1.0, 1.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // A. Multi-Layer Radial Back-Glow Aura
                Positioned.fill(
                  child: CustomPaint(
                    painter: GenyAuraPainter(
                      color: themeColor,
                      pulse: _pulseController.value,
                      isSpeaking: isSpeaking,
                    ),
                  ),
                ),

                // B. 360-Degree Circular Radial Audio Equalizer Spikes
                Positioned.fill(
                  child: CustomPaint(
                    painter: GenyCircularVocalSpectrumPainter(
                      color: themeColor,
                      wave: _waveController.value,
                      soundLevel: soundLevel,
                      isSpeaking: isSpeaking,
                      isListening: isListening,
                    ),
                  ),
                ),

                // C. Rotating 3D Consciousness Matrix Sphere (Color Cross-fade)
                Transform.rotate(
                  angle: _ringsController.value * 2 * math.pi * 0.25,
                  child: Stack(
                    children: [
                      // Cyan Layer (Active when Listening / Idle)
                      Opacity(
                        opacity: (1.0 - goldFactor).clamp(0.0, 1.0),
                        child: Image.asset(
                          'assets/images/geny_core_cyan.png',
                          width: sphereDiameter,
                          height: sphereDiameter,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Gold Layer (Active when Speaking, directly matching jarvi.jpg)
                      Opacity(
                        opacity: goldFactor.clamp(0.0, 1.0),
                        child: Image.asset(
                          'assets/images/geny_core_gold.png',
                          width: sphereDiameter,
                          height: sphereDiameter,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),

                // D. Triple-Ring 3D Armillary Gyroscope Orbital Bands
                Positioned.fill(
                  child: CustomPaint(
                    painter: GenyOrbitalRingsPainter(
                      color: themeColor,
                      rotation: _ringsController.value,
                      isSpeaking: isSpeaking,
                      isThinking: isThinking,
                    ),
                  ),
                ),

                // E. Live Speaking Acoustic Shockwaves, Singularity Pulsar & Coronal Rays
                Positioned.fill(
                  child: CustomPaint(
                    painter: GenyCoreAcousticWavePainter(
                      color: themeColor,
                      wave: _waveController.value,
                      soundLevel: soundLevel,
                      isSpeaking: isSpeaking,
                      isListening: isListening,
                      goldFactor: goldFactor,
                    ),
                  ),
                ),

                // F. Floating Quantum Energy Nodes & Holographic Scanlines
                Positioned.fill(
                  child: CustomPaint(
                    painter: GenyHologramFxPainter(
                      color: themeColor,
                      pulse: _pulseController.value,
                      sparksProgress: _sparkController.value,
                      isSpeaking: isSpeaking,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the 3D Iron Man Hologram Suit / Avatar screen.
  /// Features:
  /// - Translucent male holographic 3D avatar bust inspired by geny avrtar.avif
  /// - Minimal, clean, cinematic look without floating telemetry clutter
  /// - Dynamic real-time color shifting:
  ///   * IDLE: Electric Arc Cyan (0xFF00E5FF)
  ///   * LISTENING: Calm Pulsing Electric Cyan
  ///   * COMPUTING: High-Energy Quantum Fusion Violet-Purple (0xFFBA68C8)
  ///   * SPEAKING: Radiant Stark Amber / Solar Gold (0xFFFFB300)
  /// - Rotating elliptical holographic emitter pedestal beneath with glowing floor rings and conical light beam
  /// - Gentle chest Arc Reactor acoustic ripple (steady, calm, non-erratic)
  /// - Fine digital horizontal scanlines sweeping vertically over the suit
  /// - Touch drag with smooth 3D perspective tilt and spring-back (stable anchor, zero aggressive zooming)
  Widget _buildHologramSuitStage({
    required double arenaWidth,
    required double arenaHeight,
  }) {
    final phase = _geny.phase;
    final isSpeaking = phase == GenyPhase.speaking;
    final isListening = phase == GenyPhase.listening;

    final goldFactor = _colorController.value;
    final themeColor = _getDynamicThemeColor(goldFactor);

    // Smooth floating wave and gentle 3D micro-sway (living hologram presence, no aggressive zoom)
    final floatY = math.sin(_pacingController.value * 2 * math.pi) * 4.5;
    final microSway = math.sin(_pacingController.value * 2 * math.pi) * 0.022;

    // Proportional avatar height
    final avatarHeight = (arenaHeight * 0.72).clamp(320.0, 500.0);
    final avatarWidth = avatarHeight * (896 / 1200);

    // Multi-color crossfade factors: Cyan (0.0) -> Purple (0.5) -> Gold (1.0)
    final double purpleOpacity = goldFactor <= 0.5
        ? (goldFactor * 2.0).clamp(0.0, 1.0)
        : ((1.0 - goldFactor) * 2.0).clamp(0.0, 1.0);
    final double goldOpacity = goldFactor > 0.5
        ? ((goldFactor - 0.5) * 2.0).clamp(0.0, 1.0)
        : 0.0;
    final double cyanOpacity = (1.0 - purpleOpacity - goldOpacity).clamp(0.0, 1.0);

    final tiltX = (_dragOffset.dx * 0.0015).clamp(-0.20, 0.20);
    final tiltY = (_dragOffset.dy * 0.0015).clamp(-0.20, 0.20);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Holographic Floor Emitter Pedestal
        Positioned.fill(
          child: CustomPaint(
            painter: GenyEmitterPedestalPainter(
              progress: _ringsController.value,
              color: themeColor,
              active: isSpeaking || isListening,
            ),
          ),
        ),

        // 2. 3D Floating Hologram Suit Avatar (Steady scale, anchored with smooth 3D perspective)
        Transform.translate(
          offset: Offset(_dragOffset.dx, _dragOffset.dy + floatY - 10),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(tiltX + microSway)
              ..rotateX(-tiltY),
            child: SizedBox(
              width: avatarWidth,
              height: avatarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Smooth, steady ambient aura backglow (gentle breathing)
                  Container(
                    width: avatarWidth * 0.72,
                    height: avatarHeight * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(
                            alpha: isSpeaking || isListening ? 0.26 : 0.15,
                          ),
                          blurRadius: 38,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),

                  // 3D Orbital Holographic Torso Rings (Moving orbital animations like Arc Reactor)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GenyHoloTorsoRingsPainter(
                        ringProgress: _ringsController.value,
                        color: themeColor,
                        active: isSpeaking || isListening,
                      ),
                    ),
                  ),

                  // Base Cyan Hologram Suit (Idle / Standby)
                  Opacity(
                    opacity: cyanOpacity,
                    child: Image.asset(
                      'assets/images/geny_male_hologram.png',
                      width: avatarWidth,
                      height: avatarHeight,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Intermediate Purple Hologram Suit (Thinking / Computing)
                  if (purpleOpacity > 0.01)
                    Opacity(
                      opacity: purpleOpacity,
                      child: Image.asset(
                        'assets/images/geny_male_hologram_purple.png',
                        width: avatarWidth,
                        height: avatarHeight,
                        fit: BoxFit.contain,
                      ),
                    ),

                  // Gold Hologram Suit (Speaking)
                  if (goldOpacity > 0.01)
                    Opacity(
                      opacity: goldOpacity,
                      child: Image.asset(
                        'assets/images/geny_male_hologram_gold.png',
                        width: avatarWidth,
                        height: avatarHeight,
                        fit: BoxFit.contain,
                      ),
                    ),

                  // Subtle calm Arc Reactor breathing glow at chest core
                  Positioned(
                    top: avatarHeight * 0.36,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(
                              alpha: isSpeaking || isListening
                                  ? (0.42 + math.sin(_pulseController.value * 2 * math.pi) * 0.14)
                                  : (0.20 + math.sin(_pulseController.value * 2 * math.pi) * 0.08),
                            ),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Subtle Chest Arc Reactor Acoustic Ripples (Calm, non-erratic)
                  if (isSpeaking || isListening)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GenyChestSonicWavePainter(
                          waveProgress: _waveController.value,
                          color: themeColor,
                          active: true,
                        ),
                      ),
                    ),

                  // Digital Raster Scanlines Sweeping Suit
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: GenySuitScanlinePainter(
                          progress: _pulseController.value,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Minimal side telemetry
  Widget _buildSideTelemetryLeft(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CORE // STARK-VIII\nCONSCIOUSNESS // ACTIVE\nNODES // 1024-SYNC',
          style: TextStyle(
            color: color.withValues(alpha: 0.22),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildSideTelemetryRight(Color color) {
    final currentStyle = SettingsService.instance.genyScreenStyle;
    final isArc = currentStyle == GenyScreenStyle.arcReactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          isArc
              ? 'QUANTUM // SYNCED\nSTABILITY // 99.8%\nCHIRALITY // NOMINAL'
              : 'SUIT // MARK LXXXV\nHOLO // 3D-AVATAR\nTELEMETRY // OPTIC',
          textAlign: TextAlign.end,
          style: TextStyle(
            color: color.withValues(alpha: 0.22),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ],
    );
  }

  /// Subtle status pill (ONLY appears when actively listening, computing, or executing tasks)
  Widget _buildDynamicStatusPill() {
    if (_geny.phase == GenyPhase.idle ||
        _geny.phase == GenyPhase.speaking) {
      return const SizedBox(height: 14);
    }

    Color color;
    String label;
    IconData icon;

    switch (_geny.phase) {
      case GenyPhase.listening:
        color = const Color(0xFF00E5FF);
        label = 'LISTENING';
        icon = Icons.graphic_eq_rounded;
        break;
      case GenyPhase.thinking:
        color = const Color(0xFFFFD700);
        label = 'COMPUTING';
        icon = Icons.psychology_outlined;
        break;
      case GenyPhase.executing:
        color = const Color(0xFFFF9100);
        final step = _geny.currentStep;
        label = step > 0 ? 'AUTOMATION STEP #$step' : 'TASK IN PROGRESS';
        icon = Icons.bolt_rounded;
        break;
      default:
        return const SizedBox(height: 14);
    }

    final isExecuting = _geny.phase == GenyPhase.executing;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xCC050505),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
            if (isExecuting) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _geny.abortTask,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD50000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProactiveBanner(Color themeColor) {
    final proactive = ProactiveAgentService.instance;
    final suggestion = proactive.currentSuggestion;
    if (suggestion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE080808),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.40),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: themeColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suggestion.title.toUpperCase(),
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  suggestion.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final goal = suggestion.actionGoal;
              proactive.dismissSuggestion();
              _geny.processCommand(goal);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.6),
                  width: 0.6,
                ),
              ),
              child: Text(
                'ACT',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              proactive.dismissSuggestion();
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0x66FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints an ultra-minimal, aesthetic holographic quantum starfield/matrix
class GenyCyberGridPainter extends CustomPainter {
  final Color color;
  const GenyCyberGridPainter({this.color = const Color(0xFF00E5FF)});

  @override
  void paint(Canvas canvas, Size size) {
    // Ultra faint quantum dot matrix
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    const spacing = 52.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }

    // Concentric faint HUD distance rings around the optical center
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final center = Offset(size.width / 2, size.height * 0.50);
    canvas.drawCircle(center, size.width * 0.48, ringPaint);
    canvas.drawCircle(center, size.width * 0.76, ringPaint);
  }

  @override
  bool shouldRepaint(covariant GenyCyberGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Paints the futuristic Stark HUD corner brackets with dynamic color
class GenyCornerBracketsPainter extends CustomPainter {
  final Color color;

  const GenyCornerBracketsPainter({this.color = const Color(0xFF00E5FF)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const length = 16.0;
    const offset = 8.0;

    // Top-left
    canvas.drawLine(const Offset(offset, offset + length),
        const Offset(offset, offset), paint);
    canvas.drawLine(const Offset(offset, offset),
        const Offset(offset + length, offset), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - offset - length, offset),
        Offset(size.width - offset, offset), paint);
    canvas.drawLine(Offset(size.width - offset, offset),
        Offset(size.width - offset, offset + length), paint);

    // Bottom-left
    canvas.drawLine(Offset(offset, size.height - offset - length),
        Offset(offset, size.height - offset), paint);
    canvas.drawLine(Offset(offset, size.height - offset),
        Offset(offset + length, size.height - offset), paint);

    // Bottom-right
    canvas.drawLine(
        Offset(size.width - offset - length, size.height - offset),
        Offset(size.width - offset, size.height - offset),
        paint);
    canvas.drawLine(
        Offset(size.width - offset, size.height - offset - length),
        Offset(size.width - offset, size.height - offset),
        paint);
  }

  @override
  bool shouldRepaint(covariant GenyCornerBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Renders an expanding holographic sonic ripple from the tap location
class GenyTapRipplePainter extends CustomPainter {
  final Offset? tapPosition;
  final double progress;
  final Color color;

  const GenyTapRipplePainter({
    required this.tapPosition,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tapPosition == null || progress <= 0.0 || progress >= 1.0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 2.2;

    // Primary expanding wave
    final radius1 = progress * 150.0;
    final alpha1 = (1.0 - progress).clamp(0.0, 1.0) * 0.55;
    paint.color = color.withValues(alpha: alpha1);
    canvas.drawCircle(tapPosition!, radius1, paint);

    // Secondary trailing wave
    if (progress > 0.15) {
      final p2 = (progress - 0.15) / 0.85;
      final radius2 = p2 * 110.0;
      final alpha2 = (1.0 - p2).clamp(0.0, 1.0) * 0.35;
      paint.color = color.withValues(alpha: alpha2);
      canvas.drawCircle(tapPosition!, radius2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GenyTapRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tapPosition != tapPosition ||
        oldDelegate.color != color;
  }
}

/// Renders 360-degree circular radial frequency spectrum equalizer around the sphere
class GenyCircularVocalSpectrumPainter extends CustomPainter {
  final Color color;
  final double wave;
  final double soundLevel;
  final bool isSpeaking;
  final bool isListening;

  const GenyCircularVocalSpectrumPainter({
    required this.color,
    required this.wave,
    required this.soundLevel,
    required this.isSpeaking,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = size.width * 0.475;

    final normalizedSound = (soundLevel.abs().clamp(0.0, 10.0)) / 10.0;
    final voiceAmp = isSpeaking
        ? (0.35 + 0.65 * math.sin(wave * math.pi)) *
            (0.6 + normalizedSound * 0.9)
        : (isListening ? (0.2 + normalizedSound * 0.7) : 0.08);

    const numSpikes = 42;
    final spikePaint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numSpikes; i++) {
      final angle = (i / numSpikes) * 2 * math.pi;
      final harmonic =
          math.sin((i * 3.7) + (wave * 2 * math.pi)) * 0.5 + 0.5;
      final spikeLen =
          (harmonic * 16.0 * voiceAmp) + (isSpeaking ? 3.5 : 1.5);

      final r1 = baseRadius + 1.5;
      final r2 = baseRadius + 1.5 + spikeLen;

      final p1 = Offset(cx + r1 * math.cos(angle), cy + r1 * math.sin(angle));
      final p2 = Offset(cx + r2 * math.cos(angle), cy + r2 * math.sin(angle));

      final alpha = (0.25 + (harmonic * 0.75) * voiceAmp).clamp(0.1, 1.0);
      spikePaint.color =
          (i % 3 == 0 ? Colors.white : color).withValues(alpha: alpha);

      canvas.drawLine(p1, p2, spikePaint);

      // Outer node dot on prominent spikes
      if (harmonic > 0.7 && voiceAmp > 0.3) {
        canvas.drawCircle(
            p2, 1.3, Paint()..color = Colors.white.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(
          covariant GenyCircularVocalSpectrumPainter oldDelegate) =>
      true;
}

/// 3D Tilted Gyroscopic Armillary Quantum Data Rings with tick markings and orbiting satellites
class GenyOrbitalRingsPainter extends CustomPainter {
  final Color color;
  final double rotation;
  final bool isSpeaking;
  final bool isThinking;

  const GenyOrbitalRingsPainter({
    required this.color,
    required this.rotation,
    required this.isSpeaking,
    required this.isThinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: isSpeaking ? 0.65 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final dotPaint = Paint()..color = const Color(0xFFFFFFFF);

    // Ring 1: Equatorial Gyroscope Ring (Tilted +28 deg)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(0.48);
    final r1 = size.width * 0.50;
    final r1YScale = 0.36 + (math.sin(rotation * 2 * math.pi) * 0.05);
    canvas.scale(1.0, r1YScale);
    canvas.drawCircle(Offset.zero, r1, ringPaint);

    // Degree tick notches around Ring 1
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 16; i++) {
      final ta = (i / 16.0) * 2 * math.pi;
      final pA = Offset((r1 - 3) * math.cos(ta), (r1 - 3) * math.sin(ta));
      final pB = Offset((r1 + 3) * math.cos(ta), (r1 + 3) * math.sin(ta));
      canvas.drawLine(pA, pB, tickPaint);
    }

    // Orbiting Satellite Photon 1
    final a1 = (isThinking ? rotation * 2.5 : rotation) * 2 * math.pi;
    final sat1 = Offset(r1 * math.cos(a1), r1 * math.sin(a1));
    canvas.drawCircle(sat1, 2.8, dotPaint);
    canvas.drawCircle(
        sat1, 6.0, Paint()..color = color.withValues(alpha: 0.4));
    canvas.restore();

    // Ring 2: Polar Orbital Ring (Tilted -44 deg)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.76);
    final r2 = size.width * 0.53;
    final r2YScale = 0.30 + (math.cos(rotation * 2 * math.pi) * 0.05);
    canvas.scale(1.0, r2YScale);
    canvas.drawCircle(Offset.zero, r2, ringPaint);

    // Orbiting Satellite Photon 2 (counter-rotating)
    final a2 = -(isThinking ? rotation * 2.8 : rotation * 1.2) * 2 * math.pi;
    final sat2 = Offset(r2 * math.cos(a2), r2 * math.sin(a2));
    canvas.drawCircle(sat2, 2.6, dotPaint);
    canvas.drawCircle(
        sat2, 5.5, Paint()..color = color.withValues(alpha: 0.35));
    canvas.restore();

    // Ring 3: Steep Meridian Ring (Tilted +72 deg, precessing)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(1.25);
    final r3 = size.width * 0.46;
    final r3YScale = 0.24 + (math.sin(rotation * 3 * math.pi) * 0.04);
    canvas.scale(1.0, r3YScale);
    canvas.drawCircle(
      Offset.zero,
      r3,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    final a3 = (rotation * 1.8) * 2 * math.pi;
    canvas.drawCircle(
        Offset(r3 * math.cos(a3), r3 * math.sin(a3)), 2.0, dotPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GenyOrbitalRingsPainter oldDelegate) => true;
}

/// Renders acoustic energy shockwaves, pulsating nuclear pulsar singularity,
/// and coronal ray flares rippling from the central core of the consciousness sphere.
class GenyCoreAcousticWavePainter extends CustomPainter {
  final Color color;
  final double wave;
  final double soundLevel;
  final bool isSpeaking;
  final bool isListening;
  final double goldFactor;

  const GenyCoreAcousticWavePainter({
    required this.color,
    required this.wave,
    required this.soundLevel,
    required this.isSpeaking,
    required this.isListening,
    required this.goldFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.48;

    final normalizedSound = (soundLevel.abs().clamp(0.0, 10.0)) / 10.0;
    final voiceAmp = isSpeaking
        ? (0.40 + 0.60 * math.sin(wave * math.pi)) *
            (0.7 + normalizedSound * 0.8)
        : (isListening ? (normalizedSound * 0.75) : 0.0);

    // 1. Central Pulsar Singularity Core (white-hot radiant nucleus)
    final coreR = (size.width * 0.08) * (1.0 + (voiceAmp * 0.5));
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF),
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: coreR * 2.4));
    canvas.drawCircle(Offset(cx, cy), coreR * 2.4, corePaint);
    canvas.drawCircle(
        Offset(cx, cy), coreR * 0.55, Paint()..color = Colors.white);

    // 2. Concentric Expanding Acoustic Shockwaves rippling out through the sphere
    final waveCount = 4;
    for (int i = 0; i < waveCount; i++) {
      final progress = (wave + (i / waveCount)) % 1.0;
      final shockRadius = (size.width * 0.10) +
          (progress * (maxR - (size.width * 0.10)));
      final baseAlpha = isSpeaking ? 0.75 : (isListening ? 0.40 : 0.15);
      final alpha = (1.0 - progress) *
          baseAlpha *
          (isSpeaking ? voiceAmp : (isListening ? 0.8 : 0.4));

      if (alpha > 0.02) {
        final shockPaint = Paint()
          ..color = (isSpeaking ? const Color(0xFFFFD54F) : color)
              .withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * (1.0 - progress * 0.5);

        canvas.drawCircle(Offset(cx, cy), shockRadius, shockPaint);
      }
    }

    // 3. Multi-Ray Coronal Energy Flares (Subtle anamorphic core glint)
    if (isSpeaking || isListening) {
      final flareLen = maxR * (0.32 + voiceAmp * 0.20);
      final flareAngles = [0.0, math.pi / 2, math.pi / 4, -math.pi / 4];
      for (final fa in flareAngles) {
        final flarePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              color.withValues(alpha: 0.70 * voiceAmp),
              const Color(0xFFFFFFFF).withValues(alpha: 0.90 * voiceAmp),
              color.withValues(alpha: 0.70 * voiceAmp),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(Rect.fromCenter(
            center: Offset(cx, cy),
            width: flareLen * 2,
            height: 3,
          ));

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(fa);
        canvas.drawLine(
          Offset(-flareLen, 0),
          Offset(flareLen, 0),
          flarePaint..strokeWidth = 1.2,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant GenyCoreAcousticWavePainter oldDelegate) =>
      true;
}

/// Renders smooth multi-layer radial backlight aura behind the consciousness sphere
class GenyAuraPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final bool isSpeaking;

  const GenyAuraPainter({
    required this.color,
    required this.pulse,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.52;

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(
            alpha: isSpeaking ? 0.32 + (pulse * 0.08) : 0.16 + (pulse * 0.04),
          ),
          color.withValues(
            alpha: isSpeaking ? 0.10 + (pulse * 0.03) : 0.04 + (pulse * 0.01),
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

    canvas.drawCircle(Offset(cx, cy), radius, auraPaint);
  }

  @override
  bool shouldRepaint(covariant GenyAuraPainter oldDelegate) => true;
}

/// Floating quantum energy spark particles and holographic scanlines
class GenyHologramFxPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final double sparksProgress;
  final bool isSpeaking;

  const GenyHologramFxPainter({
    required this.color,
    required this.pulse,
    required this.sparksProgress,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Subtle Holographic Scanlines
    final scanlinePaint = Paint()
      ..color = color.withValues(alpha: 0.025)
      ..strokeWidth = 0.8;

    const lineGap = 10.0;
    for (double y = 0; y < size.height; y += lineGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 2. 3D Floating Quantum Spark Nodes orbiting the sphere
    final sparkPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);

    final sparkSeeds = [
      [-0.32, -0.25, 0.45],
      [0.30, 0.28, 0.65],
      [-0.22, 0.35, 0.85],
      [0.25, -0.32, 0.35],
      [-0.10, -0.15, 0.55],
      [0.15, 0.18, 0.75],
      [-0.38, 0.10, 0.20],
      [0.35, -0.12, 0.90],
    ];

    for (final seed in sparkSeeds) {
      final t = (sparksProgress + seed[2]) % 1.0;
      final orbitalAngle = t * 2 * math.pi;
      final rx = (size.width * 0.42) * seed[0].abs();
      final ry = (size.height * 0.42) * seed[1].abs();

      final px = cx + rx * math.cos(orbitalAngle);
      final py = cy + ry * math.sin(orbitalAngle);

      final alpha =
          (math.sin(t * math.pi) * (isSpeaking ? 0.9 : 0.65)).clamp(0.0, 1.0);
      sparkPaint.color =
          (t > 0.5 ? Colors.white : color).withValues(alpha: alpha);

      canvas.drawCircle(Offset(px, py), 1.8, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GenyHologramFxPainter oldDelegate) => true;
}

/// Renders the rotating circular holographic projection pedestal beneath the 3D Iron Man suit
class GenyEmitterPedestalPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool active;

  GenyEmitterPedestalPainter({
    required this.progress,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.88;
    final rx = size.width * 0.38;
    final ry = rx * 0.28; // Elliptical 3D perspective

    // 1. Upward volumetric light beam cone
    final beamPath = Path()
      ..moveTo(cx - rx * 0.85, cy)
      ..lineTo(cx - rx * 0.45, cy - size.height * 0.65)
      ..lineTo(cx + rx * 0.45, cy - size.height * 0.65)
      ..lineTo(cx + rx * 0.85, cy)
      ..close();

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: active ? 0.30 : 0.16),
          color.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(cx - rx, cy - size.height * 0.65, rx * 2, size.height * 0.65),
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(beamPath, beamPaint);

    // 2. Concentric ground rings
    final ringPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.65 : 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.5, height: ry * 1.5),
      ringPaint..strokeWidth = 0.9,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 0.9, height: ry * 0.9),
      ringPaint..strokeWidth = 0.6,
    );

    // 3. Rotating tick marks along outer ellipse
    final tickPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.80 : 0.50)
      ..strokeWidth = 1.5;

    const tickCount = 24;
    final angleOffset = progress * 2 * math.pi;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i * 2 * math.pi / tickCount) + angleOffset;
      final px = cx + rx * math.cos(angle);
      final py = cy + ry * math.sin(angle);
      final len = (i % 4 == 0) ? 6.0 : 3.5;
      final dx = len * math.cos(angle);
      final dy = len * 0.28 * math.sin(angle);
      canvas.drawLine(Offset(px - dx, py - dy), Offset(px + dx, py + dy), tickPaint);
    }

    // 4. Center intense projection hotspot
    final spotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: active ? 0.85 : 0.50),
          color.withValues(alpha: active ? 0.60 : 0.30),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 0.7, height: ry * 0.7),
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 0.7, height: ry * 0.7),
      spotPaint,
    );

    // 5. Rising volumetric quantum light particles from emitter
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 14; i++) {
      final fracY = (progress * 0.4 + i * 0.0714) % 1.0;
      final py = cy - (fracY * size.height * 0.52);
      final spread = (1.0 - fracY * 0.45);
      final angle = (i * 1.57) % (2 * math.pi);
      final px = cx + (rx * 0.60 * spread * math.cos(angle));
      final alpha = math.sin(fracY * math.pi) * (active ? 0.60 : 0.30);
      sparkPaint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), 1.3, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GenyEmitterPedestalPainter oldDelegate) => true;
}

/// 3D Orbital Holographic Torso Rings floating around the Suit
class GenyHoloTorsoRingsPainter extends CustomPainter {
  final double ringProgress;
  final Color color;
  final bool active;

  GenyHoloTorsoRingsPainter({
    required this.ringProgress,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.60;
    final rx = size.width * 0.44;
    final ry = rx * 0.22; // 3D perspective ellipse

    // 1. Clockwise outer orbital ring with telemetry ticks
    final outerAngle = ringProgress * 2 * math.pi;
    final outerPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.42 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(0.16); // slight 3D roll angle
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      outerPaint,
    );

    final tickPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.70 : 0.40)
      ..strokeWidth = 1.3;
    const ticks = 16;
    for (int i = 0; i < ticks; i++) {
      final a = (i * 2 * math.pi / ticks) + outerAngle;
      final px = rx * math.cos(a);
      final py = ry * math.sin(a);
      const len = 4.0;
      canvas.drawLine(
        Offset(px - len * 0.5 * math.cos(a), py - len * 0.5 * math.sin(a)),
        Offset(px + len * 0.5 * math.cos(a), py + len * 0.5 * math.sin(a)),
        tickPaint,
      );
    }
    canvas.restore();

    // 2. Counter-clockwise inner orbital ring
    final innerAngle = -ringProgress * 2 * math.pi * 0.75;
    final innerPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.32 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas.save();
    canvas.translate(cx, cy - 22);
    canvas.rotate(-0.12); // counter roll angle
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 1.55, height: ry * 1.55),
      innerPaint,
    );

    // Orbiting cursor pip
    final pipPaint = Paint()
      ..color = Colors.white.withValues(alpha: active ? 0.85 : 0.55)
      ..style = PaintingStyle.fill;
    final pipX = rx * 0.775 * math.cos(innerAngle);
    final pipY = ry * 0.775 * math.sin(innerAngle);
    canvas.drawCircle(Offset(pipX, pipY), 2.0, pipPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GenyHoloTorsoRingsPainter oldDelegate) => true;
}

/// Renders acoustic sonic shockwaves emanating from the chest Arc Reactor of the 3D Hologram Suit
class GenyChestSonicWavePainter extends CustomPainter {
  final double waveProgress;
  final Color color;
  final bool active;

  GenyChestSonicWavePainter({
    required this.waveProgress,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;

    final cx = size.width / 2;
    // Chest node is around 38% down the suit
    final cy = size.height * 0.38;

    for (int i = 0; i < 2; i++) {
      final p = (waveProgress + i * 0.50) % 1.0;
      final radius = 22.0 + p * 38.0;
      final alpha = (1.0 - p) * 0.35;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 - (p * 0.6);

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GenyChestSonicWavePainter oldDelegate) => true;
}

/// High-tech horizontal raster scanlines sweeping down the 3D Hologram Suit
class GenySuitScanlinePainter extends CustomPainter {
  final double progress;
  final Color color;

  GenySuitScanlinePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Moving bright scanline
    final scanY = size.height * progress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.85),
          color.withValues(alpha: 0.65),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 3, size.width, 6))
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), linePaint);

    // 2. Subtle periodic raster bars
    final rasterPaint = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 6.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rasterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GenySuitScanlinePainter oldDelegate) => true;
}
