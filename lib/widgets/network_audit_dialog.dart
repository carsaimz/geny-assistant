import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_audit_service.dart';

/// 🛡️ Stark Network Cyber Security Audit Dialog
class NetworkAuditDialog extends StatefulWidget {
  const NetworkAuditDialog({super.key});

  @override
  State<NetworkAuditDialog> createState() => _NetworkAuditDialogState();
}

class _NetworkAuditDialogState extends State<NetworkAuditDialog> {
  final NetworkAuditService _service = NetworkAuditService.instance;

  @override
  void initState() {
    super.initState();
    _service.auditNetwork();
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const blue = Color(0xFF2979FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          height: 580,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF05121E).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cyan.withValues(alpha: 0.40), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: blue.withValues(alpha: 0.20),
                blurRadius: 32,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final isAuditing = _service.isAuditing;
              final report = _service.lastReport;

              return Column(
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
                        child: const Icon(Icons.shield_outlined, color: cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NETWORK SECURITY AUDIT',
                              style: TextStyle(
                                color: cyan,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'LOCAL SUBNET & PORT SWEEPER',
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

                  // Security Score Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cyan.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report != null ? '${report.securityScore} / 100' : 'SCANNING...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'CYBER DEFENSE POSTURE',
                              style: TextStyle(
                                color: cyan,
                                fontFamily: 'monospace',
                                fontSize: 9,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              report != null ? '${report.pingLatencyMs} ms' : '--',
                              style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              report != null ? report.subnetPrefix : 'Subnet',
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
                  ),

                  const SizedBox(height: 12),

                  // Vulnerabilities & Alerts
                  if (report != null && report.vulnerabilities.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: report.vulnerabilities.map((v) {
                          final isWarn = v.contains('Unencrypted') || v.contains('active on');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isWarn ? Icons.warning_amber : Icons.check_circle_outline,
                                  color: isWarn ? Colors.orangeAccent : const Color(0xFF00E676),
                                  size: 13,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    v,
                                    style: TextStyle(
                                      color: isWarn ? Colors.orangeAccent : Colors.white70,
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Connected Devices List
                  Expanded(
                    child: report == null
                        ? const Center(
                            child: CircularProgressIndicator(color: cyan),
                          )
                        : ListView.builder(
                            itemCount: report.devices.length,
                            itemBuilder: (context, idx) {
                              final dev = report.devices[idx];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: dev.isCameraStream
                                        ? Colors.orangeAccent.withValues(alpha: 0.5)
                                        : cyan.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      dev.isCameraStream
                                          ? Icons.videocam
                                          : (dev.isGateway ? Icons.router : Icons.devices),
                                      color: dev.isCameraStream ? Colors.orangeAccent : cyan,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dev.hostname,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${dev.ip} • ${dev.vendor}',
                                            style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (dev.openPorts.isNotEmpty)
                                      Wrap(
                                        spacing: 4,
                                        children: dev.openPorts.map((p) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: p == 554
                                                  ? Colors.orange.withValues(alpha: 0.25)
                                                  : cyan.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              ':$p',
                                              style: TextStyle(
                                                color: p == 554 ? Colors.orangeAccent : cyan,
                                                fontFamily: 'monospace',
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
                        backgroundColor: cyan.withValues(alpha: 0.20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: cyan, width: 1.2),
                        ),
                      ),
                      onPressed: isAuditing
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _service.auditNetwork();
                            },
                      icon: const Icon(Icons.security, size: 18),
                      label: Text(
                        isAuditing ? 'AUDITING SUBNET...' : 'RUN FULL NETWORK AUDIT',
                        style: const TextStyle(
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

