import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'ai_service.dart';
import 'calendar_reminder_service.dart';
import 'commute_traffic_service.dart';
import 'conversational_memory_service.dart';
import 'geny_service.dart';
import 'geny_tools_service.dart';
import 'screen_automation_service.dart';
import 'settings_service.dart';
import 'todo_service.dart';

class ProactiveSuggestion {
  final String id;
  final String title;
  final String description;
  final String actionGoal;
  final String spokenPrompt;
  final String actionLabel;
  final DateTime timestamp;

  const ProactiveSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.actionGoal,
    required this.spokenPrompt,
    this.actionLabel = 'Execute',
    required this.timestamp,
  });
}

/// Advanced Geny-level intelligence:
/// - Proactive autonomous suggestions & scheduled voice prompts.
/// - Anticipates user needs based on temporal, calendar & battery context.
/// - Hands-free conversational confirmation daemon.
/// - Continuous preference learning.
/// - Multi-step agentic task planning.
/// - Vision: Screen & UI visual understanding.
class ProactiveAgentService extends ChangeNotifier {
  ProactiveAgentService._();
  static final ProactiveAgentService instance = ProactiveAgentService._();

  ProactiveSuggestion? _currentSuggestion;
  ProactiveSuggestion? get currentSuggestion => _currentSuggestion;

  Timer? _monitorTimer;
  DateTime? _lastProactiveSpokenTime;
  final Set<String> _spokenDeduplicationIds = {};

  bool get isMonitoring => _monitorTimer != null;

