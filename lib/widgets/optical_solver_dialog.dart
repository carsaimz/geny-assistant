import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/optical_solver_service.dart';

/// 👁️ Real-Time Optical HUD Solver Dialog
class OpticalSolverDialog extends StatefulWidget {
  const OpticalSolverDialog({super.key});

  @override
  State<OpticalSolverDialog> createState() => _OpticalSolverDialogState();
}

class _OpticalSolverDialogState extends State<OpticalSolverDialog>
    with SingleTickerProviderStateMixin {
  final OpticalSolverService _service = OpticalSolverService.instance;
  late AnimationController _scanLaserController;

  @override
  void initState() {
    super.initState();
    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLaserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFB300);
    const cyan = Color(0xFF00E5FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          height: 580,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF140D05).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.20),
                blurRadius: 32,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final isSolving = _service.isSolving;
              final result = _service.lastResult;

              return Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gold.withValues(alpha: 0.15),
                          border: Border.all(color: gold.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.document_scanner_outlined, color: gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OPTICAL HUD SOLVER',
                              style: TextStyle(
                                color: gold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'POINT & SOLVE LIVE AR MATRIX',
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

                  const SizedBox(height: 14),

                  // Mode Selector Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _modeChip(OpticalSolveMode.auto, 'Auto'),
                      _modeChip(OpticalSolveMode.math, 'Math'),
                      _modeChip(OpticalSolveMode.codeDebug, 'Code'),
                      _modeChip(OpticalSolveMode.billSplit, 'Bill'),
                      _modeChip(OpticalSolveMode.circuit, 'Circuit'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Optical HUD Reticle Box
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Corner brackets
                        const Positioned(top: 8, left: 8, child: Icon(Icons.crop_free, color: gold, size: 24)),
                        const Positioned(bottom: 8, right: 8, child: Icon(Icons.crop_free, color: gold, size: 24)),

                        // Animated scanning laser line
                        if (isSolving)
                          AnimatedBuilder(
                            animation: _scanLaserController,
                            builder: (context, child) {
                              return Positioned(
                                top: 10 + (_scanLaserController.value * 115),
                                left: 16,
                                right: 16,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: gold,
                                    boxShadow: [
                                      BoxShadow(
                                        color: gold.withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSolving ? Icons.camera : Icons.camera_alt_outlined,
                                color: isSolving ? gold : Colors.white24,
                                size: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isSolving ? 'ANALYZING PHYSICAL TARGET...' : 'AIM CAMERA AT SUBJECT & SOLVE',
                                style: TextStyle(
                                  color: isSolving ? gold : Colors.white38,
                                  fontFamily: 'monospace',
                                  fontSize: 9.5,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Results Card
                  Expanded(
                    child: result == null
                        ? Center(
                            child: Text(
                              'Tap "POINT & SOLVE" to resolve math formulas, screen stack traces, restaurant split bills, or electronics in real time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: gold.withValues(alpha: 0.3)),
                            ),
                            child: ListView(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        result.title,
                                        style: const TextStyle(
                                          color: gold,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(result.confidence * 100).toInt()}% Confidence',
                                      style: const TextStyle(
                                        color: cyan,
                                        fontFamily: 'monospace',
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 16),
                                Text(
                                  result.solution,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                if (result.keyMetrics.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: result.keyMetrics.entries.map((e) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: gold.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: gold.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          '${e.key}: ${e.value}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Trigger Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: gold, width: 1.2),
                        ),
                      ),
                      onPressed: isSolving
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _service.pointAndSolve();
                            },
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: Text(
                        isSolving ? 'COMPUTING RESOLUTION...' : 'POINT & SOLVE',
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

  Widget _modeChip(OpticalSolveMode mode, String label) {
    final isSelected = _service.activeMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _service.activeMode = mode;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFB300) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB300) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

