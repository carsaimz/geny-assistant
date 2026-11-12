import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/code_black_service.dart';
import '../../services/voice_service.dart';

/// 🎭 "Code Black" Deceptive Lockout Screen
///
/// Looks like a terminal system crash / military lockout.
/// Hidden unlock: 4 rapid taps on the top-right corner, or speaking the secret override passphrase.
class CodeBlackScreen extends StatefulWidget {
  const CodeBlackScreen({super.key});

  @override
  State<CodeBlackScreen> createState() => _CodeBlackScreenState();
}

class _CodeBlackScreenState extends State<CodeBlackScreen>
    with SingleTickerProviderStateMixin {
  final CodeBlackService _service = CodeBlackService.instance;
  late AnimationController _glitchController;
  int _secretCornerTaps = 0;
  DateTime? _lastCornerTap;
  Timer? _flickerTimer;
  bool _flickerState = false;
  final Random _rand = Random();

  final List<String> _fakeLogs = [
    'CRITICAL KERNEL INTEGRITY FAILURE: mem_core_isolate() returned 0xDEADBEEF',
    'SECURITY FAULT: Cryptographic enclave checksum mismatch at 0x7FFF0049',
    'DEFENSE PROTOCOL: Shizuku / ADB isolation active. USB debugging disabled.',
    'WARNING: Unauthorized tactile inputs detected. Geo-coordinates locked.',
    'ENCRYPTION LAYER: 4096-bit AES lockdown engaged. Volatile cache scrubbed.',
    'TRANSMITTING SATELLITE TELEMETRY TO ABUZAR DEFENSE COMMAND...',
  ];

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _flickerTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted) {
        setState(() {
          _flickerState = !_flickerState;
        });
      }
    });

    _listenForVoiceOverride();
  }

  void _listenForVoiceOverride() {
    VoiceService.instance.onListeningChanged = (listening) {
      if (!listening && mounted && _service.isArmed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _service.isArmed) {
            unawaited(VoiceService.instance.startListening(
              continuous: true,
              onResult: (words, isFinal, candidates) {
                if (_service.checkVoiceDisarm(words)) {
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ));
          }
        });
      }
    };

    unawaited(VoiceService.instance.startListening(
      continuous: true,
      onResult: (words, isFinal, candidates) {
        if (_service.checkVoiceDisarm(words)) {
          if (mounted) Navigator.of(context).pop();
        }
      },
    ));
  }

  @override
  void dispose() {
    VoiceService.instance.onSpeechResult = null;
    VoiceService.instance.onListeningChanged = null;
    _glitchController.dispose();
    _flickerTimer?.cancel();
    super.dispose();
  }

  void _onCornerTapped() {
    final now = DateTime.now();
    if (_lastCornerTap == null || now.difference(_lastCornerTap!).inMilliseconds < 1200) {
      _secretCornerTaps++;
    } else {
      _secretCornerTaps = 1;
    }
    _lastCornerTap = now;

    HapticFeedback.mediumImpact();

    if (_secretCornerTaps >= 4) {
      _service.disarm();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onEmergencyDoubleTap() {
    HapticFeedback.heavyImpact();
    _service.disarm();
    if (mounted) Navigator.of(context).pop();
  }

  void _onScreenTapped() {
    _service.recordIntruderTouch();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button exit
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final breaches = _service.breachAttemptCount;

            return Stack(
              children: [
                // Glitch background CRT Scanlines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrtScanlinePainter(glitchValue: _glitchController.value),
                  ),
                ),

                // Main Alarm Content
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onScreenTapped,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Alarming pulsing icon
                          AnimatedBuilder(
                            animation: _glitchController,
                            builder: (context, child) {
                              final scale = 1.0 + (_glitchController.value * 0.12);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: _flickerState ? Colors.redAccent : Colors.red,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.5),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 64,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 28),

                          // Header
                          const Text(
                            'CRITICAL KERNEL PANIC',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'HARDWARE ISOLATION PROTOCOL // CODE BLACK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Breach count card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A0505),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.security, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'TAMPER VIOLATIONS: $breaches',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'BIOMETRIC DATA & FRONT CAMERA STREAM BROADCASTING TO SECURE CLOUD',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontFamily: 'monospace',
                                    fontSize: 9.5,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Terminal hex dump logs
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: ListView.builder(
                              itemCount: _fakeLogs.length,
                              itemBuilder: (context, idx) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '> ${_fakeLogs[idx]}',
                                    style: TextStyle(
                                      color: idx == 0 ? Colors.redAccent : Colors.white38,
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'SECURE SYSTEM MEMORY DUMP: 0x${_rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right corner: 4-tap secret override
                Positioned(
                  top: 0,
                  right: 0,
                  width: 90,
                  height: 90,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onCornerTapped,
                    child: Container(
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.all(14),
                      color: Colors.transparent,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _flickerState
                              ? Colors.red.withValues(alpha: 0.35)
                              : Colors.red.withValues(alpha: 0.10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Emergency Override Bar (Double-Tap or Long-Press to Disarm)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _onEmergencyDoubleTap,
                    onLongPress: _onEmergencyDoubleTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF140303).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open, size: 14, color: Colors.redAccent.withValues(alpha: 0.75)),
                          const SizedBox(width: 8),
                          Text(
                            'EMERGENCY OVERRIDE // DOUBLE-TAP TO DISARM',
                            style: TextStyle(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CrtScanlinePainter extends CustomPainter {
  final double glitchValue;
  _CrtScanlinePainter({required this.glitchValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.04 + (glitchValue * 0.02))
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrtScanlinePainter oldDelegate) => true;
}
