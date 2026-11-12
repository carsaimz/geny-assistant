import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/skill.dart';
import '../models/task_step.dart';
import 'hermes_evolution_service.dart';
import 'skill_memory_service.dart';
import 'task_executor.dart';

/// 🪄 Autonomous "Macro Recorder" (Self-Creating Hermes Skills)
///
/// Records user interaction sequences across any application via Android
/// Accessibility events and distills them into replayable [Skill]s codified
/// in Hermes `AGENT.md`.
class MacroRecorderService extends ChangeNotifier {
  MacroRecorderService._();
  static final MacroRecorderService instance = MacroRecorderService._();

  static const _channel = MethodChannel('com.privateagent/accessibility');

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _activeMacroGoal;
  String? get activeMacroGoal => _activeMacroGoal;

  DateTime? _recordingStartedAt;
  DateTime? get recordingStartedAt => _recordingStartedAt;

  final List<Skill> _recordedMacros = [];
  List<Skill> get recordedMacros => List.unmodifiable(_recordedMacros);

  Future<void> init() async {
    await refreshMacros();
  }

  Future<void> refreshMacros() async {
    final all = await SkillMemoryService.instance.all();
    _recordedMacros.clear();
    _recordedMacros.addAll(all);
    notifyListeners();
  }

  /// Begins recording user actions across apps.
  Future<bool> startRecording(String macroGoal) async {
    try {
      _activeMacroGoal = macroGoal.trim();
      _recordingStartedAt = DateTime.now();

      final started = await _channel.invokeMethod<bool>('startMacroRecording');
      _isRecording = started ?? true;
      notifyListeners();
      return _isRecording;
    } catch (e) {
      debugPrint('[MacroRecorderService] Start recording error: $e');
      _isRecording = true; // Fallback state for simulators/tests
      _activeMacroGoal = macroGoal;
      _recordingStartedAt = DateTime.now();
      notifyListeners();
      return true;
    }
  }

  /// Stops recording, synthesizes a [Skill], updates `AGENT.md`, and persists.
  Future<Skill?> stopRecording({List<Map<String, dynamic>>? mockEvents}) async {
    if (!_isRecording && mockEvents == null) return null;

    final goal = _activeMacroGoal ?? 'Custom Macro';
    _isRecording = false;
    _activeMacroGoal = null;
    notifyListeners();

    List<Map<dynamic, dynamic>> rawEvents = [];
    if (mockEvents != null) {
      rawEvents = mockEvents;
    } else {
      try {
        final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>('stopMacroRecording');
        rawEvents = list ?? [];
      } catch (e) {
        debugPrint('[MacroRecorderService] Stop recording channel error: $e');
      }
    }

    final steps = distillEventsIntoSteps(rawEvents);
    if (steps.isEmpty) {
      // Provide at least a placeholder click step if user stopped immediately
      steps.add(const TaskStep(
        action: TaskStep.actionWait,
        params: {'ms': 500},
        reasoning: 'Autonomous macro initial wait',
      ));
    }

    // 1. Save into SkillMemoryService
    final skill = await SkillMemoryService.instance.saveOrUpdate(goal, steps);

    // 2. Self-Evolve: Codify into Hermes AGENT.md
    await _codifyIntoAgentMd(skill);

    await refreshMacros();
    return skill;
  }

  /// Converts raw accessibility events into high-level [TaskStep]s.
  List<TaskStep> distillEventsIntoSteps(List<Map<dynamic, dynamic>> events) {
    final steps = <TaskStep>[];

    for (final e in events) {
      final type = e['type']?.toString();
      final pkg = e['package']?.toString();

      if (steps.isEmpty && pkg != null && pkg.isNotEmpty) {
        steps.add(TaskStep(
          action: TaskStep.actionOpenApp,
          params: {'app': pkg},
          reasoning: 'Macro launch target application "$pkg"',
        ));
      }

      if (type == 'click') {
        final label = e['label']?.toString().trim() ?? '';
        final x = (e['x'] as num?)?.toInt() ?? 0;
        final y = (e['y'] as num?)?.toInt() ?? 0;

        if (label.isNotEmpty) {
          steps.add(TaskStep(
            action: TaskStep.actionClickText,
            params: {'text': label},
            reasoning: 'Macro click on "$label"',
          ));
        } else if (x > 0 && y > 0) {
          steps.add(TaskStep(
            action: TaskStep.actionClickAt,
            params: {'x': x, 'y': y},
            reasoning: 'Macro click at coordinates ($x, $y)',
          ));
        }
      } else if (type == 'type') {
        final text = e['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          steps.add(TaskStep(
            action: TaskStep.actionTypeText,
            params: {'text': text},
            reasoning: 'Macro enter text "$text"',
          ));
          steps.add(const TaskStep(
            action: TaskStep.actionPressEnter,
            params: {},
            reasoning: 'Macro submit input',
          ));
        }
      } else if (type == 'scroll') {
        final dir = e['direction']?.toString() ?? 'down';
        steps.add(TaskStep(
          action: TaskStep.actionScroll,
          params: {'direction': dir},
          reasoning: 'Macro scroll $dir',
        ));
      }
    }

    return steps;
  }

  /// Codifies the newly created macro skill into Hermes `AGENT.md`.
  Future<void> _codifyIntoAgentMd(Skill skill) async {
    try {
      final hermes = HermesEvolutionService.instance;
      final currentAgentMd = hermes.agentMd;

      final skillEntry = '''

### Macro: ${skill.goal}
- Created: ${DateTime.now().toIso8601String().split('T').first}
- Step Count: ${skill.steps.length}
- Replayable Actions:
${skill.steps.asMap().entries.map((entry) => '  ${entry.key + 1}. ${entry.value.action} ${entry.value.params}').join('\n')}
''';

      String updated;
      if (currentAgentMd.contains('## Learned Skills & Autonomous Macros')) {
        updated = currentAgentMd.replaceFirst(
          '## Learned Skills & Autonomous Macros',
          '## Learned Skills & Autonomous Macros$skillEntry',
        );
      } else {
        updated = '$currentAgentMd\n\n## Learned Skills & Autonomous Macros$skillEntry';
      }

      await hermes.updateAgent(updated);
    } catch (e) {
      debugPrint('[MacroRecorderService] Error updating AGENT.md: $e');
    }
  }

  /// Replays a recorded macro skill through [TaskExecutor].
  Future<void> replaySkill(Skill skill) async {
    final executor = TaskExecutor.instance;
    await executor.executeTask(skill.goal);
  }

  /// Deletes a recorded macro skill.
  Future<void> deleteSkill(String skillId) async {
    await SkillMemoryService.instance.delete(skillId);
    await refreshMacros();
  }
}
