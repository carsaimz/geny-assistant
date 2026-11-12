import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/screen_node.dart';
import '../models/skill.dart';
import '../models/task_history_entry.dart';
import '../models/task_step.dart';
import 'ai_service.dart';
import 'app_launcher_service.dart';
import 'recovery_engine.dart';
import 'screen_automation_service.dart';
import 'settings_service.dart';
import 'skill_memory_service.dart';
import 'system_control_service.dart';
import 'voice_service.dart';

enum ExecutorState { idle, running, paused }

/// The heart of Geny: the observe -> think -> act feedback loop.
///
/// 1. Verifies the accessibility service is enabled.
/// 2. Tries skill-memory replay (macro) before spending LLM tokens.
/// 3. Otherwise loops: dump screen -> ask LLM for one JSON action ->
///    execute -> repeat, with step caps, repeat-action detection and a
///    [RecoveryEngine] for stuck states.
class TaskExecutor extends ChangeNotifier {
  TaskExecutor._();
  static final TaskExecutor instance = TaskExecutor._();

  static const _historyKey = 'task_history_v1';
  static const _maxHistoryEntries = 50;
  static const _maxHistoryTurns = 6;

  final ScreenAutomationService _automation = ScreenAutomationService.instance;
  final AiService _ai = AiService.instance;
  final AppLauncherService _apps = AppLauncherService.instance;
  final SkillMemoryService _skills = SkillMemoryService.instance;
  final RecoveryEngine _recovery = RecoveryEngine();

  final List<ChatMessage> logs = [];
  final List<TaskHistoryEntry> historyEntries = [];

  ExecutorState state = ExecutorState.idle;
  String? currentGoal;
  int step = 0;

  bool _cancelRequested = false;
  bool _usedSkillReplay = false;
  final List<TaskStep> _executedSteps = [];
  final List<String> _runLogLines = [];
  DateTime? _startedAt;

  bool get isRunning => state == ExecutorState.running;
  bool get isPaused => state == ExecutorState.paused;
  bool get isBusy => state != ExecutorState.idle;

