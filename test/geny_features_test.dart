import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:private_agent/models/task_step.dart';
import 'package:private_agent/services/ai_service.dart';
import 'package:private_agent/services/app_usage_service.dart';
import 'package:private_agent/services/calendar_reminder_service.dart';
import 'package:private_agent/services/commute_traffic_service.dart';
import 'package:private_agent/services/conversational_memory_service.dart';
import 'package:private_agent/services/email_triage_service.dart';
import 'package:private_agent/services/finance_tracking_service.dart';
import 'package:private_agent/services/form_filling_service.dart';
import 'package:private_agent/services/hermes_evolution_service.dart';
import 'package:private_agent/services/inbox_service.dart';
import 'package:private_agent/services/geny_service.dart';
import 'package:private_agent/services/macro_recorder_service.dart';
import 'package:private_agent/services/message_drafting_service.dart';
import 'package:private_agent/services/notes_knowledge_service.dart';
import 'package:private_agent/services/permission_manager_service.dart';
import 'package:private_agent/services/air_gesture_service.dart';
import 'package:private_agent/services/airspace_radar_service.dart';
import 'package:private_agent/services/charging_telemetry_service.dart';
import 'package:private_agent/services/code_black_service.dart';
import 'package:private_agent/services/floating_copilot_service.dart';
import 'package:private_agent/services/multi_task_service.dart';
import 'package:private_agent/services/network_audit_service.dart';
import 'package:private_agent/services/optical_solver_service.dart';
import 'package:private_agent/services/personality_service.dart';
import 'package:private_agent/services/phone_storage_service.dart';
import 'package:private_agent/services/polyglot_diplomat_service.dart';
import 'package:private_agent/services/proactive_agent_service.dart';
import 'package:private_agent/services/routine_automation_service.dart';
import 'package:private_agent/services/security_alert_service.dart';
import 'package:private_agent/services/sentry_service.dart';
import 'package:private_agent/services/settings_service.dart';
import 'package:private_agent/services/smart_home_service.dart';
import 'package:private_agent/services/sound_radar_service.dart';
import 'package:private_agent/services/sports_service.dart';
import 'package:private_agent/services/system_diagnostics_service.dart';
import 'package:private_agent/services/todo_service.dart';
import 'package:private_agent/services/vision_perception_service.dart';
import 'package:private_agent/services/workflow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Feature 1: Conversational Memory & Learning', () {
    test('Stores, retrieves, and wipes cross-session facts and dialogue history', () async {
      final memory = ConversationalMemoryService.instance;
      await memory.wipeAll();

      final fact = await memory.addFact('User prefers dark mode and British English voice', category: 'preference');
      expect(fact.fact, contains('dark mode'));
      expect(memory.facts.length, 1);

      // Record dialogue turn
      await memory.recordTurn('Remember that my favorite club is Real Madrid', 'Understood. Recorded in your knowledge base.');
      expect(memory.persistedHistory.length, 2);
      expect(memory.facts.any((f) => f.fact.contains('Real Madrid')), isTrue);

      final promptContext = memory.buildMemoryContext();
      expect(promptContext, contains('USER MEMORY & PREFERENCES'));
      expect(promptContext, contains('dark mode'));

      // Delete fact
      await memory.deleteFact(fact.id);
      expect(memory.facts.any((f) => f.id == fact.id), isFalse);

      // Wipe all
      await memory.wipeAll();
      expect(memory.facts.isEmpty, isTrue);
      expect(memory.persistedHistory.isEmpty, isTrue);
    });
  });

  group('Feature 2: Personality & Emotional Awareness', () {
    test('Adapts persona instructions, detects urgency and emotion', () async {
      final personality = PersonalityService.instance;
      await personality.init();

      await personality.setArchetype(PersonalityArchetype.geny);
      await personality.setFormality(FormalityLevel.formal);
      await personality.setHumor(HumorLevel.subtle);

      final genyPrompt = personality.buildPersonaPrompt('Please help me quickly');
      expect(genyPrompt, contains('ARCHETYPE: You are Geny'));
      expect(genyPrompt, contains('FORMALITY'));

      // Emotional state detection
      final urgentEmotion = personality.detectEmotion('Please hurry, this is an emergency ASAP!');
      expect(urgentEmotion, DetectedEmotion.urgent);

      final frustratedEmotion = personality.detectEmotion('This is so annoying and broken, I hate it');
      expect(frustratedEmotion, DetectedEmotion.frustrated);

      final tiredEmotion = personality.detectEmotion('I am feeling so exhausted and tired today');
      expect(tiredEmotion, DetectedEmotion.tired);

      final happyEmotion = personality.detectEmotion('This is wonderful, great job!');
      expect(happyEmotion, DetectedEmotion.happy);
    });
  });

  group('Feature 3: Calendar & Reminders', () {
    test('Schedules items, provides daily briefing, and deletes events', () async {
      final calendar = CalendarReminderService.instance;
      await calendar.init();

      final now = DateTime.now();
      final item = await calendar.addItem(
        title: 'Team Architecture Sync',
        dateTime: DateTime(now.year, now.month, now.day, now.hour, now.minute),
        isReminder: false,
        description: 'Discuss Geny neural integration',
      );

      expect(calendar.items.any((i) => i.id == item.id), isTrue);

      final briefing = calendar.getTodayBriefingSpoken();
      expect(briefing, contains('Team Architecture Sync'));

      await calendar.deleteItem(item.id);
      expect(calendar.items.any((i) => i.id == item.id), isFalse);
    });
  });

  group('Feature 4: Email Triage', () {
    test('Triages email into structured priority and suggested replies', () async {
      final triage = EmailTriageService.instance;

      final urgentResult = await triage.triageEmail('Urgent: server cluster outage, immediate attention required.');
      expect(urgentResult.priority, EmailPriority.urgent);
      expect(urgentResult.suggestedReplies.isNotEmpty, isTrue);
    });
  });

  group('Feature 5: To-Do List & Task Tracking', () {
    test('Manages tasks with priority, completion state, and spoken summary', () async {
      final todo = TodoService.instance;
      await todo.init();

      final task = await todo.addTask(
        'Submit quarterly expense report',
        priority: TodoPriority.high,
      );

      expect(todo.items.any((t) => t.id == task.id), isTrue);
      expect(todo.pendingItems.any((t) => t.id == task.id), isTrue);

      final spoken = todo.getPendingTasksSpoken();
      expect(spoken, contains('quarterly expense report'));

      // Toggle done
      await todo.toggleDone(task.id);
      expect(todo.pendingItems.any((t) => t.id == task.id), isFalse);
      expect(todo.completedItems.any((t) => t.id == task.id), isTrue);

      // Delete task
      await todo.deleteTask(task.id);
      expect(todo.items.any((t) => t.id == task.id), isFalse);
    });
  });

  group('Feature 6: Notes & Knowledge Base', () {
    test('Stores notes, supports keyword search, and deletes notes', () async {
      final notes = NotesKnowledgeService.instance;
      await notes.init();

      final note = await notes.addNote(
        title: 'Quantum Core Specs',
        content: 'Arc-Reactor frequency calibrated to 14.2 GHz with neodymium coils.',
        tags: ['hardware', 'stark'],
      );

      expect(notes.notes.any((n) => n.id == note.id), isTrue);

      final searchResults = notes.searchNotes('neodymium');
      expect(searchResults.length, 1);
      expect(searchResults.first.title, 'Quantum Core Specs');

      final searchMiss = notes.searchNotes('cryptocurrency');
      expect(searchMiss.isEmpty, isTrue);

      await notes.deleteNote(note.id);
      expect(notes.notes.any((n) => n.id == note.id), isFalse);
    });
  });

  group('Feature 7: Routine Automation', () {
    test('Generates morning briefing and evening routines', () async {
      final routines = RoutineAutomationService.instance;
      final morning = await routines.executeMorningRoutine();
      expect(morning, contains('Good morning'));

      final evening = await routines.executeEveningRoutine();
      expect(evening, contains('Night Protocol'));
    });
  });

  group('Feature 8: Security Monitoring & Risk Assessment', () {
    test('Assesses low, medium, and high risk actions correctly', () {
      final security = SecurityAlertService.instance;

      final lowRisk = security.evaluateActionRisk('Check the weather in London');
      expect(lowRisk.riskLevel, RiskLevel.low);
      expect(lowRisk.requiresConfirmation, isFalse);

      final mediumRisk = security.evaluateActionRisk('Turn off Bluetooth');
      expect(mediumRisk.riskLevel, RiskLevel.medium);

      final highRisk = security.evaluateActionRisk('Transfer money and delete all personal messages');
      expect(highRisk.riskLevel, RiskLevel.high);
      expect(highRisk.requiresConfirmation, isTrue);
    });
  });

  group('Feature 9 & 10: Finance Tracking & Sports Service', () {
    test('Constructs crypto queries and sports updates', () async {
      final finance = FinanceTrackingService.instance;
      expect(finance, isNotNull);

      final sports = SportsService.instance;
      expect(sports, isNotNull);
    });
  });

  group('Feature 13: Message Drafting & Dispatch', () {
    test('Generates WhatsApp and SMS draft models', () {
      final draft = const MessageDraft(
        channel: MessageChannel.whatsapp,
        recipient: '+1234567890',
        body: 'Meeting moved to 3 PM',
      );

      expect(draft.channel, MessageChannel.whatsapp);
      expect(draft.recipient, '+1234567890');
      expect(draft.body, 'Meeting moved to 3 PM');

      final smsDraft = const MessageDraft(
        channel: MessageChannel.sms,
        recipient: '+1987654321',
        body: 'I have arrived safely',
      );
      expect(smsDraft.channel, MessageChannel.sms);
    });
  });

  group('Advanced Intelligence: Proactive Needs Evaluation & Autonomous Voice', () {
    test('Evaluates temporal and contextual needs', () async {
      final proactive = ProactiveAgentService.instance;
      final suggestion = await proactive.evaluateProactiveNeeds();
      // Hour dependent, but will always produce a valid ProactiveSuggestion or null
      if (suggestion != null) {
        expect(suggestion.title.isNotEmpty, isTrue);
        expect(suggestion.actionGoal.isNotEmpty, isTrue);
        expect(suggestion.spokenPrompt.isNotEmpty, isTrue);
        proactive.dismissSuggestion();
        expect(proactive.currentSuggestion, isNull);
      }
    });

    test('Night Mode Auto-Speak trigger at 10:00 PM (22:00)', () async {
      final proactive = ProactiveAgentService.instance;
      proactive.clearDeduplicationHistory();

      final nightTime = DateTime(2026, 11, 2, 22, 0); // 10:00 PM
      final suggestion = await proactive.evaluateProactiveNeeds(nowOverride: nightTime);

      expect(suggestion, isNotNull);
      expect(suggestion!.id, contains('night_prompt'));
      expect(suggestion.spokenPrompt, "It's night time. Should I turn on the night mode?");
      expect(suggestion.actionGoal, 'turn on night mode');
    });

    test('Study & Focus Protocol trigger at 3:00 PM (15:00)', () async {
      final proactive = ProactiveAgentService.instance;
      proactive.clearDeduplicationHistory();

      final studyTime = DateTime(2026, 11, 2, 15, 0); // 3:00 PM
      final suggestion = await proactive.evaluateProactiveNeeds(nowOverride: studyTime);

      expect(suggestion, isNotNull);
      expect(suggestion!.id, contains('study_prompt'));
      expect(suggestion.spokenPrompt, contains('study and focus session'));
      expect(suggestion.actionGoal, 'study mode');
    });

    test('Upcoming Meeting reminder within 30 minutes', () async {
      final calendar = CalendarReminderService.instance;
      await calendar.init();

      final now = DateTime(2026, 11, 2, 11, 0);
      final meetingTime = DateTime(2026, 11, 2, 11, 20); // 20 minutes from now

      final item = await calendar.addItem(
        title: 'Quarterly Executive Review',
        dateTime: meetingTime,
        description: 'Boardroom Presentation',
      );

      final proactive = ProactiveAgentService.instance;
      proactive.clearDeduplicationHistory();

      final suggestion = await proactive.evaluateProactiveNeeds(nowOverride: now);
      expect(suggestion, isNotNull);
      expect(suggestion!.id, 'meeting_${item.id}');
      expect(suggestion.spokenPrompt, contains('Quarterly Executive Review'));
      expect(suggestion.title, contains('Quarterly Executive Review'));
    });

    test('Pending Tasks Review in early evening at 6:00 PM (18:00)', () async {
      final todos = TodoService.instance;
      await todos.init();
      await todos.addTask('Finalize Quarterly Budget Report', priority: TodoPriority.high);

      final proactive = ProactiveAgentService.instance;
      proactive.clearDeduplicationHistory();

      final eveningTime = DateTime(2026, 11, 2, 18, 0); // 6:00 PM
      final suggestion = await proactive.evaluateProactiveNeeds(nowOverride: eveningTime);

      expect(suggestion, isNotNull);
      expect(suggestion!.id, contains('todo_prompt'));
      expect(suggestion.spokenPrompt, contains('remaining on your agenda today'));
      expect(suggestion.actionGoal, 'Show my tasks');
    });

    test('Hands-Free Voice Confirmation: Affirmative response classification', () {
      expect(GenyService.isAffirmativeResponse('yes'), isTrue);
      expect(GenyService.isAffirmativeResponse('yeah please'), isTrue);
      expect(GenyService.isAffirmativeResponse('sure'), isTrue);
      expect(GenyService.isAffirmativeResponse('turn it on'), isTrue);
      expect(GenyService.isAffirmativeResponse('do it'), isTrue);
      expect(GenyService.isAffirmativeResponse('engage'), isTrue);
      expect(GenyService.isAffirmativeResponse('activate'), isTrue);
      expect(GenyService.isAffirmativeResponse('ok go ahead'), isTrue);
      expect(GenyService.isAffirmativeResponse('sounds good'), isTrue);
    });

    test('Hands-Free Voice Confirmation: Negative response classification', () {
      expect(GenyService.isNegativeResponse('no'), isTrue);
      expect(GenyService.isNegativeResponse('nope'), isTrue);
      expect(GenyService.isNegativeResponse('not now'), isTrue);
      expect(GenyService.isNegativeResponse('cancel'), isTrue);
      expect(GenyService.isNegativeResponse('never mind'), isTrue);
      expect(GenyService.isNegativeResponse('later'), isTrue);
      expect(GenyService.isNegativeResponse('dismiss'), isTrue);
      expect(GenyService.isNegativeResponse('leave it'), isTrue);
    });
  });

  group('Desk Mode: Wake Word Gating & Ambient Chatter Rejection', () {
    test('Rejects ambient conversations between friends sitting near desk', () {
      expect(GenyService.extractWakeCommand('Hey man did you see the match yesterday'), isNull);
      expect(GenyService.extractWakeCommand('Bro what are we having for lunch'), isNull);
      expect(GenyService.extractWakeCommand('I searched that on google earlier'), isNull);
      expect(GenyService.extractWakeCommand('Pass me that jar, visitor is here'), isNull);
      expect(GenyService.extractWakeCommand('What are today to new headlines'), isNull);
    });

    test('Accurately detects Geny wake phrases and extracts user commands', () {
      // User says: "Hey Geny what are today to new headlines"
      expect(
        GenyService.extractWakeCommand('Hey Geny, what are today to new headlines'),
        'what are today to new headlines',
      );
      expect(
        GenyService.extractWakeCommand('geny what are today to new headlines'),
        'what are today to new headlines',
      );
      expect(
        GenyService.extractWakeCommand('Hello Geny what are today to new headlines?'),
        'what are today to new headlines',
      );
      expect(
        GenyService.extractWakeCommand('what are today to new headlines, Geny?'),
        'what are today to new headlines',
      );
    });

    test('Recognizes stand-alone wake greetings', () {
      expect(GenyService.extractWakeCommand('Hey Geny'), '');
      expect(GenyService.extractWakeCommand('Hey, Geny'), '');
      expect(GenyService.extractWakeCommand('Geny!'), '');
      expect(GenyService.extractWakeCommand('Hello Geny'), '');
      expect(GenyService.extractWakeCommand('Hello, Geny!'), '');
      expect(GenyService.extractWakeCommand('Ok Geny'), '');
      expect(GenyService.extractWakeCommand('Hi Geny'), '');
      expect(GenyService.extractWakeCommand('Hey Javis'), '');
      expect(GenyService.extractWakeCommand('Wake up Geny'), '');
      expect(GenyService.extractWakeCommand('Geny wake up'), '');
      expect(GenyService.extractWakeCommand('Hey service'), '');
      expect(GenyService.extractWakeCommand('Hey Travis'), '');
      expect(GenyService.extractWakeCommand('Hey Davis'), '');
      expect(GenyService.extractWakeCommand('Hey Davies'), '');
    });
  });

  group('Hermes Agent Self-Evolution (SOUL.md, USER.md, AGENT.md)', () {
    test('Initializes, evolves, updates, and resets tri-partite markdown context', () async {
      final hermes = HermesEvolutionService.instance;
      await hermes.resetAll();

      expect(hermes.soulMd, contains('SOUL.md'));
      expect(hermes.soulMd, contains('Geny'));
      expect(hermes.userMd, contains('USER.md'));
      expect(hermes.userMd, contains('Operator Profile'));
      expect(hermes.agentMd, contains('AGENT.md'));
      expect(hermes.agentMd, contains('Active Hardware Protocols'));

      // Evolve with simulated memory facts
      final memory = ConversationalMemoryService.instance;
      await memory.addFact('Favorite language is Rust', category: 'preference');
      await memory.addFact('Prefers morning meetings before 11 AM', category: 'habit');

      await hermes.evolveContext();

      expect(hermes.lastEvolvedAt, isNotNull);
      expect(hermes.userMd, contains('Favorite language is Rust'));
      expect(hermes.userMd, contains('Prefers morning meetings before 11 AM'));
      expect(hermes.agentMd, contains('Study Protocol'));
      expect(hermes.agentMd, contains('Sleep Protocol'));
      expect(hermes.evolutionLog.isNotEmpty, isTrue);

      // Verify system context injection
      final contextStr = hermes.buildHermesSystemContext();
      expect(contextStr, contains('[HERMES CONTEXT: SLOT 1 - SOUL.md]'));
      expect(contextStr, contains('[HERMES CONTEXT: SLOT 2 - USER.md]'));
      expect(contextStr, contains('[HERMES CONTEXT: SLOT 3 - AGENT.md]'));

      // Test custom update
      await hermes.updateSoul('# CUSTOM SOUL\nDirect and ruthless efficiency.');
      expect(hermes.soulMd, contains('CUSTOM SOUL'));

      // Test reset soul
      await hermes.resetSoul();
      expect(hermes.soulMd, contains('Geny Core Identity'));

      // Clean up
      await hermes.resetAll();
      await memory.wipeAll();
    });
  });

  group('Inbox Reading & Permission Manager', () {
    test('Parses and formats SMS and Email inbox models', () async {
      final sms = SmsMessage.fromMap({
        'id': '101',
        'sender': '+1234567890',
        'body': 'Your one-time login code is 492819',
        'date': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      expect(sms.id, '101');
      expect(sms.sender, '+1234567890');
      expect(sms.body, contains('492819'));
      expect(sms.isRead, isFalse);

      final email = EmailMessage.fromMap({
        'id': '201',
        'package': 'com.google.android.gm',
        'title': 'Google Security Alert',
        'text': 'New sign-in from Chrome on Mac OS',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      expect(email.id, '201');
      expect(email.package, 'com.google.android.gm');
      expect(email.senderOrTitle, contains('Security Alert'));
    });

    test('Permission Manager Service initializes required categories', () {
      final manager = PermissionManagerService.instance;
      expect(manager.permissions, isNotNull);
      expect(AppPermissionType.values.length, 8);
    });
  });

  group('New Advanced Capabilities: Vision, Macro Recorder, Smart Home, Commute', () {
    test('Geny Eye Optical Perception synthesizes visual feedback', () async {
      final vision = VisionPerceptionService.instance;
      final mockResult = VisionAnalysisResult(
        description: 'Optical analysis: Printed circuit board with dual LM358 operational amplifiers.',
        spokenSummary: 'I observe a printed circuit board with dual LM358 operational amplifiers.',
        timestamp: DateTime.now(),
      );
      vision.setAnalysisResult(mockResult);

      expect(vision.lastResult, isNotNull);
      expect(vision.lastResult!.spokenSummary, contains('LM358'));
      expect(vision.lastResult!.isSuccess, isTrue);

      // Test fallback on simulated error
      final fallback = VisionAnalysisResult.failure('Optical sensor disconnected');
      vision.setAnalysisResult(fallback);
      expect(vision.lastResult!.isSuccess, isFalse);
    });

    test('Autonomous Macro Recorder distills events and codifies into AGENT.md', () async {
      final recorder = MacroRecorderService.instance;
      final hermes = HermesEvolutionService.instance;
      await hermes.resetAll();

      final mockEvents = <Map<String, dynamic>>[
        {'type': 'click', 'package': 'com.spotify.music', 'label': 'Search', 'x': 200, 'y': 800},
        {'type': 'type', 'package': 'com.spotify.music', 'text': 'Workout Hits'},
        {'type': 'click', 'package': 'com.spotify.music', 'label': 'Play', 'x': 300, 'y': 950},
        {'type': 'scroll', 'package': 'com.spotify.music', 'direction': 'down'},
      ];

      final steps = recorder.distillEventsIntoSteps(mockEvents);
      expect(steps.length, greaterThanOrEqualTo(3));
      expect(steps.first.action, 'open_app');
      expect(steps[1].action, 'click_text');
      expect(steps[1].params['text'], 'Search');

      await recorder.startRecording('Play Workout Playlist');
      expect(recorder.isRecording, isTrue);
      expect(recorder.activeMacroGoal, 'Play Workout Playlist');

      final skill = await recorder.stopRecording(mockEvents: mockEvents);
      expect(recorder.isRecording, isFalse);
      expect(skill, isNotNull);
      expect(skill!.goal, 'Play Workout Playlist');
      expect(hermes.agentMd, contains('Macro: Play Workout Playlist'));

      // Clean up
      await recorder.deleteSkill(skill.id);
    });

    test('Smart Home Service parses voice commands and configures payloads', () async {
      final smartHome = SmartHomeService.instance;

      final turnOnReply = await smartHome.handleVoiceCommand('turn on the living room light at 80%');
      expect(turnOnReply, contains('80 percent'));

      final turnOffReply = await smartHome.handleVoiceCommand('turn off the lights');
      expect(turnOffReply, contains('deactivated'));

      final dimReply = await smartHome.handleVoiceCommand('dim the lights to 15%');
      expect(dimReply, contains('15 percent'));

      final defaultReply = await smartHome.handleVoiceCommand('toggle smart light');
      expect(defaultReply, contains('updated'));
    });

    test('Commute & Traffic Service calculates duration, congestion, and departure buffer', () async {
      final commute = CommuteTrafficService.instance;

      final status = await commute.checkCommute(
        origin: '10 Downing Street',
        destination: 'Stark Tower',
        targetArrivalTime: DateTime.now().add(const Duration(minutes: 30)),
        meetingTitle: 'Executive Review',
      );

      expect(status.durationMinutes, greaterThan(0));
      expect(status.distanceKm, greaterThan(0));
      expect(status.spokenSummary, contains('Executive Review'));
      expect(status.recommendedDepartureTime, isNotNull);
      expect(status.isUrgent, isTrue);
    });

    test('AiService accurately routes new intents via fallback', () {
      final eyeIntent = GenyIntent.fallback('Geny look at this component');
      expect(eyeIntent.type, GenyIntentType.vision);

      final macroIntent = GenyIntent.fallback('record macro Order Starbucks');
      expect(macroIntent.type, GenyIntentType.macro);

      final smartHomeIntent = GenyIntent.fallback('turn on the living room light');
      expect(smartHomeIntent.type, GenyIntentType.smartHome);

      final commuteIntent = GenyIntent.fallback('how is traffic to work today');
      expect(commuteIntent.type, GenyIntentType.commute);

      final installIntent = GenyIntent.fallback('install instagram');
      expect(installIntent.type, GenyIntentType.action);
      expect(installIntent.actionGoal, 'install instagram');

      final downloadIntent = GenyIntent.fallback('download whatsapp');
      expect(downloadIntent.type, GenyIntentType.action);
    });

    test('TaskStep.tryParse handles action aliases, JSON formats, and natural language outputs', () {
      // 1. Standard JSON with alias 'open'
      final stepOpen = TaskStep.tryParse('{"action": "open", "params": {"app": "Play Store"}}');
      expect(stepOpen, isNotNull);
      expect(stepOpen!.action, TaskStep.actionOpenApp);
      expect(stepOpen.stringParam('app'), 'Play Store');

      // 2. Action alias 'click' mapped to 'click_text'
      final stepClick = TaskStep.tryParse('{"action": "click", "params": {"text": "Install"}}');
      expect(stepClick, isNotNull);
      expect(stepClick!.action, TaskStep.actionClickText);
      expect(stepClick.stringParam('text'), 'Install');

      // 3. Action alias 'tap' with coordinates mapped to 'click_at'
      final stepTapAt = TaskStep.tryParse('{"action": "tap", "params": {"x": 500, "y": 800}}');
      expect(stepTapAt, isNotNull);
      expect(stepTapAt!.action, TaskStep.actionClickAt);
      expect(stepTapAt.intParam('x'), 500);
      expect(stepTapAt.intParam('y'), 800);

      // 4. Action alias 'type' mapped to 'type_text'
      final stepType = TaskStep.tryParse('{"action": "type", "params": {"text": "instagram"}}');
      expect(stepType, isNotNull);
      expect(stepType!.action, TaskStep.actionTypeText);
      expect(stepType.stringParam('text'), 'instagram');

      // 5. Natural language prose fallback from local models
      final stepProseClick = TaskStep.tryParse('**Action:** Click [0] (Button) Search apps & games');
      expect(stepProseClick, isNotNull);
      expect(stepProseClick!.action, TaskStep.actionClickText);
      expect(stepProseClick.stringParam('text'), 'Search apps & games');

      // 6. Natural language open app
      final stepProseOpen = TaskStep.tryParse('I will launch the Play Store app to proceed.');
      expect(stepProseOpen, isNotNull);
      expect(stepProseOpen!.action, TaskStep.actionOpenApp);
      expect(stepProseOpen.stringParam('app'), 'Play Store');
    });

    test('Superpowers: SoundRadar, Sentry, Storage, and Telemetry Services', () async {
      // 1. Sound Radar Service
      final soundRadar = SoundRadarService.instance;
      final ambientScan = await soundRadar.scanAmbientEnvironment();
      expect(ambientScan, isNotEmpty);
      expect(ambientScan, isNotEmpty);

      // 2. Sound Radar Music Search via hint (handles online query or offline acoustic fallback)
      final trackFound = await soundRadar.identifyMusic('Bohemian Rhapsody Queen');
      expect(trackFound, isNotEmpty);
      expect(trackFound, isNotEmpty);

      // 3. Sentry Service initialization
      final sentry = SentryService.instance;
      expect(sentry.isArmed, isFalse);

      // 4. Phone Storage Service (mock or graceful failure on unit test)
      final storage = PhoneStorageService.instance;
      final res = await storage.createFile(
        fileName: 'test_song.txt',
        content: 'Stark lyrics',
      );
      expect(res, isNotNull);

      // 5. System Diagnostics Service fallback on desktop test
      final diag = SystemDiagnosticsService.instance;
      final spokenDiag = await diag.getDiagnosticsSpoken();
      expect(spokenDiag, isNotEmpty);

      // 6. App Usage Service
      final appUsage = AppUsageService.instance;
      final spokenApps = await appUsage.getInstalledAppsSpoken();
      expect(spokenApps, isNotEmpty);
    });

    test('PersonalityService provides dynamic, non-repetitive responses', () {
      final personality = PersonalityService.instance;

      final musicAck1 = personality.getMusicAck('Closer');
      final musicAck2 = personality.getMusicAck('Believer');
      expect(musicAck1, isNotEmpty);
      expect(musicAck2, isNotEmpty);

      final appAck = personality.getAppAck('Instagram');
      expect(appAck, contains('Instagram'));

      final installAck = personality.getInstallAck('WhatsApp');
      expect(installAck, contains('WhatsApp'));

      final standDown = personality.getStandDown();
      expect(standDown, isNotEmpty);

      final formAck = personality.getFormFillAck();
      expect(formAck, isNotEmpty);

      final formDone = personality.getFormFillCompletion(4);
      expect(formDone, contains('4'));
    });

    test('FormFillingService initializes and detects profile data', () async {
      final formService = FormFillingService.instance;
      expect(formService, isNotNull);

      // Pre-seed some facts in user knowledge
      await HermesEvolutionService.instance.updateUser('''
# User Profile
- Name: Tony Stark
- Email: tony@starkindustries.com
- Phone: +1 415 555 0199
- City: Malibu
''');

      final profile = formService.buildUserKnowledgeMap();
      expect(profile['name'], 'Tony Stark');
      expect(profile['email'], 'tony@starkindustries.com');
      expect(profile['phone'], '+1 415 555 0199');
      expect(profile['city'], 'Malibu');
    });

    test('Creator identity declares Geny open-source origin', () {
      final personality = PersonalityService.instance;
      final answer = personality.getCreatorAnswer();
      expect(answer, contains('Geny'));
      expect(answer.toLowerCase(), isNot(contains('tony stark')));
      expect(answer.toLowerCase(), isNot(contains('abuzar')));
    });

    test('Executive greeting synthesizes date, time, meetings, and tasks', () async {
      final personality = PersonalityService.instance;
      await HermesEvolutionService.instance.updateUser('''
# User Profile
- Name: Alex
- Identity: Primary Operator
''');
      await CalendarReminderService.instance.init();
      await TodoService.instance.init();

      // Add a test meeting
      await CalendarReminderService.instance.addItem(
        title: 'Jack',
        description: 'Meeting with Jack',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        durationMinutes: 30,
        isReminder: false,
      );

      // Add a test task
      await TodoService.instance.addTask('Prepare quarterly analysis', priority: TodoPriority.high);

      final greeting = await personality.generateExecutiveGreeting();
      expect(greeting, contains('Alex'));
      expect(greeting.toLowerCase(), contains('meeting'));
      expect(greeting, contains('Prepare quarterly analysis'));
      expect(greeting, contains('to-do'));
    });

    test('Dynamic News, Web Search, and Sentry Protocol acknowledgments are condition-aware', () {
      final personality = PersonalityService.instance;
      final newsAck = personality.getNewsAck();
      expect(newsAck.isNotEmpty, true);
      expect(newsAck.toLowerCase(), anyOf(contains('news'), contains('headline'), contains('wire'), contains('dispatches'), contains('feed')));

      final techNewsAck = personality.getNewsAck('technology');
      expect(techNewsAck.toLowerCase(), contains('technology'));

      final searchAck = personality.getWebSearchAck('quantum computing');
      expect(searchAck.isNotEmpty, true);
      expect(searchAck.toLowerCase(), anyOf(contains('quantum computing'), contains('web'), contains('online')));

      final sentryArmAck = personality.getSentryAck(arm: true);
      expect(sentryArmAck.toLowerCase(), anyOf(contains('sentry protocol'), contains('sentry mode')));
      expect(sentryArmAck.toLowerCase(), anyOf(contains('armed'), contains('active'), contains('activated')));

      final sentryDisarmAck = personality.getSentryAck(arm: false);
      expect(sentryDisarmAck.toLowerCase(), anyOf(contains('sentry protocol'), contains('sentry mode'), contains('sentry watchdog')));
      expect(sentryDisarmAck.toLowerCase(), anyOf(contains('disarm'), contains('deactivated'), contains('standing down')));
    });

    test('Sentry Protocol and Sentry Mode equivalence in WorkflowService', () {
      final wf = WorkflowService.instance;
      wf.init();

      final modeMatch = wf.findMatch('activate sentry mode');
      expect(modeMatch != null, true);
      expect(modeMatch!.id, 'sentry');

      final protocolMatch = wf.findMatch('activate sentry protocol');
      expect(protocolMatch != null, true);
      expect(protocolMatch!.id, 'sentry');

      final protocalMatch = wf.findMatch('engage sentry protocal');
      expect(protocalMatch != null, true);
      expect(protocalMatch!.id, 'sentry');
    });

    test('Questions and educational inquiries never trigger hardware workflows', () {
      final wf = WorkflowService.instance;
      wf.init();

      expect(wf.findMatch('what is machine learning'), isNull);
      expect(wf.findMatch('how does an engine work'), isNull);
      expect(wf.findMatch('why do people sleep'), isNull);
      expect(wf.findMatch('tell me about night mode in photography'), isNull);
      expect(wf.findMatch('who directed the movie Inception'), isNull);
      expect(wf.findMatch('explain quantum computing'), isNull);

      // Verify legitimate workflow commands still work
      final study = wf.findMatch('Geny activate study mode');
      expect(study, isNotNull);
      expect(study!.id, 'study');

      final night = wf.findMatch('going to sleep now goodnight');
      expect(night, isNotNull);
      expect(night!.id, 'night');
    });

    test('PersonalityService generates natural question acknowledgments', () {
      final personality = PersonalityService.instance;
      final mlAck = personality.getQuestionAck('what is machine learning');
      expect(mlAck.toLowerCase(), contains('machine learning'));
      expect(mlAck.toLowerCase(), anyOf(contains('break that down'), contains('intuitive explanation'), contains('explain how it works'), contains('analyzing')));

      final generalAck = personality.getQuestionAck('explain quantum mechanics');
      expect(generalAck.isNotEmpty, true);
    });

    test('GenyIntent fallback treats questions as webSearch or chat rather than workflows', () {
      final intent = GenyIntent.fallback('what is machine learning');
      expect(intent.type, anyOf(GenyIntentType.webSearch, GenyIntentType.chat));
      expect(intent.type, isNot(GenyIntentType.workflow));

      final chatIntent = GenyIntent.fallback('tell me a creative bedtime story about space');
      expect(chatIntent.type, GenyIntentType.chat);
      expect(chatIntent.type, isNot(GenyIntentType.workflow));
    });
  });

  group('Stark Superpowers Suite Verification', () {
    test('1. Iron Man Air Gestures handles mid-air simulation and state transitions', () async {
      final air = AirGestureService.instance;
      air.voiceFeedback = false; // silence TTS in tests

      final rWave = await air.simulateGesture('wave');
      expect(rWave, contains('Next Media Track'));
      expect(air.lastGesture, 'wave');

      final rHover = await air.simulateGesture('palm_hover');
      expect(rHover, contains('Play / Pause Toggled'));
      expect(air.lastGesture, 'palm_hover');

      final rDouble = await air.simulateGesture('double_wave');
      expect(rDouble, contains('Take Screenshot'));
      expect(air.lastGesture, 'double_wave');
    });

    test('2. Arc Reactor Charging Telemetry formats electrical and thermal metrics', () async {
      final charging = ChargingTelemetryService.instance;
      charging.voiceAnnouncements = false;

      final speech = await charging.getSpokenTelemetry();
      expect(speech.toLowerCase(), contains('arc reactor'));
      expect(speech.toLowerCase(), contains('thermals'));
    });

    test('3. Polyglot Diplomat manages language swapping and supported catalogs', () {
      final diplomat = PolyglotDiplomatService.instance;
      diplomat.sourceLanguage = 'English';
      diplomat.targetLanguage = 'Spanish';

      diplomat.swapLanguages();
      expect(diplomat.sourceLanguage, 'Spanish');
      expect(diplomat.targetLanguage, 'English');

      expect(PolyglotDiplomatService.supportedLanguages.contains('Hindi'), isTrue);
      expect(PolyglotDiplomatService.supportedLanguages.contains('Japanese'), isTrue);
      expect(PolyglotDiplomatService.supportedLanguages.contains('German'), isTrue);
    });

    test('4. Code Black Deceptive Lockout arms, records intruder breaches, and verifies voice override', () async {
      final black = CodeBlackService.instance;
      await black.arm();
      expect(black.isArmed, isTrue);

      black.recordIntruderTouch();
      black.recordIntruderTouch();
      expect(black.breachAttemptCount, 2);

      expect(black.checkVoiceDisarm('override alpha immediately'), isTrue);
      expect(black.isArmed, isFalse);

      await black.arm();
      expect(black.checkVoiceDisarm('stand down geny'), isTrue);
      expect(black.isArmed, isFalse);
    });

    test('5. Floating Co-Pilot data modeling and context parsing', () {
      final analysis = ScreenContextAnalysis(
        appName: 'WhatsApp',
        category: 'chat',
        summary: 'Incoming message from Jack asking for project update',
        quickReplies: ['Will send shortly!', 'Almost done', 'Let us discuss at 4'],
        warningOrScamAlert: null,
      );

      expect(analysis.appName, 'WhatsApp');
      expect(analysis.category, 'chat');
      expect(analysis.quickReplies.length, 3);
    });

    test('6. Overhead Airspace Radar models aircraft telemetry and compass directions', () {
      final flight = OverheadAircraft(
        callsign: 'UAE203',
        originCountry: 'UAE',
        altitudeFeet: 36000,
        velocityKnots: 520,
        headingDegrees: 90, // East
        distanceMiles: 12.4,
      );

      expect(flight.callsign, 'UAE203');
      expect(flight.compassDirection, 'E');

      final flightNorth = OverheadAircraft(
        callsign: 'BAW1',
        originCountry: 'UK',
        altitudeFeet: 15000,
        velocityKnots: 300,
        headingDegrees: 0, // North
        distanceMiles: 8.0,
      );
      expect(flightNorth.compassDirection, 'N');
    });

    test('7. Chaotic Brain Dump Multi-Task Decoupler heuristic classification', () {
      final decoupler = MultiTaskDecouplerService.instance;

      expect(
        decoupler.isMultiTaskDump('remind me to call Jack at 4pm and draft a whatsapp to Sarah'),
        isTrue,
      );
      expect(
        decoupler.isMultiTaskDump('add milk to my todo list and calculate 25 percent of 140'),
        isTrue,
      );
      expect(
        decoupler.isMultiTaskDump('what is the weather today in Tokyo'),
        isFalse,
      );
    });

    test('8. Network Cyber Security Audit models devices and calculates posture', () {
      final dev = NetworkDevice(
        ip: '192.168.1.45',
        mac: 'AA:BB:CC:DD:EE:FF',
        vendor: 'Raspberry Pi Foundation',
        hostname: 'LAN Client',
        openPorts: [22, 554],
        isCameraStream: true,
      );

      expect(dev.isCameraStream, isTrue);
      expect(dev.openPorts, contains(554));

      final report = NetworkAuditReport(
        localIp: '192.168.1.10',
        subnetPrefix: '192.168.1.0/24',
        totalDevicesFound: 4,
        devices: [dev],
        securityScore: 85,
        vulnerabilities: ['RTSP Video feed exposed on port 554'],
        pingLatencyMs: 12,
        auditedAt: DateTime.now(),
      );

      expect(report.totalDevicesFound, 4);
      expect(report.securityScore, 85);
      expect(report.vulnerabilities.first, contains('RTSP Video feed'));
    });

    test('9. GenyIntent.fallback routes all 9 superpowers to correct intents', () {
      expect(GenyIntent.fallback('activate air gestures').type, GenyIntentType.airGestures);
      expect(GenyIntent.fallback('charging telemetry').type, GenyIntentType.chargingTelemetry);
      expect(GenyIntent.fallback('activate polyglot diplomat').type, GenyIntentType.polyglotDiplomat);
      expect(GenyIntent.fallback('activate code black').type, GenyIntentType.codeBlack);
      expect(GenyIntent.fallback('activate floating copilot').type, GenyIntentType.floatingCopilot);
      expect(GenyIntent.fallback('what is flying above me').type, GenyIntentType.airspaceRadar);
      expect(
        GenyIntent.fallback('remind me to call Bob at 5pm and draft a message to Alice').type,
        GenyIntentType.multiTaskDump,
      );
      expect(GenyIntent.fallback('Geny, solve this equation').type, GenyIntentType.opticalSolver);
      expect(GenyIntent.fallback('audit my network').type, GenyIntentType.networkAudit);
    });

    test('10. OpticalSolverService classifies domains and provides structured solutions', () {
      final solver = OpticalSolverService.instance;
      expect(solver.activeMode, OpticalSolveMode.auto);
      solver.activeMode = OpticalSolveMode.codeDebug;
      expect(solver.activeMode, OpticalSolveMode.codeDebug);
      solver.activeMode = OpticalSolveMode.auto;
    });

    test('11. Geny visual screen style can switch between Arc Reactor and Geny suit', () async {
      final settings = SettingsService.instance;
      await settings.init();

      // Default should be arcReactor
      expect(settings.genyScreenStyle, GenyScreenStyle.arcReactor);

      // Switch to geny suit hologram
      await settings.setGenyScreenStyle(GenyScreenStyle.geny);
      expect(settings.genyScreenStyle, GenyScreenStyle.geny);

      // Switch back to arcReactor
      await settings.setGenyScreenStyle(GenyScreenStyle.arcReactor);
      expect(settings.genyScreenStyle, GenyScreenStyle.arcReactor);
    });
  });
}
