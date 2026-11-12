import 'package:uuid/uuid.dart';

/// Final outcome of a task run.
enum TaskStatus { success, failed, cancelled }

/// A persisted record of one executed task (shown in the history screen).
class TaskHistoryEntry {
  static const _uuid = Uuid();

  final String id;
  final String goal;
  final TaskStatus status;
  final int steps;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<String> logs;

  TaskHistoryEntry({
    String? id,
    required this.goal,
    required this.status,
    required this.steps,
    required this.startedAt,
    this.finishedAt,
    this.logs = const [],
  }) : id = id ?? _uuid.v4();

  Duration? get duration => finishedAt?.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'goal': goal,
        'status': status.name,
        'steps': steps,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'logs': logs,
      };

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TaskHistoryEntry(
        id: json['id']?.toString(),
        goal: json['goal']?.toString() ?? '',
        status: TaskStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TaskStatus.failed,
        ),
        steps: json['steps'] is int
            ? json['steps'] as int
            : int.tryParse('${json['steps']}') ?? 0,
        startedAt:
            DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        finishedAt: DateTime.tryParse(json['finishedAt']?.toString() ?? ''),
        logs: json['logs'] is List
            ? (json['logs'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}
