import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../theme/app_theme.dart';

/// Root widget of the system-wide floating overlay engine (runs in its own isolate).
///
/// Collapsed: A Stark Arc Reactor holographic bubble with 3-state real-time colors:
///   - Electric Cyan: Idle / Standby
///   - Emerald Green: Listening / Speech active
///   - Solar Gold: Computing / Thinking / Summarizing / Speaking
///
/// Expanded: A Glassmorphic HUD panel featuring:
///   - One-tap "Summarize Screen Article" tool
///   - Quick actions for Sentry Watchdog, Hardware Specs, and Screen Time
///   - Live Screen Summary card
///   - Agent Task transcript & command controls
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp>
    with SingleTickerProviderStateMixin {
  static const _bubbleSize = 110;
  static const _panelWidth = 330;
  static const _panelHeight = 360;

  StreamSubscription<dynamic>? _subscription;
  late final AnimationController _reactorController;

  bool _expanded = false;

  // GENY Real-Time Phase State
  String _genyPhase = 'idle'; // 'idle', 'listening', 'thinking', 'speaking', 'executing'
  String _genyStatus = 'STANDBY // SAY "HEY GENY"';
  String? _screenSummary;
  String _summaryTitle = 'Screen Article Summary';

  bool get _busy =>
      _genyPhase == 'thinking' ||
      _genyPhase == 'speaking' ||
      _genyPhase == 'executing';

  Color get _currentColor {
    if (_genyPhase == 'listening') {
      return const Color(0xFF00E676); // Emerald Green (Listening)
    }
    if (_busy) {
      return const Color(0xFFFFB300); // Solar Gold / Amber (Computing / Speaking)
    }
    return const Color(0xFF00E5FF); // Electric Cyan (Standby)
  }

  @override
  void initState() {
    super.initState();
    _reactorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _subscription =
        FlutterOverlayWindow.overlayListener.listen(_onMainAppEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reactorController.dispose();
    super.dispose();
  }

  void _onMainAppEvent(dynamic event) {
    if (event is! String) return;
    try {
      final decoded = jsonDecode(event);
      if (decoded is! Map) return;

      final type = decoded['type'];
      if (type == 'geny_state') {
        setState(() {
          _genyPhase = decoded['phase']?.toString() ?? _genyPhase;
          _genyStatus = decoded['status']?.toString() ?? _genyStatus;
        });
      } else if (type == 'screen_summary') {
        setState(() {
          _screenSummary = decoded['summary']?.toString();
          _summaryTitle = decoded['title']?.toString() ?? 'Screen Article Summary';
        });
        if (!_expanded) {
          _expand();
        }
      }
    } catch (_) {}
  }

  void _sendCommand(Map<String, dynamic> payload) {
    FlutterOverlayWindow.shareData(jsonEncode({
      'type': 'command',
      ...payload,
    }));
  }

  Future<void> _expand() async {
    setState(() => _expanded = true);
    await FlutterOverlayWindow.resizeOverlay(
        _panelWidth, _panelHeight, false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
  }

  Future<void> _collapse() async {
    setState(() => _expanded = false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(_bubbleSize, _bubbleSize, true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Material(
        type: MaterialType.transparency,
        child: _expanded ? _buildPanel() : _buildBubble(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Floating Arc Reactor Holographic Bubble
  // ------------------------------------------------------------------

  Widget _buildBubble() {
    final color = _currentColor;
    final isListening = _genyPhase == 'listening';
    final isComputing = _busy;

    return Center(
      child: GestureDetector(
        onTap: _expand,
        child: AnimatedBuilder(
          animation: _reactorController,
          builder: (context, child) {
            final angle = _reactorController.value * 2 * math.pi * (isComputing ? 2.5 : 1.0);
            return Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isListening ? 0.75 : 0.5),
                    blurRadius: isListening ? 22 : 16,
                    spreadRadius: isListening ? 3 : 1,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: ArcReactorPainter(
                  coreColor: color,
                  rotationAngle: angle,
                  isPulsing: isListening || isComputing,
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.8),
                      border: Border.all(color: color, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening
                          ? Icons.mic
                          : isComputing
                              ? Icons.auto_awesome
                              : Icons.bolt,
                      color: color,
                      size: 14,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Holographic Glassmorphism Panel (Dedicated Clean Summary View)
  // ------------------------------------------------------------------

  Widget _buildPanel() {
    final color = _currentColor;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xEE080D1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panelHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: _screenSummary != null
                      ? _buildSummaryContent()
                      : _buildEmptyPrompt(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelHeader() {
    final color = _currentColor;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(Icons.bolt, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              const Text(
                'G.E.N.Y.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  _genyPhase.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
          onPressed: _collapse,
        ),
      ],
    );
  }

  Widget _buildSummaryContent() {
    final color = _currentColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _summaryTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                _screenSummary ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Rescan', style: TextStyle(fontSize: 11)),
                  onPressed: () => _sendCommand({'command': 'summarize_screen'}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.volume_up, size: 14),
                  label: const Text('Read Aloud', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    if (_screenSummary != null) {
                      _sendCommand({'command': 'geny_command', 'goal': 'speak ${_screenSummary!}'});
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.article_outlined, color: Color(0xFF00E5FF), size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'Screen Article Summarizer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Open any article or browser page,\nthen tap below for an executive summary.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFF00E5FF),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Summarize Current Screen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _sendCommand({'command': 'summarize_screen'}),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Arc Reactor Holographic Custom Painter
// ------------------------------------------------------------------

class ArcReactorPainter extends CustomPainter {
  final Color coreColor;
  final double rotationAngle;
  final bool isPulsing;

  ArcReactorPainter({
    required this.coreColor,
    required this.rotationAngle,
    required this.isPulsing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dark circular backing
    final bgPaint = Paint()
      ..color = const Color(0xEE050B14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, bgPaint);

    // 2. Outer metallic ring
    final outerRing = Paint()
      ..color = coreColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius - 4, outerRing);

    // 3. Inner containment ring
    final innerRing = Paint()
      ..color = coreColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 14, innerRing);

    // 4. Rotating Arc segments / Coils (10 segments)
    final coilPaint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    const segmentCount = 10;
    const arcLength = (2 * math.pi / segmentCount) * 0.6;
    final arcRadius = radius - 9;

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = rotationAngle + (i * 2 * math.pi / segmentCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        arcLength,
        false,
        coilPaint,
      );
    }

    // 5. Ambient core glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          coreColor.withValues(alpha: isPulsing ? 0.9 : 0.6),
          coreColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 12));
    canvas.drawCircle(center, radius - 12, glowPaint);
  }

  @override
  bool shouldRepaint(covariant ArcReactorPainter oldDelegate) {
    return oldDelegate.coreColor != coreColor ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.isPulsing != isPulsing;
  }
}
