import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/air_gesture_service.dart';

/// 🖐️ Air Gestures Holographic Control HUD
///
/// Displays real-time optical proximity wave telemetry, gesture triggers,
/// and interactive touchless simulation buttons.
class AirGesturesHudWidget extends StatefulWidget {
  const AirGesturesHudWidget({super.key});

  @override
  State<AirGesturesHudWidget> createState() => _AirGesturesHudWidgetState();
}

class _AirGesturesHudWidgetState extends State<AirGesturesHudWidget>
    with SingleTickerProviderStateMixin {
  final AirGestureService _service = AirGestureService.instance;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF07121E).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cyan.withValues(alpha: 0.35), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.18),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final isArmed = _service.isEnabled;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyan.withValues(alpha: 0.15),
                          border: Border.all(color: cyan.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.pan_tool_outlined, color: cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'IRON MAN AIR GESTURES',
                              style: TextStyle(
                                color: cyan,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              isArmed ? 'OPTICAL PROXIMITY ACTIVE' : 'SENSORS STANDBY',
                              style: TextStyle(
                                color: isArmed ? const Color(0xFF00E676) : Colors.white54,
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Animated Proximity Wave Radar
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final wave = _pulseController.value;
                      return Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cyan.withValues(alpha: 0.2)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radiating ripples
                            if (isArmed) ...[
                              Container(
                                width: 50 + (wave * 90),
                                height: 50 + (wave * 90),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cyan.withValues(alpha: (1.0 - wave) * 0.45),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 30 + (wave * 60),
                                height: 30 + (wave * 60),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cyan.withValues(alpha: (1.0 - wave) * 0.65),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ],
                            Icon(
                              Icons.front_hand,
                              color: isArmed ? cyan : Colors.white24,
                              size: 42,
                            ),
                            Positioned(
                              bottom: 8,
                              child: Text(
                                _service.statusMessage,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Gestures Reference Grid
                  _gestureRow('👋 Quick Wave / Swipe', 'Next Track / Skip Song'),
                  const SizedBox(height: 8),
                  _gestureRow('✋ Palm Hover (1-2s)', 'Play / Pause Music'),
                  const SizedBox(height: 8),
                  _gestureRow('✌️ Double Wave', 'Capture Instant Screenshot'),

                  const SizedBox(height: 20),

                  // Simulation Pods
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _simButton('Test Wave', () => _service.simulateGesture('wave')),
                      _simButton('Test Hover', () => _service.simulateGesture('palm_hover')),
                      _simButton('Test Double', () => _service.simulateGesture('double_wave')),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Arm / Disarm Toggle Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isArmed
                            ? const Color(0xFFEF5350).withValues(alpha: 0.8)
                            : cyan.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isArmed ? Colors.redAccent : cyan,
                            width: 1.2,
                          ),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _service.toggleAirGestures();
                      },
                      icon: Icon(isArmed ? Icons.power_settings_new : Icons.sensors),
                      label: Text(
                        isArmed ? 'DISARM AIR SENSORS' : 'ARM AIR SENSORS',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _gestureRow(String gesture, String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            gesture,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            action,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00E5FF),
        side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Text(
        label,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
      ),
    );
  }
}

