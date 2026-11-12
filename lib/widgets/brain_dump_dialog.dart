import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/multi_task_service.dart';
import '../services/voice_service.dart';

/// 🧠 Interactive HUD Dialog for the "Chaotic Brain Dump" Multi-Task Decoupler
/// Allows typing or dictating compound rambling instructions, disassembling them
/// into discrete atomic tasks, executing them concurrently, and inspecting real-time results.
class BrainDumpDialog extends StatefulWidget {
  const BrainDumpDialog({super.key});

  @override
  State<BrainDumpDialog> createState() => _BrainDumpDialogState();
}

class _BrainDumpDialogState extends State<BrainDumpDialog> {
  final MultiTaskDecouplerService _service = MultiTaskDecouplerService.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDictating = false;
  String? _lastSummary;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startDictation() {
    setState(() => _isDictating = true);
    HapticFeedback.mediumImpact();

    VoiceService.instance.startListening(
      manual: true,
      onResult: (text, isFinal, candidates) {
        if (!mounted) return;
        if (text.trim().isNotEmpty) {
          _textController.text = text;
        }
        if (isFinal) {
          setState(() => _isDictating = false);
        }
      },
    );
  }

  Future<void> _processDump() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();

    final summary = await _service.processBrainDump(text);
    if (!mounted) return;

    setState(() {
      _lastSummary = summary;
    });

    VoiceService.instance.speak(summary);
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          height: 600,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1522).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cyan.withValues(alpha: 0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.25),
                blurRadius: 32,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final isProcessing = _service.isProcessing;
              final tasks = _service.lastExecutedTasks;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        child: const Icon(Icons.alt_route_rounded, color: cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MULTI-TASK DECOUPLER',
                              style: TextStyle(
                                color: cyan,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              'Chaotic Brain Dump Parallel Engine',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input box with dictation button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDictating
                            ? const Color(0xFFFF5252)
                            : cyan.withValues(alpha: 0.3),
                        width: _isDictating ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 3,
                            minLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Dictate or type multiple requests...\ne.g. "Remind me to call Elon at 5 and note AI thoughts and calculate 18% of 500 and turn on flashlight"',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11.5,
                              ),
                              contentPadding: const EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isDictating ? Icons.mic : Icons.mic_none,
                            color: _isDictating ? const Color(0xFFFF5252) : cyan,
                          ),
                          onPressed: _startDictation,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Execute Button
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : _processDump,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.bolt, size: 16),
                    label: Text(
                      isProcessing
                          ? 'DECONSTRUCTING INTENTS...'
                          : 'EXECUTE PARALLEL DECOUPLING',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Results header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PARALLEL DISPATCH LEDGER (${tasks.length})',
                        style: TextStyle(
                          color: cyan.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Text(
                          '${tasks.where((t) => t.executionStatus == 'success' || t.executionStatus == 'completed').length}/${tasks.length} Resolved',
                          style: TextStyle(
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Decoupled Tasks List
                  Expanded(
                    child: tasks.isEmpty
                        ? Center(
                            child: Text(
                              'No active decoupled tasks.\nEnter multiple compound tasks above or say\n"Hey Geny, brain dump..."',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              final isSuccess = task.executionStatus == 'success' ||
                                  task.executionStatus == 'completed';
                              final isFailed = task.executionStatus == 'failed';
                              final statusColor = isSuccess
                                  ? Colors.greenAccent
                                  : (isFailed ? Colors.redAccent : cyan);

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        task.type.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.description,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (task.resultSummary != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              task.resultSummary!,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.65),
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isSuccess
                                          ? Icons.check_circle_outline
                                          : (isFailed ? Icons.error_outline : Icons.hourglass_top),
                                      color: statusColor,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Summary Banner
                  if (_lastSummary != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, color: cyan, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastSummary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: cyan,
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
