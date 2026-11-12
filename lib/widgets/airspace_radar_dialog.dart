import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/airspace_radar_service.dart';

/// 📡 Overhead Airspace & Satellite Radar HUD Dialog
class AirspaceRadarDialog extends StatefulWidget {
  const AirspaceRadarDialog({super.key});

  @override
  State<AirspaceRadarDialog> createState() => _AirspaceRadarDialogState();
}

class _AirspaceRadarDialogState extends State<AirspaceRadarDialog>
    with SingleTickerProviderStateMixin {
  final AirspaceRadarService _service = AirspaceRadarService.instance;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _service.scanAirspace();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00E676);
    const cyan = Color(0xFF00E5FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          height: 560,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF061512).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: green.withValues(alpha: 0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.2),
                blurRadius: 32,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final flights = _service.nearbyFlights;
              final iss = _service.issPass;

              return Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withValues(alpha: 0.15),
                          border: Border.all(color: green.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.radar, color: green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OVERHEAD AIRSPACE RADAR',
                              style: TextStyle(
                                color: green,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'LIVE ADS-B & SATELLITE TRACKING',
                              style: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'monospace',
                                fontSize: 9.0,
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

                  const SizedBox(height: 16),

                  // Radar Scope Display
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: green.withValues(alpha: 0.3)),
                    ),
                    child: AnimatedBuilder(
                      animation: _sweepController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _RadarScopePainter(
                            angle: _sweepController.value * 2 * pi,
                            aircraftCount: flights.length,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${flights.length} CONTACTS',
                                  style: const TextStyle(
                                    color: green,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const Text(
                                  'SECTOR RANGE: 40 NM',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ISS Satellite Card
                  if (iss != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.satellite_alt, color: cyan, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ISS Orbital Pass: ${iss.distanceFromUserKm.toInt()} km away (Alt: ${iss.altitudeKm.toInt()} km)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Aircraft List
                  Expanded(
                    child: ListView.builder(
                      itemCount: flights.length,
                      itemBuilder: (context, idx) {
                        final f = flights[idx];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: green.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flight, color: green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.callsign,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${f.originCountry} • ${f.compassDirection} at ${f.velocityKnots.toInt()} kts',
                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${f.altitudeFeet.toInt()} ft',
                                    style: const TextStyle(
                                      color: green,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${f.distanceMiles.toStringAsFixed(1)} mi',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Rescan Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green.withValues(alpha: 0.20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: green, width: 1.2),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _service.scanAirspace();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'RE-SCAN AIRSPACE SECTOR',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
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
}

class _RadarScopePainter extends CustomPainter {
  final double angle;
  final int aircraftCount;
  _RadarScopePainter({required this.angle, required this.aircraftCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    final gridPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Rings
    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius * 0.33, gridPaint);

    // Crosshairs
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // Sweep line
    final sweepEnd = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
    final sweepPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.7)
      ..strokeWidth = 1.8;
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Sweep trail
    final trailPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          const Color(0xFF00E676).withValues(alpha: 0.25),
        ],
        transform: GradientRotation(angle - 0.5),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, trailPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarScopePainter oldDelegate) => true;
}