  /// Starts the autonomous periodic monitor daemon (runs every 45 seconds).
  void startProactiveMonitor({Duration interval = const Duration(seconds: 45)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) {
      unawaited(checkAndTriggerProactiveAlert());
    });
  }

  /// Stops the periodic monitor daemon.
  void stopProactiveMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Clears deduplication cache (useful for testing or day transitions).
  void clearDeduplicationHistory() {
    _spokenDeduplicationIds.clear();
    _lastProactiveSpokenTime = null;
  }

  /// Evaluates context to generate an intelligent proactive recommendation.
  /// Optional [nowOverride] allows deterministic unit testing across any hour of the day.
  Future<ProactiveSuggestion?> evaluateProactiveNeeds({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();

    // 1. Proactive Meeting Commute Departure Warning (High urgency)
    if (SettingsService.instance.proactiveCommuteEnabled) {
      try {
        final commute = await CommuteTrafficService.instance.checkUpcomingMeetingCommute();
        if (commute != null && commute.isUrgent) {
          final dedupId = 'commute_${commute.destination}';
          _currentSuggestion = ProactiveSuggestion(
            id: dedupId,
            title: 'Departure Alert: ${commute.destination}',
            description: commute.spokenSummary,
            actionGoal: 'Check traffic',
            spokenPrompt: commute.spokenSummary,
            actionLabel: 'View Route',
            timestamp: now,
          );
          notifyListeners();
          return _currentSuggestion;
        }
      } catch (_) {}
    }

    // 2. Upcoming Meeting / Calendar Alert (15 - 30 minutes prior)
    if (SettingsService.instance.proactiveMeetingReminders) {
      try {
        final calendarItems = CalendarReminderService.instance.items;
        final upcomingMeetings = calendarItems.where((item) {
          if (item.isCompleted) return false;
          final diff = item.dateTime.difference(now).inMinutes;
          return diff >= 0 && diff <= 30;
        }).toList();

        if (upcomingMeetings.isNotEmpty) {
          final meeting = upcomingMeetings.first;
          final timeStr = DateFormat('h:mm a').format(meeting.dateTime);
          final hasLoc = meeting.location != null && meeting.location!.trim().isNotEmpty;
          final spoken = hasLoc
              ? "Pardon the interruption. You have an upcoming event, '${meeting.title}', at $timeStr located at ${meeting.location}. Would you like me to check traffic and route navigation?"
              : "Pardon the interruption. You have an upcoming event, '${meeting.title}', scheduled for $timeStr. Would you like me to prepare your briefing?";

          final dedupId = 'meeting_${meeting.id}';
          _currentSuggestion = ProactiveSuggestion(
            id: dedupId,
            title: 'Upcoming Meeting: ${meeting.title}',
            description: 'Scheduled for $timeStr${hasLoc ? ' (${meeting.location})' : ''}.',
            actionGoal: hasLoc ? 'Check traffic' : 'Show calendar',
            spokenPrompt: spoken,
            actionLabel: 'Review',
            timestamp: now,
          );
          notifyListeners();
          return _currentSuggestion;
        }
      } catch (_) {}
    }

    // 3. Critical Battery check (< 20%)
    if (SettingsService.instance.proactiveBatteryAlert) {
      try {
        final battery = await GenyToolsService.instance.getBatteryStatus();
        final level = battery['level'] as int;
        final isCharging = battery['isCharging'] as bool;
        if (level > 0 && level <= 20 && !isCharging) {
          final dedupId = 'battery_${now.year}_${now.month}_${now.day}_${level <= 10 ? '10' : '20'}';
          _currentSuggestion = ProactiveSuggestion(
            id: dedupId,
            title: 'Power Telemetry Critical ($level%)',
            description: 'Power reserves are low. Would you like to enable Battery Saver?',
            actionGoal: 'Turn on battery saver',
            spokenPrompt: 'power reserves have reached $level percent. Should I activate Battery Saver protocol to preserve power?',
            actionLabel: 'Battery Saver',
            timestamp: now,
          );
          notifyListeners();
          return _currentSuggestion;
        }
      } catch (_) {}
    }

    // 4. Night Mode / Sleep Protocol check (Between 9 PM and 3 AM)
    if (SettingsService.instance.proactiveNightModePrompt) {
      if (now.hour >= 21 || now.hour < 3) {
        final dedupId = 'night_prompt_${now.year}_${now.month}_${now.day}';
        _currentSuggestion = ProactiveSuggestion(
          id: dedupId,
          title: 'Night Mode Available',
          description: "It's late evening. Shall I engage Night Protocol and prepare your environment for sleep?",
          actionGoal: 'turn on night mode',
          spokenPrompt: "It's night time. Should I turn on the night mode?",
          actionLabel: 'Turn On',
          timestamp: now,
        );
        notifyListeners();
        return _currentSuggestion;
      }
    }

    // 5. Study & Focus Protocol check (Afternoon focus block: 2 PM - 4:59 PM)
    if (SettingsService.instance.proactiveStudyPrompt) {
      if (now.hour >= 14 && now.hour <= 16) {
        final dedupId = 'study_prompt_${now.year}_${now.month}_${now.day}';
        _currentSuggestion = ProactiveSuggestion(
          id: dedupId,
          title: 'Study Protocol Session',
          description: 'Time for your afternoon focus session. Ready to silence distractions and adjust luminosity.',
          actionGoal: 'study mode',
          spokenPrompt: 'it is time for your afternoon study and focus session. Shall I engage Study Protocol and silence distractions?',
          actionLabel: 'Engage',
          timestamp: now,
        );
        notifyListeners();
        return _currentSuggestion;
      }
    }

    // 6. Pending high-priority / remaining tasks check (Evening review: 5 PM - 8:59 PM)
    if (SettingsService.instance.proactiveTaskReminderPrompt) {
      if (now.hour >= 17 && now.hour <= 20) {
        final pendingTodos = TodoService.instance.pendingItems;
        if (pendingTodos.isNotEmpty) {
          final top = pendingTodos.where((t) => t.priority == TodoPriority.high).firstOrNull ?? pendingTodos.first;
          final count = pendingTodos.length;
          final taskWord = count == 1 ? 'task' : 'tasks';
          final dedupId = 'todo_prompt_${now.year}_${now.month}_${now.day}';
          _currentSuggestion = ProactiveSuggestion(
            id: dedupId,
            title: '$count $taskWord Pending on Agenda',
            description: 'Reminder: "${top.title}" requires your attention.',
            actionGoal: 'Show my tasks',
            spokenPrompt: "you have $count $taskWord remaining on your agenda today, including '${top.title}'. Shall I read your pending to-do list?",
            actionLabel: 'Review Tasks',
            timestamp: now,
          );
          notifyListeners();
          return _currentSuggestion;
        }
      }
    }

    // 7. Morning Routine check (Between 7 AM and 9:59 AM)
    if (SettingsService.instance.proactiveMorningBriefingPrompt) {
      if (now.hour >= 7 && now.hour <= 9) {
        final dedupId = 'morning_prompt_${now.year}_${now.month}_${now.day}';
        _currentSuggestion = ProactiveSuggestion(
          id: dedupId,
          title: 'Morning Briefing Available',
          description: 'Ready to deliver weather, schedule, and today’s top headlines.',
          actionGoal: 'Good morning',
          spokenPrompt: "Good morning. Would you like your morning briefing with today's weather, schedule, and headlines?",
          actionLabel: 'Briefing',
          timestamp: now,
        );
        notifyListeners();
        return _currentSuggestion;
      }
    }

    _currentSuggestion = null;
    notifyListeners();
    return null;
  }

  /// Evaluates triggers and autonomously vocalizes proactive prompts when appropriate.
  Future<void> checkAndTriggerProactiveAlert({bool forceSpeak = false}) async {
    final suggestion = await evaluateProactiveNeeds();
    if (suggestion == null) return;

    // Check master auto-speak preference
    if (!SettingsService.instance.genyAutoSpeakEnabled && !forceSpeak) {
      return;
    }

    // Deduplication check: avoid repeating the same prompt in the same cycle
    if (_spokenDeduplicationIds.contains(suggestion.id) && !forceSpeak) {
      return;
    }

    // Minimum cooldown check: at least 15 minutes between auto-spoken prompts
    if (!forceSpeak && _lastProactiveSpokenTime != null) {
      final elapsed = DateTime.now().difference(_lastProactiveSpokenTime!).inMinutes;
      if (elapsed < 15) {
        return;
      }
    }

    // Geny state check: only speak if system is idle (never interrupt user speech or tasks)
    if (GenyService.instance.phase != GenyPhase.idle && !forceSpeak) {
      return;
    }

    _spokenDeduplicationIds.add(suggestion.id);
    _lastProactiveSpokenTime = DateTime.now();

    // Trigger proactive speech and hands-free conversational confirmation window
    await GenyService.instance.proactivelySpeakAndAwaitConfirmation(suggestion);
  }

  /// Triggers a test proactive prompt for user verification from settings or testing.
  Future<void> testProactivePrompt(String type) async {
    final now = DateTime.now();
    ProactiveSuggestion suggestion;
    switch (type.toLowerCase()) {
      case 'night':
        suggestion = ProactiveSuggestion(
          id: 'test_night_${now.millisecondsSinceEpoch}',
          title: 'Night Mode Prompt (Test)',
          description: "It's late evening. Shall I engage Night Protocol and prepare for sleep?",
          actionGoal: 'turn on night mode',
          spokenPrompt: "It's night time. Should I turn on the night mode?",
          actionLabel: 'Turn On',
          timestamp: now,
        );
        break;
      case 'study':
        suggestion = ProactiveSuggestion(
          id: 'test_study_${now.millisecondsSinceEpoch}',
          title: 'Study Protocol Session (Test)',
          description: 'Ready to silence distractions and adjust luminosity.',
          actionGoal: 'study mode',
          spokenPrompt: 'it is time for your afternoon study and focus session. Shall I engage Study Protocol and silence distractions?',
          actionLabel: 'Engage',
          timestamp: now,
        );
        break;
      case 'meeting':
        suggestion = ProactiveSuggestion(
          id: 'test_meeting_${now.millisecondsSinceEpoch}',
          title: 'Upcoming Meeting: Product Review (Test)',
          description: 'Scheduled for 10:30 AM in Conference Room B.',
          actionGoal: 'show calendar',
          spokenPrompt: "Pardon the interruption. You have an upcoming meeting, 'Product Review', scheduled for 10:30 AM. Would you like me to prepare your briefing?",
          actionLabel: 'Review',
          timestamp: now,
        );
        break;
      case 'todo':
      case 'tasks':
        suggestion = ProactiveSuggestion(
          id: 'test_todo_${now.millisecondsSinceEpoch}',
          title: '3 Remaining Tasks on Agenda (Test)',
          description: 'Pending: "Finalize client proposal" and 2 others.',
          actionGoal: 'show my tasks',
          spokenPrompt: "you have 3 tasks remaining on your agenda today, including 'Finalize client proposal'. Shall I read your pending to-do list?",
          actionLabel: 'View Tasks',
          timestamp: now,
        );
        break;
      case 'morning':
        suggestion = ProactiveSuggestion(
          id: 'test_morning_${now.millisecondsSinceEpoch}',
          title: 'Morning Briefing (Test)',
          description: 'Weather, schedule and top news headlines ready.',
          actionGoal: 'good morning',
          spokenPrompt: "Good morning. Would you like your morning briefing with today's weather, schedule, and headlines?",
          actionLabel: 'Briefing',
          timestamp: now,
        );
        break;
      case 'battery':
      default:
        suggestion = ProactiveSuggestion(
          id: 'test_battery_${now.millisecondsSinceEpoch}',
          title: 'Power Telemetry Critical (18%) (Test)',
          description: 'Power reserves are low. Would you like to enable Battery Saver?',
          actionGoal: 'turn on battery saver',
          spokenPrompt: 'power reserves have reached 18 percent. Should I activate Battery Saver protocol to preserve power?',
          actionLabel: 'Battery Saver',
          timestamp: now,
        );
        break;
    }

    _currentSuggestion = suggestion;
    notifyListeners();
    await GenyService.instance.proactivelySpeakAndAwaitConfirmation(suggestion);
  }

  void dismissSuggestion() {
    _currentSuggestion = null;
    if (GenyService.instance.isAwaitingProactiveConfirmation) {
      GenyService.instance.dismissProactiveConfirmation();
    }
    notifyListeners();
  }

  /// Multi-step agentic decomposition: breaks down complex goals into actionable sub-steps.
  Future<List<String>> planMultiStepGoal(String highLevelGoal) async {
    final prompt = '''
You are an autonomous Chief of Staff AI.
Break down this high-level user goal into 3 to 5 clear, sequential, actionable steps:
"$highLevelGoal"

Output ONLY a JSON array of strings:
["Step 1: ...", "Step 2: ...", "Step 3: ..."]
''';

    try {
      final raw = await AiService.instance.chat(message: prompt);
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start != -1 && end != -1) {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return [
      '1. Research relevant requirements for: $highLevelGoal',
      '2. Outline detailed itinerary and action items',
      '3. Schedule calendar reminders for execution',
    ];
  }

  /// Vision: Analyzes current screen UI hierarchy and captures screenshot to explain what is visible.
  Future<String> analyzeCurrentScreen({String? userQuestion}) async {
    final automation = ScreenAutomationService.instance;
    final isOnline = await automation.isServiceEnabled();
    if (!isOnline) {
      return 'Screen automation accessibility service is currently disabled. Please enable it in Settings so I can observe your screen.';
    }

    final dump = await automation.dumpScreen();
    if (dump.isEmpty) {
      return 'The active screen appears to be blank or inaccessible at this moment.';
    }

    final query = userQuestion?.trim().isNotEmpty == true
        ? userQuestion!
        : 'Describe the current screen and what action options are visible.';

    final prompt = '''
You are Geny. You are inspecting the user's active Android smartphone screen.
Current screen UI hierarchy dump:
$dump

User Question: "$query"

Explain clearly and concisely in natural spoken English (2 to 3 sentences) what is on the screen and what the user can do next. Always address the user by name when known, otherwise neutrally.
''';

    try {
      final reply = await AiService.instance.chat(message: prompt);
      return reply.trim();
    } catch (_) {
      return 'I can see the active screen elements. Let me know what specific action you would like me to take on it.';
    }
  }

  /// Continuous learning: learns user preferences from actions taken.
  Future<void> recordObservedPreference(String preferenceKey, String value) async {
    final fact = 'User preference: $preferenceKey is "$value"';
    await ConversationalMemoryService.instance.addFact(fact, category: 'preference');
  }
}
