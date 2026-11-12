import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/task_executor.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/status_chip.dart';

/// Read-only replay of one past task session, rendered back into the same
/// chat bubbles used by the live transcript.
class SessionDetailScreen extends StatefulWidget {
  final String entryId;

  const SessionDetailScreen({super.key, required this.entryId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _executor = TaskExecutor.instance;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _executor.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _executor.removeListener(_onUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  static final _logLineRe = RegExp(r'^\[(\w+)(?: #(\d+))?\] ([\s\S]*)$');

  /// Reverses [TaskExecutor]'s run-log line format back into chat messages.
  List<ChatMessage> _parseLogs(List<String> logs) {
    return logs.map((line) {
      final match = _logLineRe.firstMatch(line.trim());
      if (match == null) {
        return ChatMessage.system(line);
      }
      final role = ChatRole.values.firstWhere(
        (r) => r.name == match.group(1),
        orElse: () => ChatRole.system,
      );
      final step = int.tryParse(match.group(2) ?? '');
      return ChatMessage(
        role: role,
        text: match.group(3) ?? '',
        step: step,
        markdown: role == ChatRole.agent,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _executor.historyEntries
        .where((e) => e.id == widget.entryId)
        .firstOrNull;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: Center(
          child: Text('This session was deleted.',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final messages = _parseLogs(entry.logs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          entry.goal,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusChip.forTaskStatus(entry.status)),
          ),
        ],
      ),
      body: messages.isEmpty
          ? Center(
              child: Text('(no transcript recorded)',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: messages.length,
              itemBuilder: (_, i) => ChatBubble(message: messages[i]),
            ),
    );
  }
}
