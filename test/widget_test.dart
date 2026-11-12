import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:private_agent/app.dart';
import 'package:private_agent/i18n/geny_i18n.dart';
import 'package:private_agent/models/skill.dart';
import 'package:private_agent/models/task_step.dart';
import 'package:private_agent/screens/settings/settings_screen.dart';
import 'package:private_agent/services/geny_tools_service.dart';
import 'package:private_agent/services/settings_service.dart';
import 'package:private_agent/services/voice_service.dart';
import 'package:private_agent/services/workflow_service.dart';

void main() {
  group('TaskStep parsing', () {
    test('parses a plain JSON object', () {
      final step = TaskStep.tryParse(
        '{"action":"click_text","params":{"text":"Search"},'
        '"reasoning":"tap search","is_complete":false}',
      );
      expect(step, isNotNull);
      expect(step!.action, TaskStep.actionClickText);
      expect(step.stringParam('text'), 'Search');
      expect(step.isComplete, isFalse);
    });

    test('parses JSON wrapped in markdown fences with prose around it', () {
      final step = TaskStep.tryParse(
        'Here is my decision:\n```json\n{"action":"scroll",'
        '"params":{"direction":"down"},"is_complete":false}\n```\nDone.',
      );
      expect(step, isNotNull);
      expect(step!.action, TaskStep.actionScroll);
      expect(step.stringParam('direction'), 'down');
    });

    test('parses done action with is_complete', () {
      final step = TaskStep.tryParse('{"action":"done","is_complete":true}');
      expect(step, isNotNull);
      expect(step!.isComplete, isTrue);
    });

    test('rejects non-JSON and unknown actions', () {
      expect(TaskStep.tryParse('I cannot help with that'), isNull);
      expect(TaskStep.tryParse('{"action":"explode"}'), isNull);
    });
  });

  group('Skill matching', () {
    test('normalize collapses whitespace and case', () {
      expect(Skill.normalize('  Open   YouTube '), 'open youtube');
    });

    test('similarity rewards shared tokens', () {
      expect(Skill.similarity('open youtube', 'open youtube'), 1.0);
      expect(
        Skill.similarity(
          'open youtube and play lofi',
          'open youtube and play jazz',
        ),
        greaterThan(0.5),
      );
      expect(Skill.similarity('open youtube', 'call mom'), 0.0);
    });
  });

  group('SettingsService', () {
    test('persists AI settings', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService.instance;
      await settings.init();

      await settings.setProvider('openrouter');
      expect(settings.provider, 'openrouter');
      expect(settings.baseUrl, 'https://openrouter.ai/api/v1');

      await settings.setMaxSteps(25);
      expect(settings.maxSteps, 25);

      await settings.setThemeMode(ThemeMode.dark);
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('persists the interaction mode, defaulting to agent', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService.instance;
      await settings.init();

      expect(settings.appMode, AppMode.agent);

      await settings.setAppMode(AppMode.chat);
      expect(settings.appMode, AppMode.chat);

      await settings.setAppMode(AppMode.geny);
      expect(settings.appMode, AppMode.geny);

      await settings.setAppMode(AppMode.agent);
      expect(settings.appMode, AppMode.agent);
    });

    test('backward compatibility migrates saved genie to agent', () async {
      SharedPreferences.setMockInitialValues({'ui_app_mode': 'genie'});
      final settings = SettingsService.instance;
      await settings.init();

      expect(settings.appMode, AppMode.agent);
    });
  });

  testWidgets('app boots into onboarding on first run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    await tester.pumpWidget(const GenyApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome to Geny'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('custom Ollama model survives unrelated settings changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    await settings.init();

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Select the Ollama provider chip (fills the default model).
    await tester.tap(find.text('Ollama (local)'));
    await tester.pumpAndSettle();
    expect(find.text('llama3.2'), findsOneWidget);

    // Type a custom model name into the Model field.
    await tester.enterText(
      find.widgetWithText(TextField, 'Model'),
      'qwen2.5:7b',
    );

    // Change an unrelated setting — this used to reset the Model field
    // back to the provider default.
    await tester.tap(find.text('Send system prompt'));
    await tester.pumpAndSettle();

    final modelField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Model'),
    );
    expect(modelField.controller!.text, 'qwen2.5:7b');

    // Saving persists the custom model, not the default.
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(settings.model, 'qwen2.5:7b');
  });

  group('GENY & Hermes Workflow tests', () {
    test('WorkflowService matches study, sleep, and cinema protocols', () async {
      SharedPreferences.setMockInitialValues({});
      final workflows = WorkflowService.instance;
      await workflows.init();

      final studyMatch = workflows.findMatch('Geny I have to study for exams');
      expect(studyMatch, isNotNull);
      expect(studyMatch!.id, 'study');
      expect(studyMatch.brightness, 0.45);
      expect(studyMatch.volume, 0.0);

      final nightMatch = workflows.findMatch('going to sleep now goodnight');
      expect(nightMatch, isNotNull);
      expect(nightMatch!.id, 'night');
      expect(nightMatch.brightness, 0.05);

      final cinemaMatch = workflows.findMatch('let us watch a movie in cinema mode');
      expect(cinemaMatch, isNotNull);
      expect(cinemaMatch!.id, 'cinema');
      expect(cinemaMatch.volume, 0.70);
    });

    test('SettingsService persists GENY configuration', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService.instance;
      await settings.init();

      expect(settings.genyAlwaysOn, isTrue);
      expect(settings.genyVoice, 'femaleWarm');
      expect(settings.genyNeuralVoice, 'en-GB-SoniaNeural');
      expect(settings.useNeuralVoice, isTrue);
      expect(settings.genyWorkflowsEnabled, isTrue);

      await settings.setGenyAlwaysOn(false);
      await settings.setGenyVoice('maleDeep');
      await settings.setGenyNeuralVoice('en-US-AvaNeural');
      await settings.setUseNeuralVoice(false);
      await settings.setGenyWorkflowsEnabled(false);

      expect(settings.genyAlwaysOn, isFalse);
      expect(settings.genyVoice, 'maleDeep');
      expect(settings.genyNeuralVoice, 'en-US-AvaNeural');
      expect(settings.useNeuralVoice, isFalse);
      expect(settings.genyWorkflowsEnabled, isFalse);
    });

    test('GenyToolsService formats temporal diagnostics', () {
      final dt = GenyToolsService.instance.getCurrentDateTime();
      expect(dt, isNotEmpty);
      expect(dt.contains(DateTime.now().year.toString()), isTrue);
    });

    test('VoiceService sanitizes G.E.N.Y. into natural spoken Geny', () {
      final voice = VoiceService.instance;
      expect(voice.sanitizeForSpeech('I am G.E.N.Y..'), 'I am Geny.');
      expect(voice.sanitizeForSpeech('Hello G.E.N.Y'), 'Hello Geny');
      expect(voice.sanitizeForSpeech('Welcome to GENY mode'), 'Welcome to Geny mode');
    });
  });
}
