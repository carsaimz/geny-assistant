import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/task_history_entry.dart';
import '../../services/task_executor.dart';
import '../../widgets/status_chip.dart';

/// Detailed list of past tasks with status, step counts and full logs.
class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  final _executor = TaskExecutor.instance;

  @override
  void initState() {
    super.initState();
    _executor.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _executor.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All recorded task runs will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) await _executor.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _executor.historyEntries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No tasks yet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Run your first task from the home screen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _entryTile(entries[i]),
            ),
    );
  }

  Widget _entryTile(TaskHistoryEntry entry) {
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd().add_Hm().format(entry.startedAt);
    final duration = entry.duration;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _executor.deleteHistoryEntry(entry.id),
      child: Card(
        child: ExpansionTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            entry.goal,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$date • ${entry.steps} step(s)'
              '${duration != null ? ' • ${duration.inSeconds}s' : ''}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          trailing: StatusChip.forTaskStatus(entry.status),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => SharePlus.instance.share(ShareParams(
                  text: 'Task: ${entry.goal}\n'
                      'Status: ${entry.status.name} • ${entry.steps} steps\n\n'
                      '${entry.logs.join('\n')}',
                  subject: 'Geny task log',
                )),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share log'),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                entry.logs.isEmpty ? '(no logs)' : entry.logs.join('\n'),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