  /// Called when a task finishes so external integrations (Telegram) can
  /// push results back to the originating chat.
  void Function(String chatId, TaskHistoryEntry entry)? onTaskFinished;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          historyEntries
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (e) => TaskHistoryEntry.fromJson(
                  e.map((k, v) => MapEntry('$k', v)),
                ),
              ),
            );
        }
      } catch (_) {}
    }
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = historyEntries.take(_maxHistoryEntries).toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteHistoryEntry(String id) async {
    historyEntries.removeWhere((e) => e.id == id);
    await _persistHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    historyEntries.clear();
    await _persistHistory();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Logging / broadcast helpers
  // ------------------------------------------------------------------

  void _log(ChatMessage message) {
    logs.add(message);
    if (logs.length > 200) logs.removeAt(0);
    _runLogLines.add(
      '[${message.role.name}${message.step != null ? ' #${message.step}' : ''}] ${message.text}',
    );
    notifyListeners();
    _broadcastOverlay();
  }

  /// Streams compact state to the floating overlay isolate (no-op when the
  /// overlay is not shown).
  Future<void> _broadcastOverlay() async {
    try {
      if (!await FlutterOverlayWindow.isActive()) return;
      final recent = logs
          .where((m) => m.role != ChatRole.system)
          .toList()
          .reversed
          .take(20)
          .toList()
          .reversed
          .map((m) => {'role': m.role.name, 'text': m.text, 'step': m.step})
          .toList();
      await FlutterOverlayWindow.shareData(
        jsonEncode({
          'type': 'state',
          'goal': currentGoal,
          'state': state.name,
          'step': step,
          'maxSteps': SettingsService.instance.maxSteps,
          'messages': recent,
        }),
      );
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Controls
  // ------------------------------------------------------------------

  void pause() {
    if (state == ExecutorState.running) {
      state = ExecutorState.paused;
      _log(ChatMessage.system('Task paused.'));
      notifyListeners();
      _broadcastOverlay();
    }
  }

  void resume() {
    if (state == ExecutorState.paused) {
      state = ExecutorState.running;
      _log(ChatMessage.system('Task resumed.'));
      notifyListeners();
      _broadcastOverlay();
    }
  }

  void cancel() {
    if (!isBusy) return;
    _cancelRequested = true;
    if (isPaused) state = ExecutorState.running; // unblock the wait loop
    _log(ChatMessage.system('Cancellation requested…'));
    notifyListeners();
  }

  /// Clears the live transcript so the user can start a fresh chat session.
  /// Ignored while a task is running (the transcript belongs to that run).
  void clearTranscript() {
    if (isBusy || _chatBusy) return;
    logs.clear();
    _chatHistory.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Chat mode (plain conversation, no device control)
  // ------------------------------------------------------------------

  /// Chat context is capped so long conversations stay within the
  /// model context window.
  static const _maxChatTurns = 20;

  bool _chatBusy = false;

  /// True while a Chat-mode message is waiting for the LLM reply.
  bool get isChatBusy => _chatBusy;

  /// Short-term conversational context for Chat mode.
  final List<Map<String, String>> _chatHistory = [];

  /// Sends a plain chat message and logs the LLM reply into the
  /// transcript. Unlike [executeTask] this never reads the screen,
  /// never touches the accessibility service and never replays skills.
  Future<void> sendChatMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || isBusy || _chatBusy) return;

    _chatBusy = true;
    _log(ChatMessage.user(message));
    notifyListeners();

    final agentMsg = ChatMessage.agent('');
    _log(agentMsg);
    notifyListeners();

    final fullResponseBuffer = StringBuffer();

    try {
      final stream = _ai.chatStream(
        message: message,
        history: List.of(_chatHistory),
      );

      await for (final token in stream) {
        fullResponseBuffer.write(token);
        agentMsg.text = fullResponseBuffer.toString();
        notifyListeners();
      }

      final reply = fullResponseBuffer.toString().trim();
      if (reply.isEmpty) {
        // Fallback if model yielded nothing
        final directReply = await _ai.chat(
          message: message,
          history: List.of(_chatHistory),
        );
        agentMsg.text = directReply;
        _chatHistory.add({'role': 'user', 'content': message});
        _chatHistory.add({'role': 'assistant', 'content': directReply});
      } else {
        _chatHistory.add({'role': 'user', 'content': message});
        _chatHistory.add({'role': 'assistant', 'content': reply});
      }
      while (_chatHistory.length > _maxChatTurns * 2) {
        _chatHistory.removeRange(0, 2);
      }
    } on AiException catch (e) {
      if (fullResponseBuffer.isEmpty) {
        logs.remove(agentMsg);
        _log(ChatMessage.error('AI request failed: $e'));
      }
    } catch (e) {
      if (fullResponseBuffer.isEmpty) {
        logs.remove(agentMsg);
        _log(ChatMessage.error('Chat error: $e'));
      }
    } finally {
      _chatBusy = false;
      notifyListeners();
      _broadcastOverlay();
    }
  }

  // ------------------------------------------------------------------
  // Main loop
  // ------------------------------------------------------------------

  /// Executes [goal]. When [telegramChatId] is set, completion (with a
  /// screenshot) is reported back through [onTaskFinished].
  Future<TaskStatus> executeTask(String goal, {String? telegramChatId}) async {
    if (isBusy) {
      _log(ChatMessage.error('Another task is already running.'));
      return TaskStatus.failed;
    }
    final settings = SettingsService.instance;

    state = ExecutorState.running;
    currentGoal = goal;
    step = 0;
    _cancelRequested = false;
    _usedSkillReplay = false;
    _executedSteps.clear();
    _runLogLines.clear();
    _recovery.reset();
    _startedAt = DateTime.now();
    logs.clear();
    _log(ChatMessage.user(goal));
    notifyListeners();
    _broadcastOverlay();

    TaskStatus status = TaskStatus.failed;
    try {
      // 1. Accessibility gate.
      if (!await _automation.isServiceEnabled()) {
        _log(
          ChatMessage.error(
            'Accessibility service is OFF. Enable "Geny Screen '
            'Control" in system settings, then retry.',
          ),
        );
        return status;
      }

      // 2. Skill memory fast path.
      if (settings.skillsEnabled) {
        final skill = await _skills.findMatch(goal);
        if (skill != null) {
          _usedSkillReplay = true;
          _log(
            ChatMessage.system(
              'Found memorized skill for this goal (${skill.steps.length} '
              'steps, used ${skill.successCount}x). Replaying…',
            ),
          );
          final ok = await _replaySkill(skill);
          if (ok) {
            status = TaskStatus.success;
            _log(ChatMessage.system('Skill replay completed successfully.'));
            await _skills.markReplayOutcome(skill.id, success: true);
            return status;
          }
          _log(
            ChatMessage.system(
              'Skill replay failed — falling back to AI planning.',
            ),
          );
          await _skills.markReplayOutcome(skill.id, success: false);
          _usedSkillReplay = false;
        }
      }

      // 3. AI loop.
      status = await _aiLoop(goal, settings);
      return status;
    } catch (e) {
      _log(ChatMessage.error('Execution error: $e'));
      status = TaskStatus.failed;
      return status;
    } finally {
      await _finalize(goal, status, telegramChatId);
    }
  }

  Future<TaskStatus> _aiLoop(String goal, SettingsService settings) async {
    final history = <Map<String, String>>[];
    var parseFailures = 0;

    while (step < settings.maxSteps) {
      if (_cancelRequested) {
        _log(ChatMessage.system('Task cancelled by user.'));
        return TaskStatus.cancelled;
      }
      while (state == ExecutorState.paused) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_cancelRequested) return TaskStatus.cancelled;
      }

      step++;
      notifyListeners();

      // --- Observe ---
      List<ScreenNode> nodes;
      try {
        nodes = await _automation.dumpScreen();
      } catch (e) {
        _log(ChatMessage.error('Failed to read screen: $e'));
        await Future.delayed(Duration(milliseconds: settings.stepDelayMs));
        continue;
      }
      if (nodes.isEmpty) {
        _log(ChatMessage.system('Screen appears empty (locked?). Waiting…'));
        await Future.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      final fullDump = _automation.formatNodes(nodes);
      _recovery.recordScreen(fullDump);
      final description = _automation.getCompressedScreenDescription(
        nodes,
        goal,
      );

      // --- Think ---
      String raw;
      try {
        raw = await _ai.complete(
          goal: goal,
          screenDescription: description,
          history: history,
        );
      } on AiException catch (e) {
        _log(ChatMessage.error('AI request failed: $e'));
        return TaskStatus.failed;
      }

      debugPrint('[TaskExecutor] Model raw output step $step: "$raw"');

      final decision = TaskStep.tryParse(raw);
      if (decision == null) {
        parseFailures++;
        final preview = raw.trim().length > 80 ? '${raw.trim().substring(0, 80)}…' : raw.trim();
        _log(
          ChatMessage.error(
            'Could not parse AI output as an action JSON (attempt $parseFailures): "$preview"',
          ),
        );
        if (parseFailures >= 3) {
          _log(ChatMessage.error('Giving up: AI kept replying non-JSON.'));
          return TaskStatus.failed;
        }
        _pushTurn(
          history,
          raw,
          'Your last reply was not valid JSON. Reply with ONLY the single JSON action object: '
          '{"action": "<action>", "params": {...}, "reasoning": "<explanation>", "is_complete": false}',
        );
        continue;
      }
      parseFailures = 0;

      // --- Act ---
      _log(
        ChatMessage.agent(
          decision.reasoning.isEmpty
              ? '**${decision.action}** ${_briefParams(decision)}'
              : '**${decision.action}** ${_briefParams(decision)}\n\n'
                    '${decision.reasoning}',
          step: step,
        ),
      );

      if (decision.action == TaskStep.actionDone || decision.isComplete) {
        _log(ChatMessage.system('Goal marked complete by the agent.'));
        await _learnSkillIfWorthIt(goal, settings);
        return TaskStatus.success;
      }

      final ok = await _performAction(decision, nodes);
      _executedSteps.add(decision);
      _recovery.recordAction(decision);
      _pushTurn(
        history,
        raw,
        'ACTION RESULT: ${ok ? 'success' : 'FAILED'} for '
        '${decision.action}. If the screen did not change, pick a '
        'different approach.',
      );

      // --- Recovery safeguard ---
      if (_recovery.shouldRecover) {
        final recovery = _recovery.suggestRecovery();
        _log(ChatMessage.system('Recovery: ${recovery.reasoning}'));
        await _performAction(recovery, nodes);
      }

      await Future.delayed(Duration(milliseconds: settings.stepDelayMs));
      _broadcastOverlay();
    }

    _log(
      ChatMessage.error(
        'Reached the maximum of ${settings.maxSteps} steps without '
        'completing the goal.',
      ),
    );
    return TaskStatus.failed;
  }
  // ------------------------------------------------------------------
  // Action dispatch
  // ------------------------------------------------------------------

  Future<bool> _performAction(TaskStep step, List<ScreenNode> nodes) async {
    try {
      switch (step.action) {
        case TaskStep.actionClickText:
          final text = step.stringParam('text') ?? '';
          return _automation.clickText(text, nodes: nodes);
        case TaskStep.actionClickAt:
          final x = step.intParam('x');
          final y = step.intParam('y');
          if (x == null || y == null) return false;
          return _automation.clickAt(x, y);
        case TaskStep.actionTypeText:
          final text = step.stringParam('text');
          if (text == null) return false;
          return _automation.typeText(text);
        case TaskStep.actionPressEnter:
          return _automation.pressEnter();
        case TaskStep.actionScroll:
          return _automation.scroll(step.stringParam('direction') ?? 'down');
        case TaskStep.actionSwipe:
          final sx = step.intParam('startX');
          final sy = step.intParam('startY');
          final ex = step.intParam('endX');
          final ey = step.intParam('endY');
          if ([sx, sy, ex, ey].any((v) => v == null)) return false;
          return _automation.swipe(
            startX: sx!,
            startY: sy!,
            endX: ex!,
            endY: ey!,
            durationMs: step.intParam('durationMs') ?? 350,
          );
        case TaskStep.actionPressBack:
          return _automation.pressBack();
        case TaskStep.actionPressHome:
          return _automation.pressHome();
        case TaskStep.actionOpenApp:
          final query =
              step.stringParam('app') ?? step.stringParam('package') ?? '';
          final launched = await _apps.launch(query);
          if (launched == null) {
            _log(ChatMessage.error('App not found: "$query"'));
            return false;
          }
          _log(ChatMessage.system('Launched $launched.'));
          return true;
        case TaskStep.actionWait:
          final ms = (step.intParam('ms') ?? 1500).clamp(100, 10000);
          await Future.delayed(Duration(milliseconds: ms));
          return true;
        default:
          return false;
      }
    } catch (e) {
      _log(ChatMessage.error('Action ${step.action} threw: $e'));
      return false;
    }
  }

  String _briefParams(TaskStep step) {
    if (step.params.isEmpty) return '';
    final entries = step.params.entries
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    return '`$entries`';
  }

  void _pushTurn(
    List<Map<String, String>> history,
    String assistant,
    String userNote,
  ) {
    history.add({'role': 'assistant', 'content': assistant});
    history.add({'role': 'user', 'content': userNote});
    while (history.length > _maxHistoryTurns * 2) {
      history.removeRange(0, 2);
    }
  }

  // ------------------------------------------------------------------
  // Skill replay
  // ------------------------------------------------------------------

  Future<bool> _replaySkill(Skill skill) async {
    for (final s in skill.steps) {
      if (_cancelRequested) return false;
      while (state == ExecutorState.paused) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_cancelRequested) return false;
      }
      step++;
      final nodes = await _automation.dumpScreen().catchError(
        (_) => <ScreenNode>[],
      );
      _log(
        ChatMessage.agent(
          '**${s.action}** ${_briefParams(s)}\n\n(replaying memorized step)',
          step: step,
        ),
      );
      final ok = await _performAction(s, nodes);
      if (!ok && s.action != TaskStep.actionWait) {
        _log(ChatMessage.error('Replayed step failed: ${s.action}'));
        return false;
      }
      notifyListeners();
      await Future.delayed(
        Duration(milliseconds: SettingsService.instance.stepDelayMs),
      );
    }
    return true;
  }

  Future<void> _learnSkillIfWorthIt(
    String goal,
    SettingsService settings,
  ) async {
    if (!settings.skillsEnabled || _usedSkillReplay) return;
    if (_executedSteps.isEmpty) return;
    await _skills.saveOrUpdate(goal, List.of(_executedSteps));
    _log(
      ChatMessage.system(
        'Memorized ${_executedSteps.length} steps for this goal.',
      ),
    );
  }

  // ------------------------------------------------------------------
  // Finalization
  // ------------------------------------------------------------------

  Future<void> _finalize(
    String goal,
    TaskStatus status,
    String? telegramChatId,
  ) async {
    final entry = TaskHistoryEntry(
      goal: goal,
      status: status,
      steps: step,
      startedAt: _startedAt ?? DateTime.now(),
      finishedAt: DateTime.now(),
      logs: List.of(_runLogLines),
    );
    historyEntries.insert(0, entry);
    if (historyEntries.length > _maxHistoryEntries) {
      historyEntries.removeRange(_maxHistoryEntries, historyEntries.length);
    }
    await _persistHistory();

    final summary = switch (status) {
      TaskStatus.success => 'Task completed in $step step(s).',
      TaskStatus.cancelled => 'Task cancelled after $step step(s).',
      TaskStatus.failed => 'Task failed after $step step(s).',
    };
    _log(ChatMessage.system(summary));

    if (SettingsService.instance.voiceFeedback) {
      await VoiceService.instance.speak(summary);
    }
    await SystemControlService.instance.notify(
      'Geny — ${status.name}',
      '$goal\n$summary',
    );

    if (telegramChatId != null) {
      onTaskFinished?.call(telegramChatId, entry);
    }

    state = ExecutorState.idle;
    currentGoal = null;
    _cancelRequested = false;
    notifyListeners();
    _broadcastOverlay();
  }
}
