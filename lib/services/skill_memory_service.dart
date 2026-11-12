import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill.dart';
import '../models/task_step.dart';

/// Local "macro replay" memory: stores successful action sequences per goal
/// so repeated tasks skip LLM calls entirely.
///
/// Storage: SharedPreferences key `skill_memory_v1` (JSON list). Kept
/// deliberately simple — skills are small and few.
class SkillMemoryService {
  SkillMemoryService._();
  static final SkillMemoryService instance = SkillMemoryService._();

  static const _storageKey = 'skill_memory_v1';
  static const _matchThreshold = 0.75;
  static const _maxSkills = 100;

  List<Skill>? _cache;

  Future<List<Skill>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }
    try {
      final decoded = jsonDecode(raw);
      _cache = decoded is List
          ? decoded
              .whereType<Map>()
              .map((e) => Skill.fromJson(e.map((k, v) => MapEntry('$k', v))))
              .toList()
          : <Skill>[];
    } catch (_) {
      _cache = <Skill>[];
    }
    return _cache!;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final skills = _cache ?? const <Skill>[];
    await prefs.setString(
      _storageKey,
      jsonEncode(skills.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<Skill>> all() async => List.unmodifiable(await _load());

  /// Finds a stored skill matching [goal]: exact normalized match first,
  /// then token Jaccard similarity >= 0.75.
  Future<Skill?> findMatch(String goal) async {
    final normalized = Skill.normalize(goal);
    if (normalized.isEmpty) return null;
    final skills = await _load();

    for (final s in skills) {
      if (s.normalizedGoal == normalized) return s;
    }
    Skill? best;
    var bestScore = 0.0;
    for (final s in skills) {
      final score = Skill.similarity(normalized, s.normalizedGoal);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return bestScore >= _matchThreshold ? best : null;
  }

  /// Stores (or refreshes) the action sequence for [goal]. Terminal `done`
  /// steps are stripped since replay ends when the list is exhausted.
  Future<Skill> saveOrUpdate(String goal, List<TaskStep> steps) async {
    final skills = await _load();
    final cleaned = steps
        .where((s) => s.action != TaskStep.actionDone && s.isSupported)
        .toList();
    final normalized = Skill.normalize(goal);

    final existingIndex =
        skills.indexWhere((s) => s.normalizedGoal == normalized);
    if (existingIndex >= 0) {
      final existing = skills[existingIndex];
      final updated = Skill(
        id: existing.id,
        goal: goal,
        steps: cleaned,
        successCount: existing.successCount,
        lastUsedAt: DateTime.now(),
        createdAt: existing.createdAt,
      );
      skills[existingIndex] = updated;
      await _persist();
      return updated;
    }

    final skill = Skill(goal: goal, steps: cleaned);
    skills.insert(0, skill);
    if (skills.length > _maxSkills) {
      skills.removeRange(_maxSkills, skills.length);
    }
    await _persist();
    return skill;
  }

  Future<void> markReplayOutcome(String skillId, {required bool success}) async {
    final skills = await _load();
    final index = skills.indexWhere((s) => s.id == skillId);
    if (index < 0) return;
    if (success) {
      skills[index].successCount += 1;
      skills[index].lastUsedAt = DateTime.now();
    } else {
      // A skill that failed to replay is likely stale (app UI changed):
      // drop it so the next run relearns from the AI.
      skills.removeAt(index);
    }
    await _persist();
  }

  Future<void> delete(String skillId) async {
    final skills = await _load();
    skills.removeWhere((s) => s.id == skillId);
    await _persist();
  }

  Future<void> clear() async {
    _cache = [];
    await _persist();
  }
}
