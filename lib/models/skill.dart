import 'package:uuid/uuid.dart';

import 'task_step.dart';

/// A memorized, previously successful action sequence for a goal
/// ("macro replay"). Stored locally by `SkillMemoryService` so identical or
/// very similar goals can be executed without calling the LLM again.
class Skill {
  static const _uuid = Uuid();

  final String id;

  /// Original natural-language goal that produced this skill.
  final String goal;

  /// Lowercased, whitespace-collapsed form used for matching.
  final String normalizedGoal;

  /// The successful action sequence (without the terminal `done` step).
  final List<TaskStep> steps;

  /// How many times this skill replayed successfully.
  int successCount;

  DateTime lastUsedAt;
  final DateTime createdAt;

  Skill({
    String? id,
    required this.goal,
    required this.steps,
    this.successCount = 0,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        normalizedGoal = normalize(goal),
        lastUsedAt = lastUsedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  static String normalize(String input) =>
      input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  static Set<String> _tokens(String normalized) => normalized
      .split(' ')
      .where((t) => t.length > 2)
      .toSet();

  /// Jaccard similarity between token sets of two normalized goals.
  static double similarity(String normalizedA, String normalizedB) {
    final a = _tokens(normalizedA);
    final b = _tokens(normalizedB);
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'goal': goal,
        'steps': steps.map((s) => s.toJson()).toList(),
        'successCount': successCount,
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id']?.toString(),
        goal: json['goal']?.toString() ?? '',
        steps: json['steps'] is List
            ? (json['steps'] as List)
                .whereType<Map>()
                .map((e) =>
                    TaskStep.fromJson(e.map((k, v) => MapEntry('$k', v))))
                .toList()
            : const [],
        successCount: json['successCount'] is int
            ? json['successCount'] as int
            : int.tryParse('${json['successCount']}') ?? 0,
        lastUsedAt: DateTime.tryParse(json['lastUsedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
