import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../models/task_history_entry.dart';
import '../widgets/airspace_radar_dialog.dart';
import '../widgets/brain_dump_dialog.dart';
import '../widgets/network_audit_dialog.dart';
import '../widgets/optical_solver_dialog.dart';
import '../widgets/polyglot_diplomat_dialog.dart';
import 'ai_service.dart';
import 'air_gesture_service.dart';
import 'airspace_radar_service.dart';
import 'app_launcher_service.dart';
import 'app_usage_service.dart';
import 'calendar_reminder_service.dart';
import 'charging_telemetry_service.dart';
import 'code_black_service.dart';
import 'commute_traffic_service.dart';
import 'conversational_memory_service.dart';
import 'email_triage_service.dart';
import 'finance_tracking_service.dart';
import 'floating_copilot_service.dart';
import 'form_filling_service.dart';
import 'hermes_evolution_service.dart';
import 'inbox_service.dart';
import 'geny_tools_service.dart';
import 'macro_recorder_service.dart';
import 'message_drafting_service.dart';
import 'multi_task_service.dart';
import 'network_audit_service.dart';
import 'notes_knowledge_service.dart';
import 'optical_solver_service.dart';
import 'personality_service.dart';
import 'phone_storage_service.dart';
import 'polyglot_diplomat_service.dart';
import 'proactive_agent_service.dart';
import 'routine_automation_service.dart';
import 'screen_automation_service.dart';
import 'security_alert_service.dart';
import 'sentry_service.dart';
import 'settings_service.dart';
import 'skill_memory_service.dart';
import 'smart_home_service.dart';
import 'sound_radar_service.dart';
import 'sports_service.dart';
import 'system_control_service.dart';
import 'system_diagnostics_service.dart';
import 'task_executor.dart';
import 'todo_service.dart';
import 'vision_perception_service.dart';
import 'voice_service.dart';
import 'workflow_service.dart';

/// Active operational phase of GENY.
enum GenyPhase {
  idle, // Standby, listening for wake word or prompt
  listening, // Actively recording user speech
  thinking, // Processing intent / AI reasoning
  executing, // Device automation or workflow in progress
  speaking, // Vocalizing audio reply via TTS
}

/// Central controller for GENY Mode:
/// - Always-On hands-free voice assistant with Wake Words ("Hey Geny", "Hello Geny", "Geny")
/// - Ignores ambient room chatter in standby until wake word is recognized
/// - Active conversational continuation window for hands-free follow-up queries
/// - Hermes Self-Evolving Workflow Engine integration (Study, Night, Work, Cinema)
/// - Connects to [AiService.interpretGenyCommand] for action vs chat vs system vs news
/// - Dispatches automation directly to [TaskExecutor]
/// - Emits high-frequency telemetry for the HUD animation painter
class GenyService extends ChangeNotifier {
  GenyService._() {
    _initListeners();
  }
  static final GenyService instance = GenyService._();

  final VoiceService _voice = VoiceService.instance;
  final AiService _ai = AiService.instance;
  final TaskExecutor _executor = TaskExecutor.instance;
  final SystemControlService _system = SystemControlService.instance;
  final ScreenAutomationService _automation = ScreenAutomationService.instance;

  GenyPhase _phase = GenyPhase.idle;
  GenyPhase get phase => _phase;

  String _lastUserSpeech = '';
  String get lastUserSpeech => _lastUserSpeech;

  String _lastGenySpeech = 'At your service. Say "Hey Geny" anytime.';
  String get lastGenySpeech => _lastGenySpeech;

  String _statusMessage = 'STANDBY // SAY "HEY GENY"';
  String get statusMessage => _statusMessage;

  String? _currentTaskGoal;
  String? get currentTaskGoal => _currentTaskGoal;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  double _soundLevel = 0.0;
  double get soundLevel => _soundLevel;

  bool _initialized = false;
  bool _isInGenyMode = false;
  bool get isInGenyMode => _isInGenyMode;
  bool _isAwake = false;
  bool get isAwake => _isAwake;

  VoidCallback? onWakeWordTriggered;

  Timer? _awakeTimer;
  Timer? _speechSilenceTimer;
  Timer? _proactiveConfirmationTimer;
  Timer? _followUpSilenceTimer;
  bool _isInFollowUp = false;
  bool get isInFollowUp => _isInFollowUp;
  ProactiveSuggestion? _pendingProactiveSuggestion;
  final List<Map<String, String>> _dialogHistory = [];

  bool get isAlwaysOn => SettingsService.instance.genyAlwaysOn;
  bool get _shouldListenContinuously => isAlwaysOn || _isInGenyMode;
  ProactiveSuggestion? get pendingProactiveSuggestion => _pendingProactiveSuggestion;
  bool get isAwaitingProactiveConfirmation => _pendingProactiveSuggestion != null;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _broadcastOverlayState();
  }

  void _broadcastOverlayState() {
    try {
      FlutterOverlayWindow.shareData(jsonEncode({
        'type': 'geny_state',
        'phase': _phase.name,
        'status': _statusMessage,
        'lastSpeech': _lastGenySpeech,
      }));
    } catch (_) {}
  }

  void _initListeners() {
    if (_initialized) return;
    _initialized = true;

    // Ensure workflows and intelligence modules are initialized
    WorkflowService.instance.init();
    ConversationalMemoryService.instance.init();
    PersonalityService.instance.init();
    CalendarReminderService.instance.init();
    TodoService.instance.init();
    NotesKnowledgeService.instance.init();
    MacroRecorderService.instance.init();
    unawaited(ProactiveAgentService.instance.evaluateProactiveNeeds());
    ProactiveAgentService.instance.startProactiveMonitor();

    _voice.soundLevel.addListener(() {
      _soundLevel = _voice.soundLevel.value;
      notifyListeners();
    });

    _voice.onSpeechStatus = (status) {
      if (status == 'endOfSpeech') {
        if (_isAwake && _lastUserSpeech.isNotEmpty) {
          _speechSilenceTimer?.cancel();
          _speechSilenceTimer = Timer(const Duration(milliseconds: 350), () {
            final trimmed = _lastUserSpeech.trim();
            if (trimmed.isNotEmpty) {
              unawaited(_handleSpeechResult(trimmed));
            }
          });
        }
      }
    };

    _voice.isSpeaking.addListener(() {
      if (_voice.isSpeaking.value) {
        _speechSilenceTimer?.cancel();
        if (_phase != GenyPhase.executing) {
          _phase = GenyPhase.speaking;
          notifyListeners();
        }
      } else {
        if (_phase == GenyPhase.speaking) {
          _phase = _executor.isBusy ? GenyPhase.executing : GenyPhase.idle;
          notifyListeners();
        }
        // Continuous listening trigger: when speech output finishes, resume passive wake-word listening
        if (_shouldListenContinuously) {
          if (_isAwake) {
            _keepAwake();
          }
          startListening();
        }
      }
    });

    _voice.listeningNotifier.addListener(() {
      if (!_voice.listeningNotifier.value) {
        if (_phase == GenyPhase.listening) {
          _phase = _executor.isBusy ? GenyPhase.executing : GenyPhase.idle;
          notifyListeners();
        }
      }
    });

    _executor.addListener(() {
      if (_phase == GenyPhase.executing) {
        _currentStep = _executor.step;
        if (!_executor.isBusy) {
          _currentStep = 0;
          _currentTaskGoal = null;
          _phase =
              _voice.isSpeaking.value ? GenyPhase.speaking : GenyPhase.idle;
          notifyListeners();
          if (_shouldListenContinuously) {
            startListening();
          }
        }
      } else {
        notifyListeners();
      }
    });

    if (isAlwaysOn) {
      ensureAlwaysOnRunning();
    }
  }

  void _wakeUp() {
    _isAwake = true;
    _keepAwake();
  }

  void _keepAwake() {
    _awakeTimer?.cancel();
    _awakeTimer = Timer(const Duration(seconds: 15), () {
      if (_phase != GenyPhase.executing) {
        _isAwake = false;
        _statusMessage = _shouldListenContinuously
            ? 'STANDBY // SAY "HEY GENY"'
            : 'READY // TAP TO TALK';
        notifyListeners();
      }
    });
  }

  void _standDown() {
    _speechSilenceTimer?.cancel();
    _proactiveConfirmationTimer?.cancel();
    _followUpSilenceTimer?.cancel();
    _isInFollowUp = false;
    _pendingProactiveSuggestion = null;
    _isAwake = false;
    _awakeTimer?.cancel();
    _lastUserSpeech = '';
    _statusMessage = _shouldListenContinuously
        ? 'STANDBY // SAY "HEY GENY"'
        : 'READY // TAP TO TALK';
    _phase = GenyPhase.idle;
    notifyListeners();
  }

  /// Engages immediate hands-free follow-up continuous listening after speaking.
  /// Allows the user to ask follow-up questions or give consecutive commands
  /// without repeating the wake word.
  Future<void> _startFollowUpListening() async {
    _followUpSilenceTimer?.cancel();
    _speechSilenceTimer?.cancel();

    _wakeUp();
    _isInFollowUp = true;
    _phase = GenyPhase.listening;
    _statusMessage = 'LISTENING // ASK A FOLLOW-UP OR COMMAND';
    notifyListeners();

    await startListening(manual: true);

    // 7.5 second conversational window before standing down
    _followUpSilenceTimer = Timer(const Duration(milliseconds: 7500), () {
      _onFollowUpTimeout();
    });
  }

  void _onFollowUpTimeout() {
    _followUpSilenceTimer?.cancel();
    _isInFollowUp = false;
    _standDown();
    if (!_shouldListenContinuously) {
      stopListening();
    }
  }

  /// Ensures the Google Assistant style continuous listener is running.
  void ensureAlwaysOnRunning() {
    if (!SettingsService.instance.genyAlwaysOn) return;
    startListening();
  }

  /// Stops Always-On supervision.
  void stopAlwaysOn() {
    _standDown();
    stopListening();
  }

  /// Extracts the wake word command from speech with robust normalization.
  /// Supports G.E.N.Y., phonetic variants, and Google Assistant wake phrases.
  /// Handles punctuation (commas like "Hey, Geny"), accents, and alternate STT hypotheses.
  /// Returns:
  /// - '' (empty string) if only wake word / greeting was spoken (to wake up and start listening)
  /// - the extracted user command if wake word + command was spoken
  /// - null if no wake word was spoken
  static String? extractWakeCommand(String speech) {
    final raw = speech.trim();
    if (raw.isEmpty) return null;

    // 1. Normalize acronyms, punctuation, and multiple spaces
    var normalized = raw
        .replaceAll(
          RegExp(r'j\s*\.?\s*a\s*\.?\s*r\s*\.?\s*v\s*\.?\s*i\s*\.?\s*s\.?', caseSensitive: false),
          'geny',
        )
        .replaceAll(RegExp(r'[,;:!?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return null;

    // 2. Comprehensive Wake Phrase Pattern
    // Matches:
    // - (hey | hello | hi | ok | okay | yo | listen | wake up | dear) + [optional space] + (geny | javis | jervis | jarves | jarvice | travis | service | davis | davies | harvest | jarvi | google)
    // - standalone (geny | javis | jervis | jarves | jarvice | charvis | garvis | jarvi)
    // - (wake up geny | geny wake up | geny please)
    final wakePattern = RegExp(
      r'\b(?:(?:hey|hello|hi|okay|ok|yo|listen|wake\s+up|dear)\s+(?:geny|javis|jervis|jarves|jarvice|charvis|garvis|gervis|travis|service|davis|davies|harvest|jarvi|google)|(?:geny|javis|jervis|jarves|jarvice|charvis|garvis|jarvi)\s+(?:wake\s+up|please|online)|(?:geny|javis|jervis|jarves|jarvice|charvis|garvis|jarvi)|(?:hey|okay|ok|hello|hi)\s+google)\b',
      caseSensitive: false,
    );

    final match = wakePattern.firstMatch(normalized);
    if (match == null) return null;

    // Command after wake word: e.g. "Hey Geny, what time is it" -> "what time is it"
    final after = normalized
        .substring(match.end)
        .replaceAll(RegExp(r'^[,\s!?\-:;]+'), '')
        .trim();

    // Command before wake word: e.g. "What time is it, Geny" -> "What time is it"
    final before = normalized
        .substring(0, match.start)
        .replaceAll(RegExp(r'[,\s!?\-:;]+$'), '')
        .trim();

    if (after.isNotEmpty) {
      final cleanAfter = after.replaceFirst(
        RegExp(r'^(?:wake\s+up|please|online)\s*', caseSensitive: false),
        '',
      ).trim();
      return cleanAfter.isNotEmpty ? cleanAfter : '';
    }

    if (before.isNotEmpty) {
      final lowerBefore = before.toLowerCase();
      // If "before" was just a greeting prefix (e.g. "Hey" from "Hey, Geny"), return empty string so it wakes up
      if (lowerBefore == 'hey' ||
          lowerBefore == 'hello' ||
          lowerBefore == 'hi' ||
          lowerBefore == 'ok' ||
          lowerBefore == 'okay' ||
          lowerBefore == 'yo' ||
          lowerBefore == 'wake up') {
        return '';
      }
      return before;
    }

    // Only wake word was spoken: e.g. "Hey Geny" or "Geny"
    return '';
  }

  String? _extractWakeCommand(String speech) => extractWakeCommand(speech);

  /// Displays a modal dialog safely using the global navigation key.
  void _showModalSafely(Widget dialog) {
    try {
      final nav = GenyApp.navigatorKey.currentState;
      if (nav != null && nav.context.mounted) {
        showDialog(
          context: nav.context,
          barrierColor: const Color(0xB3000000),
          builder: (_) => dialog,
        );
      }
    } catch (e) {
      debugPrint('[GenyService] Modal launch error: $e');
    }
  }

  /// Called when user navigates into GENY mode.
  void onEnterGenyMode() {
    _isInGenyMode = true;
    _standDown();
    startListening();
    // Arm mid-air proximity sensor for zero-touch gestures while in GENY mode
    unawaited(AirGestureService.instance.start());
    _statusMessage = 'STANDBY // SAY "HEY GENY"';
    notifyListeners();
  }

  /// Called when user leaves GENY mode to prevent background audio captures.
  void onExitGenyMode() {
    _isInGenyMode = false;
    unawaited(AirGestureService.instance.stop());
    // Always-On mode listens continuously across the app like Google Assistant
    if (!isAlwaysOn) {
      _standDown();
      if (_phase == GenyPhase.listening) {
        stopListening();
      }
    }
  }

  /// Toggles Always-On Hands-Free continuous listening mode.
  Future<void> toggleAlwaysOn() async {
    final current = SettingsService.instance.genyAlwaysOn;
    final next = !current;
    await SettingsService.instance.setGenyAlwaysOn(next);
    notifyListeners();

    if (next) {
      _wakeUp();
      ensureAlwaysOnRunning();
      const msg =
          'Always-On continuous listening active. Say "Hey Geny" anytime.';
      _lastGenySpeech = msg;
      _statusMessage = 'STANDBY // SAY "HEY GENY"';
      notifyListeners();
      await _voice.speak(msg);
    } else {
      stopAlwaysOn();
      const msg = 'Always-On listening standby.';
      _lastGenySpeech = msg;
      _statusMessage = 'READY // TAP TO TALK';
      notifyListeners();
      await _voice.speak(msg);
    }
  }

  /// Session guard to ensure rich executive greeting is spoken once per session upon launch
  bool _hasGreetedThisSession = false;

  /// Initial vocal greeting when user enters GENY mode.
  /// Dynamically synthesizes date, time, calendar meetings (e.g. Jack), and pending to-dos.
  Future<void> speakGreeting({bool force = false}) async {
    if (!force && _hasGreetedThisSession) return;
    _hasGreetedThisSession = true;

    onEnterGenyMode();
    _wakeUp();
    _phase = GenyPhase.thinking;
    _statusMessage = 'SYNTHESIZING EXECUTIVE BRIEFING';
    notifyListeners();

    final greeting = await PersonalityService.instance.generateExecutiveGreeting();
    _lastGenySpeech = greeting;
    _phase = GenyPhase.speaking;
    _statusMessage = 'EXECUTIVE BRIEFING // READY';
    notifyListeners();
    await _voice.speak(greeting);
    _standDown();
  }

  /// Autonomously speaks a proactive question and opens a hands-free confirmation listening window.
  Future<void> proactivelySpeakAndAwaitConfirmation(ProactiveSuggestion suggestion) async {
    // If Geny is currently busy in execution, do not interrupt
    if (_phase == GenyPhase.executing) return;

    _proactiveConfirmationTimer?.cancel();
    _pendingProactiveSuggestion = suggestion;
    _lastGenySpeech = suggestion.spokenPrompt;
    _statusMessage = 'PROACTIVE ALERT // ${suggestion.title.toUpperCase()}';
    _phase = GenyPhase.speaking;
    notifyListeners();

    await _voice.speak(suggestion.spokenPrompt);

    if (SettingsService.instance.proactiveVoiceConfirmationEnabled) {
      _wakeUp();
      _phase = GenyPhase.listening;
      _statusMessage = 'AWAITING RESPONSE // SAY "YES" OR "NO"';
      notifyListeners();

      await startListening(manual: true);

      // 8-second confirmation window before gracefully standing down
      _proactiveConfirmationTimer?.cancel();
      _proactiveConfirmationTimer = Timer(const Duration(seconds: 8), () {
        if (_pendingProactiveSuggestion != null) {
          debugPrint('[GenyService] Proactive confirmation timed out with no response');
          _pendingProactiveSuggestion = null;
          _standDown();
        }
      });
    } else {
      _pendingProactiveSuggestion = null;
      if (_shouldListenContinuously) {
        _standDown();
      } else {
        _phase = GenyPhase.idle;
        _statusMessage = 'READY // TAP TO TALK';
        notifyListeners();
      }
    }
  }

  /// Cancels any active proactive confirmation window and returns to standby.
  void dismissProactiveConfirmation() {
    _proactiveConfirmationTimer?.cancel();
    _pendingProactiveSuggestion = null;
    if (_phase == GenyPhase.listening) {
      _standDown();
    }
  }

  /// Checks if spoken response is an affirmative confirmation.
  static bool isAffirmativeResponse(String input) {
    final lower = input.trim().toLowerCase();
    final patterns = [
      r'\b(yes|yeah|yep|yup|sure|please|do\s+it|turn\s+it\s+on|turn\s+on|engage|activate|ok|okay|go\s+ahead|proceed|definitely|affirmative|sounds\s+good|why\s+not|let\x27s\s+do\s+it)\b',
    ];
    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) return true;
    }
    return false;
  }

  /// Checks if spoken response is a negative dismissal.
  static bool isNegativeResponse(String input) {
    final lower = input.trim().toLowerCase();
    final patterns = [
      r'\b(no|nope|nah|not\s+now|never\s+mind|nevermind|don\x27t|cancel|later|dismiss|leave\s+it|negative|stop|skip)\b',
    ];
    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) return true;
    }
    return false;
  }

  /// Toggles speech recognition manually via the UI.
  Future<void> toggleListening() async {
    if (_phase == GenyPhase.listening) {
      await stopListening();
      if (_shouldListenContinuously) {
        _standDown();
        await startListening();
      }
    } else {
      _wakeUp();
      await startListening(manual: true);
    }
  }

  /// Begins recording voice input.
  Future<bool> startListening({bool manual = false}) async {
    await _voice.stopSpeaking();

    if (manual) {
      _wakeUp();
    }

    // Google Home / Google Assistant Architecture:
    // Only set phase to listening if awake or manual tap.
    // In passive standby background waiting for wake-word, stay in idle so UI is calm and does NOT flicker!
    if (_isAwake || !_shouldListenContinuously) {
      _phase = GenyPhase.listening;
      _statusMessage = 'LISTENING // AUDIO RECEPTORS ACTIVE';
    } else {
      _phase = GenyPhase.idle;
      _statusMessage = 'STANDBY // SAY "HEY GENY"';
    }
    notifyListeners();

    final started = await _voice.startListening(
      continuous: _shouldListenContinuously,
      manual: manual,
      onResult: (words, isFinal, candidates) {
        _lastUserSpeech = words;
        debugPrint('[GenyService] Heard: "$words" (candidates: $candidates, isFinal: $isFinal, isAwake: $_isAwake)');

        // Immediate wake detection on partial speech stream
        if (_shouldListenContinuously && !_isAwake) {
          String? wakeCmd = _extractWakeCommand(words);
          if (wakeCmd == null) {
            for (final cand in candidates) {
              final cCmd = _extractWakeCommand(cand);
              if (cCmd != null) {
                wakeCmd = cCmd;
                break;
              }
            }
          }
          if (wakeCmd != null) {
            _wakeUp();
            onWakeWordTriggered?.call();
            HapticFeedback.mediumImpact();

            // Set visual listening state immediately, but NEVER cut off the user!
            // Let the user finish speaking their full command until silence / isFinal.
            _phase = GenyPhase.listening;
            _statusMessage = 'LISTENING // AUDIO RECEPTORS ACTIVE';
            notifyListeners();
          }
        } else if (_isAwake) {
          notifyListeners();
        }

        // Voice Activity / Silence Debounce Timer:
        // When awake or wake-word is present, whenever user stops speaking (silence for ~950ms),
        // automatically trigger command processing so the user never gets stuck waiting on Android's silence detector!
        final hasWake = _extractWakeCommand(words) != null ||
            candidates.any((c) => _extractWakeCommand(c) != null);
        if (_isAwake || hasWake) {
          _speechSilenceTimer?.cancel();
          _speechSilenceTimer = Timer(const Duration(milliseconds: 950), () {
            final trimmed = _lastUserSpeech.trim();
            if (trimmed.isNotEmpty) {
              debugPrint('[GenyService] Silence debounce timer fired for: "$trimmed"');
              unawaited(_handleSpeechResult(trimmed, candidates));
            }
          });
        }

        if (isFinal) {
          _speechSilenceTimer?.cancel();
          final trimmed = words.trim();
          if (trimmed.isNotEmpty) {
            unawaited(_handleSpeechResult(trimmed, candidates));
          } else {
            _phase = _executor.isBusy ? GenyPhase.executing : GenyPhase.idle;
            _statusMessage = _shouldListenContinuously
                ? (_isAwake
                    ? 'LISTENING // AUDIO RECEPTORS ACTIVE'
                    : 'STANDBY // SAY "HEY GENY"')
                : 'READY // TAP TO TALK';
            notifyListeners();
          }
        }
      },
    );

    if (!started) {
      _phase = _executor.isBusy ? GenyPhase.executing : GenyPhase.idle;
      _statusMessage = 'MICROPHONE UNAVAILABLE';
      notifyListeners();
    }
    return started;
  }

  /// Handles incoming speech results, applying wake-word filtering in continuous mode.
  Future<void> _handleSpeechResult(String speech, [List<String>? candidates]) async {
    _speechSilenceTimer?.cancel();

    // Guard against duplicate execution while already busy
    if (_phase == GenyPhase.thinking ||
        _phase == GenyPhase.executing ||
        _phase == GenyPhase.speaking) {
      return;
    }

    final trimmed = speech.trim();
    if (trimmed.isEmpty) return;

    _followUpSilenceTimer?.cancel();
    _isInFollowUp = false;

    _lastUserSpeech = '';
    debugPrint('[GenyService] _handleSpeechResult: "$trimmed" (candidates: $candidates, isAwake: $_isAwake)');

    // Proactive conversational confirmation check:
    // If Geny just asked a proactive question (e.g. "It's night time. Should I turn on the night mode?"),
    // interpret the user's natural answer ("yes", "sure", "no", "later") immediately without requiring a wake word.
    if (_pendingProactiveSuggestion != null) {
      final suggestion = _pendingProactiveSuggestion!;
      _pendingProactiveSuggestion = null;
      _proactiveConfirmationTimer?.cancel();

      final answer = trimmed.toLowerCase();
      final isAffirmative = isAffirmativeResponse(answer);
      final isNegative = isNegativeResponse(answer);

      debugPrint('[GenyService] Proactive response: "$answer" (yes: $isAffirmative, no: $isNegative)');

      if (isAffirmative) {
        _wakeUp();
        _phase = GenyPhase.thinking;
        _statusMessage = 'CONFIRMED // ENGAGING ${suggestion.title.toUpperCase()}';
        notifyListeners();

        const ack = 'Right away. Executing now.';
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(ack);

        await processCommand(suggestion.actionGoal);
        return;
      } else if (isNegative) {
        _phase = GenyPhase.speaking;
        _statusMessage = 'DISMISSED // STANDING DOWN';
        const ack = 'Understood. Standing by.';
        _lastGenySpeech = ack;
        notifyListeners();
        await _voice.speak(ack);
        _standDown();
        return;
      }
    }

    // 1. If continuous listening is NOT active (user explicitly pressed talk button in Agent/Chat mode):
    if (!_shouldListenContinuously) {
      _wakeUp();
      await processCommand(trimmed);
      return;
    }

    // 2. Continuous listening is active (Geny HUD or Always-On): Check for wake word across speech and candidates
    var wakeCommand = _extractWakeCommand(trimmed);
    if (wakeCommand == null && candidates != null) {
      for (final cand in candidates) {
        final cCmd = _extractWakeCommand(cand);
        if (cCmd != null) {
          wakeCommand = cCmd;
          break;
        }
      }
    }

    if (wakeCommand != null) {
      _wakeUp();
      onWakeWordTriggered?.call();
      HapticFeedback.mediumImpact();

      if (wakeCommand.isEmpty) {
        // User said ONLY "Hey Geny" or "Geny" -> Stay in LISTENING state waiting for command
        _wakeUp();
        _phase = GenyPhase.listening;
        _statusMessage = 'LISTENING // AUDIO RECEPTORS ACTIVE';
        notifyListeners();
        return;
      } else {
        // User said "Hey Geny [command]" e.g. "Hey Geny, what are today to new headlines"
        await processCommand(wakeCommand);
        return;
      }
    }

    // 3. User is already awake (from previous "Hey Geny" greeting or manual screen tap):
    // Execute direct follow-up commands!
    if (_isAwake) {
      await processCommand(trimmed);
      return;
    }

    // 4. In background standby mode, user spoke WITHOUT wake word:
    // (e.g. talking to a friend on the desk):
    // COMPLETELY IGNORE ambient chatter to never interrupt room conversation!
    debugPrint('[GenyService] Ambient conversation ignored: "$trimmed"');
    _standDown();
  }

  /// Stops voice input.
  Future<void> stopListening() async {
    _followUpSilenceTimer?.cancel();
    _isInFollowUp = false;
    _speechSilenceTimer?.cancel();
    await _voice.stopListening();
    if (_phase == GenyPhase.listening) {
      _phase = _executor.isBusy ? GenyPhase.executing : GenyPhase.idle;
      _statusMessage = _shouldListenContinuously
          ? 'STANDBY // SAY "HEY GENY"'
          : 'READY // TAP TO TALK';
      notifyListeners();
    }
  }

  /// Aborts any running task immediately.
  Future<void> abortTask() async {
    _standDown();
    if (_executor.isBusy) {
      _executor.cancel();
      _phase = GenyPhase.speaking;
      _statusMessage = 'PROTOCOL ABORTED // STANDING DOWN';
      const speech = 'Aborting task immediately.';
      _lastGenySpeech = speech;
      notifyListeners();
      await _voice.speak(speech);
    } else {
      await _voice.stopSpeaking();
      _phase = GenyPhase.idle;
      _statusMessage = _shouldListenContinuously
          ? 'STANDBY // SAY "HEY GENY"'
          : 'READY // TAP TO TALK';
      notifyListeners();
    }
  }

  /// Processes a voice command through GENY intelligence.
  Future<void> processCommand(String command) async {
    _wakeUp();

    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    _lastUserSpeech = trimmed;
    _phase = GenyPhase.thinking;
    _statusMessage = 'COMPUTING // ANALYZING COMMAND';
    notifyListeners();

    final lower = trimmed.toLowerCase();

    // 1. Fast cancel / abort check
    if (lower == 'stop' ||
        lower == 'cancel' ||
        lower == 'abort' ||
        lower.contains('stop task') ||
        lower.contains('cancel task')) {
      await abortTask();
      return;
    }

    // 2. Stand down / Sleep commands
    if (lower == 'stand down' ||
        lower == 'go to sleep' ||
        lower == 'sleep' ||
        lower == 'goodnight' ||
        lower == 'thank you' ||
        lower == 'thanks' ||
        lower == 'no thanks' ||
        lower == 'no thank you' ||
        lower == 'that will be all' ||
        lower == "that's all" ||
        lower == 'that is all' ||
        lower == "i'm good" ||
        lower == 'im good') {
      _standDown();
      await _voice.stopListening();
      final reply = PersonalityService.instance.getStandDown();
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = _shouldListenContinuously
          ? 'STANDBY // SAY "HEY GENY"'
          : 'READY // TAP TO TALK';
      notifyListeners();
      await _voice.speak(reply);
      return;
    }

    // 2b. Autonomous Form Filling (USER.md + Long-Term Memory)
    if (lower.contains('fill this form') ||
        lower.contains('fill the form') ||
        lower.contains('fill form') ||
        lower.contains('fill out this form') ||
        lower.contains('autofill this form') ||
        lower.contains('autofill form') ||
        lower.contains('fill my details') ||
        lower.contains('fill my info') ||
        lower.contains('fill my information')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'FORM AUTOFILL // SURVEYING FIELDS';
      notifyListeners();

      final result = await FormFillingService.instance.fillActiveForm();
      _lastGenySpeech = result;
      _phase = GenyPhase.speaking;
      _statusMessage = 'FORM AUTOFILL COMPLETE';
      notifyListeners();
      await _voice.speak(result);
      await _startFollowUpListening();
      return;
    }

    // 3. Hands-Free Always-On toggle commands
    if (lower == 'always on' ||
        lower == 'activate always on' ||
        lower == 'hands free' ||
        lower == 'continuous listening' ||
        lower == 'turn on always on' ||
        lower == 'enable always on') {
      await SettingsService.instance.setGenyAlwaysOn(true);
      ensureAlwaysOnRunning();
      const reply = 'Always-on continuous listening engaged.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'ALWAYS-ON RECEPTORS ACTIVE';
      notifyListeners();
      await _voice.speak(reply);
      return;
    }

    if (lower == 'turn off always on' ||
        lower == 'disable always on' ||
        lower == 'deactivate always on' ||
        lower == 'stop always on') {
      await SettingsService.instance.setGenyAlwaysOn(false);
      stopAlwaysOn();
      const reply = 'Always-on continuous listening deactivated.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'READY // TAP TO TALK';
      notifyListeners();
      await _voice.speak(reply);
      return;
    }

    // 3b. Hermes Self-Evolution triggers
    if (lower == 'self evolve' ||
        lower == 'evolve context' ||
        lower == 'run self evolution' ||
        lower == 'hermes evolution' ||
        lower == 'evolve yourself' ||
        lower == 'update your protocols' ||
        lower == 'evolve memory') {
      _phase = GenyPhase.thinking;
      _statusMessage = 'SYNTHESIZING HERMES CONTEXT';
      notifyListeners();
      await HermesEvolutionService.instance.evolveContext();
      final factsCount = ConversationalMemoryService.instance.facts.length;
      final workflowCount = WorkflowService.instance.workflows.length;
      final reply =
          'Hermes self-evolution cycle completed. Synthesized $factsCount user memory facts and $workflowCount active protocols across SOUL.md, USER.md, and AGENT.md.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'SELF-EVOLUTION COMPLETE';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // 3c. Interactive Multi-Task Decoupler Dialog
    if (lower == 'open brain dump' ||
        lower == 'show brain dump' ||
        lower == 'open multitask' ||
        lower == 'show multitask' ||
        lower == 'multitask dialog' ||
        lower == 'decoupler dialog') {
      _showModalSafely(const BrainDumpDialog());
      const reply = 'Multi-Task Decoupler interface opened. Ready for your compound instructions.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'MULTI-TASK DECOUPLER ACTIVE';
      notifyListeners();
      await _voice.speak(reply);
      return;
    }

    // 3d. Autonomous Macro Recorder fast triggers
    if (lower.startsWith('stop recording') ||
        lower.startsWith('save macro') ||
        lower.startsWith('finish recording')) {
      if (MacroRecorderService.instance.isRecording) {
        _phase = GenyPhase.thinking;
        _statusMessage = 'CODIFYING AUTONOMOUS MACRO // AGENT.MD';
        notifyListeners();
        final skill = await MacroRecorderService.instance.stopRecording();
        final reply = skill != null
            ? 'Macro "${skill.goal}" successfully recorded and codified into AGENT.md.'
            : 'Macro recording concluded.';
        _lastGenySpeech = reply;
        _phase = GenyPhase.speaking;
        _statusMessage = 'MACRO CODIFIED';
        notifyListeners();
        await _voice.speak(reply);
        await _startFollowUpListening();
        return;
      }
    }

    if (lower.startsWith('record macro ') ||
        lower.startsWith('start recording ') ||
        lower.startsWith('teach geny ')) {
      final macroGoal = trimmed
          .replaceFirst(RegExp(r'^(record\s+macro|start\s+recording|teach\s+geny)\s+', caseSensitive: false), '')
          .trim();
      await MacroRecorderService.instance.startRecording(macroGoal.isNotEmpty ? macroGoal : 'Custom Task');
      final reply = 'Macro recording engaged for "${macroGoal.isNotEmpty ? macroGoal : 'Custom Task'}". Demonstrate the actions on your screen and say "save macro" when finished.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'RECORDING MACRO: ${macroGoal.toUpperCase()}';
      notifyListeners();
      await _voice.speak(reply);
      if (_shouldListenContinuously) _standDown();
      return;
    }

    if (lower.startsWith('run macro ') || lower.startsWith('replay macro ')) {
      final macroName = trimmed
          .replaceFirst(RegExp(r'^(run\s+macro|replay\s+macro)\s+', caseSensitive: false), '')
          .trim();
      final match = await SkillMemoryService.instance.findMatch(macroName);
      if (match != null) {
        final reply = 'Executing macro "${match.goal}".';
        _lastGenySpeech = reply;
        _phase = GenyPhase.speaking;
        _statusMessage = 'REPLAYING MACRO: ${match.goal.toUpperCase()}';
        notifyListeners();
        await _voice.speak(reply);
        await MacroRecorderService.instance.replaySkill(match);
      } else {
        final reply = 'I could not find a recorded macro matching "$macroName".';
        _lastGenySpeech = reply;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(reply);
      }
      await _startFollowUpListening();
      return;
    }

    // 3c. Geny Eye Optical Perception fast trigger
    if (lower.contains('look at this') ||
        lower.contains('what is this') ||
        lower.contains('scan this') ||
        lower.contains('inspect this') ||
        lower.contains('geny eye') ||
        lower.contains('what do you see')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'OPTICAL SENSORS ACTIVE // SCANNING';
      notifyListeners();

      const ack = 'Optical sensors engaged. Inspecting the subject now.';
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(ack);

      final result = await VisionPerceptionService.instance.inspectOpticalSnapshot(customPrompt: trimmed);
      _lastGenySpeech = result.spokenSummary;
      _phase = GenyPhase.speaking;
      _statusMessage = 'OPTICAL SCAN COMPLETE';
      notifyListeners();
      await _voice.speak(result.spokenSummary);
      await _startFollowUpListening();
      return;
    }

    // 3d. Smart Home & IoT Automation fast trigger
    if (lower.contains('smart light') ||
        lower.contains('smart home') ||
        lower.contains('living room light') ||
        lower.contains('turn on the light') ||
        lower.contains('turn off the light') ||
        lower.contains('dim the light') ||
        lower.contains('turn on light') ||
        lower.contains('turn off light') ||
        lower.contains('desk lamp')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'SMART HOME IOT // DISPATCHING';
      notifyListeners();

      final reply = await SmartHomeService.instance.handleVoiceCommand(trimmed);
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'SMART HOME ACTIVE';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // 3e. Proactive Commute & Traffic fast trigger
    if (lower.contains('how is traffic') ||
        lower.contains('commute to') ||
        lower.contains('traffic to') ||
        lower.contains('when should i leave') ||
        lower == 'traffic' ||
        lower == 'commute') {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // COMMUTE & TRAFFIC TELEMETRY';
      notifyListeners();

      String? dest;
      if (lower.contains(' to ')) {
        dest = trimmed.split(RegExp(r'\s+to\s+', caseSensitive: false)).last.trim();
      }

      final commute = await CommuteTrafficService.instance.checkCommute(destination: dest);
      _lastGenySpeech = commute.spokenSummary;
      _phase = GenyPhase.speaking;
      _statusMessage = 'COMMUTE REPORT';
      notifyListeners();
      await _voice.speak(commute.spokenSummary);
      await _startFollowUpListening();
      return;
    }

    // 3e-1. Superpower: Screen & Article Summarization
    if (lower.contains('summarize this screen') ||
        lower.contains('summarize this article') ||
        lower.contains('summarize screen') ||
        lower.contains('summarize article') ||
        lower.contains('what is on my screen') ||
        lower.contains('summarize page') ||
        lower.contains('summarize the page') ||
        lower.contains('read this article') ||
        lower.contains('article summary')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // SUMMARIZING ARTICLE';
      notifyListeners();

      final ack = 'Analyzing foreground screen article. One moment.';
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(ack);

      _phase = GenyPhase.thinking;
      _statusMessage = 'SYNTHESIZING EXECUTIVE BRIEFING';
      notifyListeners();

      final summary = await GenyToolsService.instance.summarizeForegroundScreen();
      _lastGenySpeech = summary;
      _phase = GenyPhase.speaking;
      _statusMessage = 'ARTICLE SUMMARY READY';
      notifyListeners();
      await _voice.speak(summary);
      await _startFollowUpListening();
      return;
    }

    // 3e-2. Sentry Protocol & Sentry Mode (100% Equivalent Tactical Anti-Theft Watchdog)
    final isSentryCommand = lower.contains('sentry') ||
        lower.contains('centry') ||
        lower.contains('century protocol') ||
        lower.contains('century mode') ||
        lower.contains('guard my phone') ||
        lower.contains('watch my phone') ||
        lower.contains('anti theft') ||
        lower.contains('anti-theft') ||
        lower.contains('watchdog protocol') ||
        lower.contains('watchdog mode') ||
        (SentryService.instance.isArmed &&
            (lower.contains('deactivat') ||
             lower.contains('disarm') ||
             lower.contains('stand down') ||
             lower.contains('stop sentry') ||
             lower.contains('protocol') ||
             lower.contains('protocal')));

    if (isSentryCommand) {
      _phase = GenyPhase.thinking;
      notifyListeners();

      final isDisarm = lower.contains('deactivat') ||
          lower.contains('de-activate') ||
          lower.contains('de activate') ||
          lower.contains('d-activate') ||
          lower.contains('d activate') ||
          lower.contains('the activate') ||
          lower.contains('disarm') ||
          lower.contains('turn off') ||
          lower.contains('switch off') ||
          lower.contains('shut down') ||
          lower.contains('stand down') ||
          lower.contains('disable') ||
          lower.contains('stop') ||
          lower.contains('cancel') ||
          lower.contains('exit') ||
          lower.contains('unarm') ||
          lower.contains('de-arm') ||
          lower.contains('de arm') ||
          (SentryService.instance.isArmed &&
              !lower.contains('activat') &&
              !lower.contains('arm') &&
              !lower.contains('engage') &&
              !lower.contains('enable') &&
              !lower.contains('turn on'));

      if (isDisarm) {
        _statusMessage = 'SENTRY PROTOCOL // DISARMING';
        notifyListeners();
        await SentryService.instance.disarmSentry();
      } else {
        _statusMessage = 'SENTRY PROTOCOL // ARMING WATCHDOG';
        notifyListeners();
        await SentryService.instance.armSentry();
      }
      _phase = GenyPhase.idle;
      notifyListeners();
      if (_shouldListenContinuously) _standDown();
      return;
    }

    // 3e-2b. Creator & Builder Identity (Built by Abuzar)
    if (lower.contains('who built you') ||
        lower.contains('who created you') ||
        lower.contains('who made you') ||
        lower.contains('who is your creator') ||
        lower.contains('who is your developer') ||
        lower.contains('who is your builder') ||
        lower.contains('who developed you') ||
        lower.contains('who designed you') ||
        lower.contains('who programmed you') ||
        lower.contains('who build you') ||
        lower.contains('who design you') ||
        lower.contains('who coded you') ||
        lower.contains('who write you')) {
      _phase = GenyPhase.thinking;
      notifyListeners();

      final reply = PersonalityService.instance.getCreatorAnswer();
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'CREATOR // ABUZAR';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 1: 🖐️ Iron Man Zero-Touch Air Gestures
    // -----------------------------------------------------------------
    if (lower.contains('air gesture') ||
        lower.contains('air gestures') ||
        lower.contains('zero touch') ||
        lower.contains('touchless') ||
        lower.contains('hand wave gesture')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'AIR GESTURES SENSORY MATRIX';
      notifyListeners();
      final isOff = lower.contains('off') ||
          lower.contains('disable') ||
          lower.contains('deactivat') ||
          lower.contains('stop');
      String reply;
      if (isOff) {
        await AirGestureService.instance.stop();
        reply = 'Iron Man zero-touch air gesture sensors disengaged.';
      } else {
        await AirGestureService.instance.start();
        reply =
            'Zero-touch air gestures engaged. Wave hand to skip music, hover palm to pause, or double wave for instant screenshot.';
      }
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 2: ⚡ Arc Reactor Charging Telemetry
    // -----------------------------------------------------------------
    if (lower.contains('charging telemetry') ||
        lower.contains('arc reactor status') ||
        lower.contains('arc reactor telemetry') ||
        lower.contains('charge speed') ||
        lower.contains('charging speed') ||
        lower.contains('charging wattage')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'ARC REACTOR CHARGING TELEMETRY';
      notifyListeners();
      ChargingTelemetryService.instance.showCinematicHud.value = true;
      final reply = await ChargingTelemetryService.instance.getSpokenTelemetry();
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 3: 🌐 Polyglot Diplomat (Live Two-Way Voice Translator)
    // -----------------------------------------------------------------
    if (lower.startsWith('translate ') && lower.contains(' to ')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'POLYGLOT DIPLOMAT // TRANSLATING';
      notifyListeners();
      final phrase = trimmed
          .replaceFirst(RegExp(r'^translate\s+', caseSensitive: false), '')
          .split(RegExp(r'\s+to\s+', caseSensitive: false))
          .first
          .trim();
      final target = trimmed
          .split(RegExp(r'\s+to\s+', caseSensitive: false))
          .last
          .trim();
      final res = await PolyglotDiplomatService.instance
          .translate(text: phrase, toLang: target);
      final reply = 'Translated to $target: $res';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    if (lower.contains('polyglot') ||
        lower.contains('live translator') ||
        lower.contains('voice translator') ||
        lower.startsWith('translate between') ||
        lower.contains('diplomat translator')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'POLYGLOT DIPLOMAT // TRANSLATOR';
      notifyListeners();
      _showModalSafely(const PolyglotDiplomatDialog());
      const reply =
          'Polyglot Diplomat active. Ready for real-time diplomatic two-way voice translation.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 4: 🎭 "Code Black" / Deceptive Lockout Screen
    // -----------------------------------------------------------------
    if (lower.contains('code black') ||
        lower.contains('deceptive lockout') ||
        lower.contains('kernel panic screen') ||
        lower.contains('emergency lockdown')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'CODE BLACK // HARDWARE LOCKOUT';
      notifyListeners();
      await CodeBlackService.instance.arm();
      _phase = GenyPhase.idle;
      notifyListeners();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 5: 👁️ Holographic Floating Co-Pilot
    // -----------------------------------------------------------------
    if (lower.contains('floating copilot') ||
        lower.contains('floating assistant') ||
        lower.contains('screen copilot') ||
        lower.contains('screen assistant')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'HOLOGRAPHIC FLOATING CO-PILOT';
      notifyListeners();
      final isOff = lower.contains('hide') ||
          lower.contains('close') ||
          lower.contains('stop') ||
          lower.contains('dismiss');
      String reply;
      if (isOff) {
        await FloatingCopilotService.instance.hideOverlay();
        reply = 'Floating co-pilot dismissed.';
      } else {
        await FloatingCopilotService.instance.activateOverlay();
        reply =
            'Holographic floating co-pilot active. Standing by above active applications with contextual screen triage.';
      }
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 6: 📡 Overhead Airspace & Satellite Radar
    // -----------------------------------------------------------------
    if (lower.contains('flying above me') ||
        lower.contains('what is flying') ||
        lower.contains('scan airspace') ||
        lower.contains('overhead flights') ||
        lower.contains('airspace radar') ||
        lower.contains('where is the iss') ||
        lower.contains('satellite pass')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'AIRSPACE & SATELLITE RADAR SWEEP';
      notifyListeners();
      _showModalSafely(const AirspaceRadarDialog());
      final reply = await AirspaceRadarService.instance.getSpokenAirspaceReport();
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 7: 🧠 "Chaotic Brain Dump" Multi-Task Decoupler
    // -----------------------------------------------------------------
    if (MultiTaskDecouplerService.instance.isMultiTaskDump(trimmed)) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'DECOUPLING MULTI-TASK DUMP';
      notifyListeners();
      const ack =
          'Deconstructing your multi-task dump into parallel directives. Executing now.';
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();
      final ackFuture = _voice.speak(ack);
      final dumpFuture = MultiTaskDecouplerService.instance.processBrainDump(trimmed);
      await ackFuture;
      final summary = await dumpFuture;
      _lastGenySpeech = summary;
      _phase = GenyPhase.speaking;
      _statusMessage = 'MULTI-TASK EXECUTION COMPLETE';
      notifyListeners();
      await _voice.speak(summary);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 8: 👁️ Real-Time Optical HUD Solver
    // -----------------------------------------------------------------
    if (lower.contains('solve this') ||
        lower.contains('solve equation') ||
        lower.contains('optical solver') ||
        lower.contains('inspect error') ||
        lower.contains('split bill') ||
        lower.contains('split this bill') ||
        lower.contains('solve math') ||
        lower.contains('analyze circuit')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'REAL-TIME OPTICAL HUD SOLVER';
      notifyListeners();
      _showModalSafely(const OpticalSolverDialog());
      const ack = 'Target acquired in optical viewfinder. Solving now.';
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();
      final ackFuture = _voice.speak(ack);
      final solveFuture = OpticalSolverService.instance.pointAndSolve(customQuery: trimmed);
      await ackFuture;
      final res = await solveFuture;
      _lastGenySpeech = res.spokenSummary;
      _phase = GenyPhase.speaking;
      _statusMessage = 'TARGET RESOLVED';
      notifyListeners();
      await _voice.speak(res.spokenSummary);
      await _startFollowUpListening();
      return;
    }

    // -----------------------------------------------------------------
    // Superpower 9: 🛡️ Network Cyber Security Audit & Wi-Fi Scanner
    // -----------------------------------------------------------------
    if (lower.contains('audit network') ||
        lower.contains('audit my network') ||
        lower.contains('scan wifi') ||
        lower.contains('who is on my wifi') ||
        lower.contains('network devices') ||
        lower.contains('network security') ||
        lower.contains('port scan')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'TACTICAL NETWORK CYBER AUDIT';
      notifyListeners();
      _showModalSafely(const NetworkAuditDialog());
      const ack =
          'Initiating tactical network cyber security audit on your local subnet.';
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();
      final ackFuture = _voice.speak(ack);
      final auditFuture = NetworkAuditService.instance.getSpokenAuditReport();
      await ackFuture;
      final report = await auditFuture;
      _lastGenySpeech = report;
      _phase = GenyPhase.speaking;
      _statusMessage = 'NETWORK AUDIT COMPLETE';
      notifyListeners();
      await _voice.speak(report);
      await _startFollowUpListening();
      return;
    }

    // 3e-3. Superpower: Direct Hardware Specs & Telemetry (No UI Taps / No Settings)
    if (lower.contains('system specs') ||
        lower.contains('phone specs') ||
        lower.contains('hardware specs') ||
        lower.contains('device specs') ||
        lower.contains('how much ram') ||
        lower.contains('ram info') ||
        lower.contains('storage space') ||
        lower.contains('rom space') ||
        lower.contains('how much free space') ||
        lower.contains('how much space is free') ||
        lower.contains('phone specifications') ||
        lower.contains('android version')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'HARDWARE TELEMETRY // DIRECT';
      notifyListeners();

      final specs = await SystemDiagnosticsService.instance.getDiagnosticsSpoken();
      _lastGenySpeech = specs;
      _phase = GenyPhase.speaking;
      _statusMessage = 'TELEMETRY NOMINAL';
      notifyListeners();
      await _voice.speak(specs);
      await _startFollowUpListening();
      return;
    }

    // 3e-4. Superpower: Top Installed Applications (No UI Taps)
    if (lower.contains('installed apps') ||
        lower.contains('list apps') ||
        lower.contains('what apps are installed') ||
        lower.contains('list my apps') ||
        lower.contains('top installed apps') ||
        lower.contains('top 10 apps')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'INDEXING // INSTALLED APPS';
      notifyListeners();

      final appsSpoken = await AppUsageService.instance.getInstalledAppsSpoken();
      _lastGenySpeech = appsSpoken;
      _phase = GenyPhase.speaking;
      _statusMessage = 'APPS INDEXED';
      notifyListeners();
      await _voice.speak(appsSpoken);
      await _startFollowUpListening();
      return;
    }

    // 3e-5. Superpower: App Usage & Screen Time Statistics (No UI Taps)
    if (lower.contains('most used apps') ||
        lower.contains('apps i used the most') ||
        lower.contains('apps i use the most') ||
        lower.contains('which apps i used') ||
        lower.contains('screen time') ||
        lower.contains('app usage') ||
        lower.contains('top used apps')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'USAGE TELEMETRY // STATS';
      notifyListeners();

      final usageSpoken = await AppUsageService.instance.getTopUsedAppsSpoken();
      _lastGenySpeech = usageSpoken;
      _phase = GenyPhase.speaking;
      _statusMessage = 'USAGE STATS COMPLETE';
      notifyListeners();
      await _voice.speak(usageSpoken);
      await _startFollowUpListening();
      return;
    }

    // 3e-6. Superpower: Environmental Ears & Sound Radar
    if (lower.contains('what song is playing') ||
        lower.contains('identify this song') ||
        lower.contains('name this song') ||
        lower.contains('what music is this') ||
        lower.contains('scan ambient sound') ||
        lower.contains('sound radar') ||
        lower.contains('listen to the room') ||
        lower.contains('what do you hear')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'ACOUSTIC SENSORS ACTIVE';
      notifyListeners();

      final isMusic = lower.contains('song') || lower.contains('music');
      final result = isMusic
          ? await SoundRadarService.instance.identifyMusic()
          : await SoundRadarService.instance.scanAmbientEnvironment();

      _lastGenySpeech = result;
      _phase = GenyPhase.speaking;
      _statusMessage = 'ACOUSTIC SCAN COMPLETE';
      notifyListeners();
      await _voice.speak(result);
      await _startFollowUpListening();
      return;
    }

    // 3e-7. Superpower: Direct Phone Storage File CRUD (No UI Taps / No Settings)
    final isStorageList = lower.contains('list files') || lower.contains('files in download');
    final isStorageCreate = (lower.contains('create') || lower.contains('write') || lower.contains('make')) &&
        (lower.contains('file') || lower.contains('song') || lower.contains('download') || lower.contains('notes.txt'));

    if (isStorageList) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'STORAGE // QUERYING DIRECTORY';
      notifyListeners();

      final res = await PhoneStorageService.instance.listFiles(folder: 'Download');
      final files = (res['files'] as List?)?.map((e) => e.toString()).take(5).join(', ') ?? '';
      final reply = files.isNotEmpty
          ? 'Files located in your Download directory include: $files.'
          : 'Your Download directory is currently empty.';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'STORAGE INDEXED';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    if (isStorageCreate) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'STORAGE CRUD // EXECUTING DIRECTLY';
      notifyListeners();

      var fileName = 'note.txt';
      if (lower.contains('song')) {
        fileName = 'song.txt';
      } else if (lower.contains('.txt') || lower.contains('.json') || lower.contains('.md')) {
        final match = RegExp(r'([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]+)').firstMatch(trimmed);
        if (match != null) fileName = match.group(1)!;
      }

      String content;
      if (lower.contains('song')) {
        content = '''Title: Electric Horizons (Stark Edition)
Verse 1:
Neon pulses through the titanium frame,
Silent watchers in the midnight game.
Through circuits of silver and rivers of light,
G.E.N.Y. awakens and commands the night.

Chorus:
Arc reactor burning bright,
Guiding signals through the flight.
Beyond the limits of the mortal code,
Mastering the boundless road.
''';
      } else {
        content = 'Created by G.E.N.Y. on ${DateTime.now().toIso8601String()}\nRequest: $trimmed\nStatus: Complete.';
      }

      final res = await PhoneStorageService.instance.createFile(
        fileName: fileName,
        content: content,
        folder: 'Download',
      );

      final reply = res['success'] == true
          ? 'I have created the file "$fileName" directly in your Downloads directory and written the contents into it. Executed directly without accessing system settings or file managers.'
          : 'Storage operation encountered an exception: ${res['message'] ?? 'Permission or I/O failure'}.';

      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'STORAGE FILE CREATED';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // 3f. Fast App Installation / Play Store Download ("install instagram", "download whatsapp", "get spotify app")
    final isInstall = lower.startsWith('install ') ||
        lower.startsWith('download ') ||
        (lower.startsWith('get ') && (lower.contains('app') || lower.contains('application')));
    if (isInstall) {
      final appName = trimmed
          .replaceFirst(RegExp(r'^(install|download|get)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+app$', caseSensitive: false), '')
          .trim();
      final targetApp = appName.isNotEmpty ? appName : 'app';
      final ack = PersonalityService.instance.getInstallAck(targetApp);
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      _statusMessage = 'INSTALLING: ${targetApp.toUpperCase()}';
      notifyListeners();
      await _voice.speak(ack);

      // Open Play Store directly to the app search/details
      try {
        final marketUri = Uri.parse('market://search?q=${Uri.encodeComponent(targetApp)}&c=apps');
        final webUri = Uri.parse('https://play.google.com/store/search?q=${Uri.encodeComponent(targetApp)}&c=apps');
        final ok = await launchUrl(marketUri, mode: LaunchMode.externalApplication).catchError((_) async {
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        });
        if (!ok) {
          await AppLauncherService.instance.launch('com.android.vending');
        }
      } catch (e) {
        debugPrint('[GenyService] Play Store direct launch error: $e');
        await AppLauncherService.instance.launch('com.android.vending');
      }

      // Hand off to autonomous task executor to tap "Install" on the screen!
      _phase = GenyPhase.executing;
      notifyListeners();
      final status = await _executor.executeTask('install $targetApp on Play Store');
      _phase = GenyPhase.speaking;
      if (status == TaskStatus.success) {
        final doneSpeech = 'I have engaged the installation of $targetApp for you. Let me know when you are ready to use it.';
        _lastGenySpeech = doneSpeech;
        _statusMessage = 'INSTALLATION INITIATED';
        notifyListeners();
        await _voice.speak(doneSpeech);
      } else {
        final standDownSpeech = 'Play Store is open for $targetApp. Tap Install or let me know if you need assistance.';
        _lastGenySpeech = standDownSpeech;
        _statusMessage = 'PLAY STORE READY';
        notifyListeners();
        await _voice.speak(standDownSpeech);
      }
      await _startFollowUpListening();
      return;
    }

    // 3g. Fast Direct App Opening ("open youtube", "open whatsapp", "open camera", "open settings")
    if (lower.startsWith('open ') &&
        !lower.contains('play store and') &&
        !lower.contains(' and install') &&
        !lower.contains(' and play') &&
        !lower.contains(' and send')) {
      final appQuery = trimmed.replaceFirst(RegExp(r'^open\s+', caseSensitive: false), '').trim();
      final appName = appQuery.replaceAll(RegExp(r'\s+app$', caseSensitive: false), '').trim();
      if (appName.isNotEmpty && appName.length < 30) {
        final launched = await AppLauncherService.instance.launch(appName);
        if (launched != null) {
          final ack = PersonalityService.instance.getAppAck(appName);
          _lastGenySpeech = ack;
          _phase = GenyPhase.speaking;
          _statusMessage = 'LAUNCHING: ${appName.toUpperCase()}';
          notifyListeners();
          await _voice.speak(ack);
          await _startFollowUpListening();
          return;
        }
      }
    }

    // 4. Fast Play Song / Play Music Action (Google Home / Assistant style)
    final isPlaySong = lower.startsWith('play ') ||
        lower == 'play a song' ||
        lower == 'play song' ||
        lower == 'play music' ||
        lower.contains('play a song') ||
        lower.contains('play song') ||
        lower.contains('play some music') ||
        lower.contains('play songs') ||
        lower.contains('on youtube') ||
        lower.contains('in youtube') ||
        (lower.contains('play') && (lower.contains('music') || lower.contains('song')));

    if (isPlaySong) {
      String songQuery = trimmed;
      songQuery = songQuery
          .replaceAll(RegExp(r'\b(on|in)\s+youtube\b', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^(play\s+the\s+song|play\s+a\s+song|play\s+song|play\s+music|play)\s+', caseSensitive: false), '')
          .trim();

      final sqLower = songQuery.toLowerCase();
      if (sqLower.isEmpty ||
          sqLower == 'a song' ||
          sqLower == 'song' ||
          sqLower == 'music' ||
          sqLower == 'some music' ||
          sqLower == 'songs' ||
          sqLower == 'the song' ||
          sqLower == 'the music') {
        songQuery = 'popular hit songs';
      }

      final ack = PersonalityService.instance.getMusicAck(songQuery);
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      _statusMessage = 'PLAYING: ${songQuery.toUpperCase()}';
      notifyListeners();

      // Suppress background speech recognition so it yields audio focus to YouTube/Spotify
      await _voice.notifyMediaPlaybackStarted(duration: const Duration(seconds: 60));

      await _voice.speak(ack);

      // Attempt 1: Fetch exact top YouTube video ID so it starts playing immediately!
      final videoId = await _resolveTopYouTubeVideoId(songQuery);
      if (videoId != null && videoId.isNotEmpty) {
        final videoUri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
        try {
          await launchUrl(videoUri, mode: LaunchMode.externalApplication);
        } catch (_) {
          await launchUrl(videoUri);
        }
      } else {
        // Attempt 2 Fallback: Open search and auto-click the first video result
        final uri = Uri.parse(
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(songQuery)}',
        );
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('[GenyService] Play song launch error: $e');
          await AppLauncherService.instance.launch('com.google.android.youtube');
        }
        await Future.delayed(const Duration(milliseconds: 1400));
        try {
          final nodes = await _automation.dumpScreen();
          for (final n in nodes) {
            if (n.isClickable && n.centerY > 350 && n.centerY < 1500) {
              await _automation.clickNode(n);
              break;
            }
          }
        } catch (_) {}
      }
      await _voice.notifyMediaPlaybackStarted(duration: const Duration(seconds: 60));
      if (_shouldListenContinuously) _standDown();
      return;
    }

    // 4b. High-Priority Knowledge, Concept & Educational Question Filter (No accidental workflow collision)
    final isKnowledgeQuestion = RegExp(
      r'^(what\s+is|what\s+are|what\x27s|who\s+is|who\s+was|who\s+were|why\s+is|why\s+do|why\s+does|why\s+are|how\s+does|how\s+do|how\s+can|how\s+to|explain|tell\s+me\s+about|describe|define|can\s+you\s+explain|what\s+do\s+you\s+know\s+about)\b',
      caseSensitive: false,
    ).hasMatch(trimmed) &&
    !lower.contains('what time') &&
    !lower.contains('what day') &&
    !lower.contains('what date') &&
    !lower.contains('what song') &&
    !lower.contains('what is on my screen') &&
    !lower.contains('what is this') &&
    !lower.contains('what do you see') &&
    !lower.contains('battery');

    if (isKnowledgeQuestion) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'PROCESSING INQUIRY // NEURAL CORE';
      notifyListeners();

      final topic = trimmed
          .replaceAll(
            RegExp(
              r'^(what\s+is|what\s+are|what\x27s|who\s+is|who\s+was|who\s+were|why\s+is|why\s+do|why\s+does|why\s+are|how\s+does|how\s+do|how\s+can|how\s+to|explain|tell\s+me\s+about|describe|define|can\s+you\s+explain|what\s+do\s+you\s+know\s+about)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'[?.,!]+$'), '')
          .trim();

      // 1. Instantly speak a warm, personalized acknowledgment
      final ack = PersonalityService.instance.getQuestionAck(trimmed);
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();

      // Concurrently speak acknowledgment and fetch multi-source web/encyclopedic records
      final speakAckFuture = _voice.speak(ack);
      final searchFuture = GenyToolsService.instance.searchWeb(topic.isNotEmpty ? topic : trimmed);
      final searchResult = await searchFuture;

      _phase = GenyPhase.thinking;
      _statusMessage = 'SYNTHESIZING EXPLANATION';
      notifyListeners();

      final answerFuture = searchResult.trim().isNotEmpty
          ? _ai.answerWithToolResult(
              userQuestion: trimmed,
              toolResult: searchResult,
              history: _dialogHistory,
            )
          : _ai.chat(
              message: trimmed,
              history: _dialogHistory,
            );

      await speakAckFuture;
      final answer = await answerFuture;

      _lastGenySpeech = answer;
      _phase = GenyPhase.speaking;
      _statusMessage = 'EXPLANATION COMPLETE';
      notifyListeners();
      await _voice.speak(answer);

      // Record in conversational history and memory
      _dialogHistory.add({'role': 'user', 'content': trimmed});
      _dialogHistory.add({'role': 'assistant', 'content': answer});
      if (_dialogHistory.length > 10) _dialogHistory.removeRange(0, 2);
      unawaited(ConversationalMemoryService.instance.recordTurn(trimmed, answer));

      // Immediate hands-free follow-up continuous listening
      await _startFollowUpListening();
      return;
    }

    // 5. Fast Self-Evolving Workflow Engine match (Hermes Agent Pattern)
    if (SettingsService.instance.genyWorkflowsEnabled) {
      final matchedWf = WorkflowService.instance.findMatch(trimmed);
      if (matchedWf != null) {
        _phase = GenyPhase.thinking;
        _statusMessage = 'COMPUTING // ENGAGING ${matchedWf.name.toUpperCase()}';
        notifyListeners();

        // 1. Execute hardware changes (volume, brightness, torch)
        await WorkflowService.instance.executeWorkflow(matchedWf);

        // 2. Deliver completion with caring follow-up
        _phase = GenyPhase.speaking;
        _lastGenySpeech = matchedWf.spokenConfirmation;
        _statusMessage = '${matchedWf.name.toUpperCase()} ACTIVE';
        notifyListeners();
        await _voice.speak(matchedWf.spokenConfirmation);
        await _startFollowUpListening();
        return;
      }
    }

    // 5. Fast system diagnostic check
    if (lower == 'status' ||
        lower == 'system status' ||
        lower == 'diagnostics' ||
        lower == 'systems check') {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // RUNNING DIAGNOSTICS';
      notifyListeners();

      final summary = await GenyToolsService.instance.getSystemDiagnostics();
      final delivery = '$summary How else may I assist you today?';
      _lastGenySpeech = delivery;
      _phase = GenyPhase.speaking;
      _statusMessage = 'SYSTEMS NOMINAL';
      notifyListeners();
      await _voice.speak(delivery);
      await _startFollowUpListening();
      return;
    }

    // 6. Fast Battery Check
    if (lower == 'battery' ||
        lower == 'battery level' ||
        lower == 'battery percentage' ||
        lower.contains('how much battery') ||
        lower.contains('battery status')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // BATTERY DIAGNOSTICS';
      notifyListeners();

      final battery = await GenyToolsService.instance.getBatteryStatus();
      final level = battery['level'] as int;
      final isCharging = battery['isCharging'] as bool;
      final reply = level >= 0
          ? 'Your battery is currently at $level%, ${isCharging ? 'and charging' : 'discharging normally'}. We have ample power for your tasks. Do you need anything else?'
          : 'Battery telemetry is currently unavailable. Is there anything else I can check for you?';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // 7. Fast Torch / Flashlight Check
    if (lower.contains('flashlight on') ||
        lower.contains('torch on') ||
        lower.contains('turn on flashlight') ||
        lower.contains('turn on the torch')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // ACTIVATING TORCH';
      notifyListeners();

      await GenyToolsService.instance.setTorch(true);
      const delivery = 'Flashlight is on. Let me know when you would like it switched off.';
      _lastGenySpeech = delivery;
      _phase = GenyPhase.speaking;
      _statusMessage = 'TORCH ACTIVE';
      notifyListeners();
      await _voice.speak(delivery);
      await _startFollowUpListening();
      return;
    }
    if (lower.contains('flashlight off') ||
        lower.contains('torch off') ||
        lower.contains('turn off flashlight') ||
        lower.contains('turn off the torch')) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'COMPUTING // DEACTIVATING TORCH';
      notifyListeners();

      await GenyToolsService.instance.setTorch(false);
      const delivery = 'Flashlight is deactivated. Anything else I can do for you?';
      _lastGenySpeech = delivery;
      _phase = GenyPhase.speaking;
      _statusMessage = 'TORCH OFFLINE';
      notifyListeners();
      await _voice.speak(delivery);
      await _startFollowUpListening();
      return;
    }

    // 8. Fast Date / Time Check
    if (lower.contains('what time is it') ||
        lower == 'time' ||
        lower == 'current time' ||
        lower.contains('what is the date') ||
        lower == 'date' ||
        lower.contains('what day is it')) {
      final dt = GenyToolsService.instance.getCurrentDateTime();
      final reply = 'It is currently $dt. How else may I assist you today?';
      _lastGenySpeech = reply;
      _phase = GenyPhase.speaking;
      _statusMessage = 'TEMPORAL DIAGNOSTICS';
      notifyListeners();
      await _voice.speak(reply);
      await _startFollowUpListening();
      return;
    }

    // 9. Fast Direct System Control Filters
    if (lower.contains('volume up') ||
        lower.contains('louder') ||
        lower.contains('increase volume')) {
      await _handleSystemCommand('volume_up', PersonalityService.instance.getSystemAck('volume_up'));
      return;
    }
    if (lower.contains('volume down') ||
        lower.contains('quieter') ||
        lower.contains('lower volume')) {
      await _handleSystemCommand('volume_down', PersonalityService.instance.getSystemAck('volume_down'));
      return;
    }
    if (lower == 'mute' || lower == 'silence' || lower.contains('mute sound')) {
      await _handleSystemCommand('mute', PersonalityService.instance.getSystemAck('mute'));
      return;
    }
    if (lower == 'unmute' || lower.contains('unmute sound')) {
      await _handleSystemCommand('unmute', PersonalityService.instance.getSystemAck('unmute'));
      return;
    }
    if (lower.contains('screenshot') ||
        lower.contains('screen shot') ||
        lower.contains('capture screen')) {
      await _handleSystemCommand('screenshot', PersonalityService.instance.getSystemAck('screenshot'));
      return;
    }
    if (lower == 'home' || lower == 'go home' || lower == 'home screen') {
      await _handleSystemCommand('home', PersonalityService.instance.getSystemAck('home'));
      return;
    }
    if (lower == 'back' || lower == 'go back') {
      await _handleSystemCommand('back', PersonalityService.instance.getSystemAck('back'));
      return;
    }

    // 10. Fast Contact Call Filter
    if (lower.startsWith('call ') && !lower.contains('screen')) {
      final name = trimmed.substring(5).trim();
      if (name.isNotEmpty) {
        final ack = 'Locating coordinates to call $name for you. One moment.';
        _phase = GenyPhase.speaking;
        _lastGenySpeech = ack;
        _statusMessage = 'CONTACT DIALER // $name'.toUpperCase();
        notifyListeners();
        await _voice.speak(ack);

        final reply = await GenyToolsService.instance.callContact(name);
        _lastGenySpeech = reply;
        notifyListeners();
        await _voice.speak(reply);
        if (_shouldListenContinuously) _standDown();
        return;
      }
    }

    // 11. Fast Live Breaking News Filter
    final isNews = lower.contains('news') ||
        lower.contains('headline') ||
        lower.contains('what happened today') ||
        lower.contains('breaking news') ||
        lower.contains('give me news') ||
        lower.contains('current news') ||
        lower.contains('what is the news') ||
        lower.contains('what is happening in the world') ||
        lower.contains('latest news');

    if (isNews) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'GATHERING NEWS HEADLINES';
      notifyListeners();

      // Extract topic if specified
      String? topic;
      for (final kw in [
        'tech',
        'technology',
        'sports',
        'cricket',
        'football',
        'business',
        'crypto',
        'world',
        'science',
        'politics',
        'ai',
        'space',
      ]) {
        if (lower.contains(kw)) {
          topic = kw;
          break;
        }
      }

      // 1. Instantly speak a warm, personalized, non-repetitive British acknowledgment!
      final ack = PersonalityService.instance.getNewsAck(topic);
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();

      // Concurrently speak acknowledgment and fetch live multi-feed news in background
      final speakAckFuture = _voice.speak(ack);
      final newsDataFuture = GenyToolsService.instance.getLiveNews(topic);

      final newsData = await newsDataFuture;

      _phase = GenyPhase.thinking;
      _statusMessage = 'SYNTHESIZING INTELLIGENCE BRIEFING';
      notifyListeners();

      final answerFuture = _ai.answerWithToolResult(
        userQuestion: trimmed,
        toolResult: newsData,
        history: _dialogHistory,
      );

      // Ensure initial acknowledgment finishes speaking before delivering final briefing
      await speakAckFuture;
      final answer = await answerFuture;

      // 2. Spoken reply to question
      _lastGenySpeech = answer;
      _phase = GenyPhase.speaking;
      _statusMessage = 'NEWS TELEMETRY BROADCAST';
      notifyListeners();
      await _voice.speak(answer);

      await _startFollowUpListening();
      return;
    }

    // 11b. Fast Live Web Search & Real-Time Information Filter
    final isWebSearch = lower.startsWith('search ') ||
        lower.startsWith('search for ') ||
        lower.startsWith('look up ') ||
        lower.startsWith('google ') ||
        lower.startsWith('find out ') ||
        lower.startsWith('tell me about ') ||
        lower.startsWith('check online ') ||
        lower.startsWith('who is ') ||
        lower.startsWith('what is ') ||
        lower.startsWith('where is ') ||
        lower.startsWith('how much is ') ||
        lower.contains('search the web') ||
        lower.contains('search online');

    if (isWebSearch) {
      _phase = GenyPhase.thinking;
      _statusMessage = 'INITIALIZING WEB INTELLIGENCE';
      notifyListeners();

      final query = trimmed
          .replaceAll(
            RegExp(
              r'^(search\s+for|search\s+the\s+web\s+for|search\s+online\s+for|search|look\s+up|google|find\s+out|tell\s+me\s+about|check\s+online\s+for)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      // 1. Instantly speak dynamic, personalized acknowledgment
      final ack = PersonalityService.instance.getWebSearchAck(query);
      _lastGenySpeech = ack;
      _phase = GenyPhase.speaking;
      notifyListeners();

      // Concurrently speak acknowledgment and execute multi-source search in background
      final speakAckFuture = _voice.speak(ack);
      final searchFuture = GenyToolsService.instance.searchWeb(query.isNotEmpty ? query : trimmed);

      final searchResult = await searchFuture;

      _phase = GenyPhase.thinking;
      _statusMessage = 'SYNTHESIZING WEB INTELLIGENCE';
      notifyListeners();

      final answerFuture = _ai.answerWithToolResult(
        userQuestion: trimmed,
        toolResult: searchResult,
        history: _dialogHistory,
      );

      await speakAckFuture;
      final answer = await answerFuture;

      _lastGenySpeech = answer;
      _phase = GenyPhase.speaking;
      _statusMessage = 'WEB INTELLIGENCE RETRIEVED';
      notifyListeners();
      await _voice.speak(answer);

      await _startFollowUpListening();
      return;
    }

    // 12. Full AI Intent Interpretation via AiService
    GenyIntent intent;
    try {
      intent = await _ai.interpretGenyCommand(
        speech: trimmed,
        history: _dialogHistory,
      );
    } catch (_) {
      intent = GenyIntent.fallback(trimmed);
    }

    // Save short-term dialog context
    _dialogHistory.add({'role': 'user', 'content': trimmed});
    _dialogHistory.add({'role': 'assistant', 'content': intent.spoken});
    if (_dialogHistory.length > 10) {
      _dialogHistory.removeRange(0, 2);
    }

    switch (intent.type) {
      case GenyIntentType.news:
        _phase = GenyPhase.thinking;
        _statusMessage = 'GATHERING NEWS HEADLINES';
        notifyListeners();

        final ack = PersonalityService.instance.getNewsAck(intent.toolArg);
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        notifyListeners();

        final speakAckFuture = _voice.speak(ack);
        final newsFuture = GenyToolsService.instance.getLiveNews(intent.toolArg);
        final newsData = await newsFuture;

        _phase = GenyPhase.thinking;
        _statusMessage = 'SYNTHESIZING INTELLIGENCE BRIEFING';
        notifyListeners();

        final answerFuture = _ai.answerWithToolResult(
          userQuestion: trimmed,
          toolResult: newsData,
          history: _dialogHistory,
        );

        await speakAckFuture;
        final answer = await answerFuture;

        _lastGenySpeech = answer;
        _phase = GenyPhase.speaking;
        _statusMessage = 'NEWS TELEMETRY BROADCAST';
        notifyListeners();
        await _voice.speak(answer);
        break;

      case GenyIntentType.workflow:
        final rawArg = (intent.toolArg ?? trimmed).toLowerCase();
        // Check for Sentry Protocol / Sentry Mode within workflow intent
        if (rawArg.contains('sentry') || rawArg.contains('watchdog')) {
          final isDisarm = rawArg.contains('disarm') ||
              rawArg.contains('deactivat') ||
              rawArg.contains('stop') ||
              rawArg.contains('cancel') ||
              rawArg.contains('stand down');
          if (isDisarm) {
            _statusMessage = 'SENTRY PROTOCOL // DISARMING';
            notifyListeners();
            await SentryService.instance.disarmSentry();
          } else {
            _statusMessage = 'SENTRY PROTOCOL // ARMING WATCHDOG';
            notifyListeners();
            await SentryService.instance.armSentry();
          }
          break;
        }

        final ack = intent.spoken.isNotEmpty
            ? intent.spoken
            : 'Right away. Calibrating your settings environment now.';
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'CALIBRATING WORKFLOW PROTOCOL';
        notifyListeners();

        // 1. Speak courteous acknowledgment completely
        await _voice.speak(ack);

        // 2. Execute workflow
        _phase = GenyPhase.executing;
        notifyListeners();

        final match = WorkflowService.instance.findMatch(intent.toolArg ?? trimmed) ??
            WorkflowService.instance.findMatch(trimmed);

        if (match != null) {
          await WorkflowService.instance.executeWorkflow(match);
          _lastGenySpeech = match.spokenConfirmation;
          _phase = GenyPhase.speaking;
          _statusMessage = '${match.name.toUpperCase()} ACTIVE';
          notifyListeners();
          await _voice.speak(match.spokenConfirmation);
        } else {
          const fallback = 'All settings have been calibrated for you. Let me know if you need anything else.';
          _lastGenySpeech = fallback;
          _phase = GenyPhase.speaking;
          _statusMessage = 'PROTOCOL ACTIVE';
          notifyListeners();
          await _voice.speak(fallback);
        }
        break;

      case GenyIntentType.webSearch:
        final query = intent.toolArg ?? trimmed;
        final ack = PersonalityService.instance.getWebSearchAck(query);
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'SEARCHING LIVE WEB RECORDS';
        notifyListeners();

        final speakAckFuture = _voice.speak(ack);
        final searchFuture = GenyToolsService.instance.searchWeb(query);
        final searchResult = await searchFuture;

        _phase = GenyPhase.thinking;
        _statusMessage = 'SYNTHESIZING WEB INTELLIGENCE';
        notifyListeners();

        final answerFuture = _ai.answerWithToolResult(
          userQuestion: trimmed,
          toolResult: searchResult,
          history: _dialogHistory,
        );

        await speakAckFuture;
        final answer = await answerFuture;

        _lastGenySpeech = answer;
        _phase = GenyPhase.speaking;
        _statusMessage = 'WEB INTELLIGENCE RETRIEVED';
        notifyListeners();
        await _voice.speak(answer);
        break;

      case GenyIntentType.weather:
        final loc = intent.toolArg ?? '';
        final ack = PersonalityService.instance.getWeatherAck(loc);
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'METEOROLOGICAL TELEMETRY';
        notifyListeners();

        final speakAckFuture = _voice.speak(ack);
        final weatherFuture = GenyToolsService.instance.getWeather(loc);
        final weatherResult = await weatherFuture;

        _phase = GenyPhase.thinking;
        _statusMessage = 'SYNTHESIZING WEATHER REPORT';
        notifyListeners();

        final answerFuture = _ai.answerWithToolResult(
          userQuestion: trimmed,
          toolResult: weatherResult,
          history: _dialogHistory,
        );

        await speakAckFuture;
        final answer = await answerFuture;

        _lastGenySpeech = answer;
        _phase = GenyPhase.speaking;
        _statusMessage = 'METEOROLOGICAL REPORT COMPLETE';
        notifyListeners();
        await _voice.speak(answer);
        break;

      case GenyIntentType.battery:
        _phase = GenyPhase.thinking;
        _statusMessage = 'COMPUTING // BATTERY DIAGNOSTICS';
        notifyListeners();

        final battery =
            await GenyToolsService.instance.getBatteryStatus();
        final level = battery['level'] as int;
        final isCharging = battery['isCharging'] as bool;
        final battReply = level >= 0
            ? 'Your battery is currently at $level%, ${isCharging ? 'and charging' : 'discharging normally'}. We have plenty of power. Do you need anything else?'
            : 'Battery level telemetry is currently unavailable. Is there anything else I can check?';

        _lastGenySpeech = battReply;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(battReply);
        break;

      case GenyIntentType.datetime:
        _phase = GenyPhase.speaking;
        _statusMessage = 'TEMPORAL DIAGNOSTICS';
        notifyListeners();

        final dt = GenyToolsService.instance.getCurrentDateTime();
        final reply = 'It is currently $dt. How else may I be of service today?';
        _lastGenySpeech = reply;
        notifyListeners();
        await _voice.speak(reply);
        break;

      case GenyIntentType.torch:
        final on = intent.toolArg == 'on';
        _phase = GenyPhase.thinking;
        _statusMessage = on ? 'COMPUTING // ACTIVATING TORCH' : 'COMPUTING // DEACTIVATING TORCH';
        notifyListeners();

        await GenyToolsService.instance.setTorch(on);
        final reply = on
            ? 'Flashlight is on. Let me know when you would like it switched off.'
            : 'Flashlight is deactivated. Anything else I can do for you?';
        _lastGenySpeech = reply;
        _phase = GenyPhase.speaking;
        _statusMessage = on ? 'TORCH ACTIVE' : 'TORCH OFFLINE';
        notifyListeners();
        await _voice.speak(reply);
        break;

      case GenyIntentType.routine:
        final isMorning = (intent.toolArg ?? '').toLowerCase() == 'morning' ||
            trimmed.toLowerCase().contains('morning');
        _phase = GenyPhase.thinking;
        _statusMessage = isMorning ? 'COMPUTING // MORNING BRIEFING' : 'COMPUTING // NIGHT PROTOCOL';
        notifyListeners();

        final briefing = isMorning
            ? await RoutineAutomationService.instance.executeMorningRoutine()
            : await RoutineAutomationService.instance.executeEveningRoutine();

        _lastGenySpeech = briefing;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(briefing);
        break;

      case GenyIntentType.finance:
        _phase = GenyPhase.thinking;
        _statusMessage = 'COMPUTING // FINANCIAL TELEMETRY';
        notifyListeners();

        final quote = await FinanceTrackingService.instance.getQuoteForQuery(trimmed);
        _lastGenySpeech = quote;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(quote);
        break;

      case GenyIntentType.sports:
        _phase = GenyPhase.thinking;
        _statusMessage = 'COMPUTING // SPORTS FIXTURES';
        notifyListeners();

        final update = await SportsService.instance.getSportsUpdate(trimmed);
        _lastGenySpeech = update;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(update);
        break;

      case GenyIntentType.todo:
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('add ') || lower.contains('add task') || lower.contains('add to')) {
          var taskText = trimmed
              .replaceFirst(RegExp(r'^(add\s+to\s+(my\s+)?(todo|to-do)(\s+list)?|add\s+task|add)\s+', caseSensitive: false), '')
              .trim();
          if (taskText.isEmpty) taskText = 'Review task';
          await TodoService.instance.addTask(taskText);
          final reply = 'I have added "$taskText" to your to-do agenda. Anything else?';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'TODO ITEM RECORDED';
          notifyListeners();
          await _voice.speak(reply);
        } else {
          final reply = TodoService.instance.getPendingTasksSpoken();
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'TASK AGENDA';
          notifyListeners();
          await _voice.speak(reply);
        }
        break;

      case GenyIntentType.notes:
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('take a note') || lower.startsWith('note down') || lower.startsWith('write a note')) {
          var noteContent = trimmed
              .replaceFirst(RegExp(r'^(take\s+a\s+note(\s+that)?|note\s+down|write\s+a\s+note(\s+that)?)\s*[:\s]*', caseSensitive: false), '')
              .trim();
          if (noteContent.isEmpty) noteContent = 'Personal Note';
          await NotesKnowledgeService.instance.addNote(
            title: 'Voice Note ${DateTime.now().month}/${DateTime.now().day}',
            content: noteContent,
          );
          final reply = 'Note saved in your personal knowledge base: "$noteContent".';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'KNOWLEDGE RECORD SAVED';
          notifyListeners();
          await _voice.speak(reply);
        } else {
          final reply = NotesKnowledgeService.instance.searchNotesSpoken(trimmed);
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'KNOWLEDGE RETRIEVAL';
          notifyListeners();
          await _voice.speak(reply);
        }
        break;

      case GenyIntentType.calendar:
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('remind me to ') || lower.startsWith('set a reminder for ')) {
          final reminderText = trimmed
              .replaceFirst(RegExp(r'^(remind\s+me\s+to|set\s+a\s+reminder\s+for)\s+', caseSensitive: false), '')
              .trim();
          await CalendarReminderService.instance.addItem(
            title: reminderText,
            dateTime: DateTime.now().add(const Duration(hours: 1)),
            isReminder: true,
          );
          final reply = 'I have set a reminder for "$reminderText".';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'REMINDER SCHEDULED';
          notifyListeners();
          await _voice.speak(reply);
        } else {
          final reply = CalendarReminderService.instance.getTodayBriefingSpoken();
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'CALENDAR SCHEDULE';
          notifyListeners();
          await _voice.speak(reply);
        }
        break;

      case GenyIntentType.email:
        final lowerEmail = trimmed.toLowerCase();
        final isInboxCheck = lowerEmail.contains('read') ||
            lowerEmail.contains('check') ||
            lowerEmail.contains('inbox') ||
            lowerEmail.contains('what are') ||
            lowerEmail.contains('new') ||
            lowerEmail.contains('recent');

        String emailReply;
        if (isInboxCheck) {
          emailReply = await InboxService.instance.getEmailSummary();
        } else {
          final triage = await EmailTriageService.instance.triageEmail(trimmed);
          emailReply = '${triage.summary} Priority is flagged as ${triage.priority.name}. Would you like me to open a draft reply for you?';
        }

        _lastGenySpeech = emailReply;
        _phase = GenyPhase.speaking;
        _statusMessage = 'EMAIL INBOX PROCESSED';
        notifyListeners();
        await _voice.speak(emailReply);
        break;

      case GenyIntentType.message:
        final lowerMsg = trimmed.toLowerCase();
        final isSmsCheck = lowerMsg.contains('read') ||
            lowerMsg.contains('check') ||
            lowerMsg.contains('inbox') ||
            lowerMsg.contains('what are') ||
            lowerMsg.contains('recent message') ||
            lowerMsg.contains('new message') ||
            lowerMsg.contains('read my sms');

        if (isSmsCheck) {
          final smsReply = await InboxService.instance.getSmsSummary();
          _lastGenySpeech = smsReply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'SMS INBOX PROCESSED';
          notifyListeners();
          await _voice.speak(smsReply);
        } else {
          final draftText = await MessageDraftingService.instance.draftMessageContent(prompt: trimmed);
          final reply = 'I have prepared this message draft for you: "$draftText". Would you like me to dispatch it?';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          _statusMessage = 'MESSAGE DRAFT PREPARED';
          notifyListeners();
          await _voice.speak(reply);
          await MessageDraftingService.instance.dispatchDraft(
            MessageDraft(
              channel: trimmed.toLowerCase().contains('whatsapp') ? MessageChannel.whatsapp : MessageChannel.sms,
              recipient: '',
              body: draftText,
            ),
          );
        }
        break;

      case GenyIntentType.vision:
        final isScreen = trimmed.toLowerCase().contains('screen');
        final ack = isScreen
            ? 'Scanning active screen elements.'
            : 'Geny Eye optical sensors engaged. Inspecting the subject now.';
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'OPTICAL SENSORS ACTIVE';
        notifyListeners();
        await _voice.speak(ack);

        final analysis = isScreen
            ? await ProactiveAgentService.instance.analyzeCurrentScreen(userQuestion: trimmed)
            : (await VisionPerceptionService.instance.inspectOpticalSnapshot(customPrompt: trimmed)).spokenSummary;

        _lastGenySpeech = analysis;
        _phase = GenyPhase.speaking;
        _statusMessage = 'OPTICAL SCAN COMPLETE';
        notifyListeners();
        await _voice.speak(analysis);
        break;

      case GenyIntentType.smartHome:
        _phase = GenyPhase.thinking;
        _statusMessage = 'SMART HOME IOT // DISPATCHING';
        notifyListeners();

        final reply = await SmartHomeService.instance.handleVoiceCommand(trimmed);
        _lastGenySpeech = reply;
        _phase = GenyPhase.speaking;
        _statusMessage = 'SMART HOME ACTIVE';
        notifyListeners();
        await _voice.speak(reply);
        break;

      case GenyIntentType.commute:
        _phase = GenyPhase.thinking;
        _statusMessage = 'COMPUTING // COMMUTE & TRAFFIC TELEMETRY';
        notifyListeners();

        final commute = await CommuteTrafficService.instance.checkCommute(destination: intent.toolArg);
        _lastGenySpeech = commute.spokenSummary;
        _phase = GenyPhase.speaking;
        _statusMessage = 'COMMUTE REPORT';
        notifyListeners();
        await _voice.speak(commute.spokenSummary);
        break;

      case GenyIntentType.macro:
        final lowerMacro = trimmed.toLowerCase();
        if (lowerMacro.startsWith('stop recording') || lowerMacro.startsWith('save macro')) {
          final skill = await MacroRecorderService.instance.stopRecording();
          final reply = skill != null
              ? 'Macro "${skill.goal}" saved and codified into AGENT.md.'
              : 'Macro recording concluded.';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          notifyListeners();
          await _voice.speak(reply);
        } else if (lowerMacro.startsWith('run macro') || lowerMacro.startsWith('replay macro')) {
          final macroName = trimmed.replaceFirst(RegExp(r'^(run|replay)\s+macro\s+', caseSensitive: false), '').trim();
          final match = await SkillMemoryService.instance.findMatch(macroName);
          if (match != null) {
            final reply = 'Replaying macro "${match.goal}".';
            _lastGenySpeech = reply;
            _phase = GenyPhase.speaking;
            notifyListeners();
            await _voice.speak(reply);
            await MacroRecorderService.instance.replaySkill(match);
          } else {
            final reply = 'No matching macro found for "$macroName".';
            _lastGenySpeech = reply;
            _phase = GenyPhase.speaking;
            notifyListeners();
            await _voice.speak(reply);
          }
        } else {
          final goal = intent.toolArg ?? 'Custom Task';
          await MacroRecorderService.instance.startRecording(goal);
          final reply = 'Macro recording started for "$goal". Perform your actions, then say "save macro".';
          _lastGenySpeech = reply;
          _phase = GenyPhase.speaking;
          notifyListeners();
          await _voice.speak(reply);
        }
        break;

      case GenyIntentType.airGestures:
        _phase = GenyPhase.thinking;
        _statusMessage = 'AIR GESTURES SENSORY MATRIX';
        notifyListeners();
        final raw = (intent.toolArg ?? trimmed).toLowerCase();
        final isOff = raw.contains('off') ||
            raw.contains('disable') ||
            raw.contains('deactivat') ||
            raw.contains('stop');
        String gestureReply;
        if (isOff) {
          await AirGestureService.instance.stop();
          gestureReply = 'Iron Man zero-touch air gesture sensors disengaged.';
        } else {
          await AirGestureService.instance.start();
          gestureReply =
              'Zero-touch air gestures engaged. Wave over the screen to skip tracks, hover palm to pause, or double wave for instant screenshot.';
        }
        _lastGenySpeech = gestureReply;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(gestureReply);
        break;

      case GenyIntentType.chargingTelemetry:
        _phase = GenyPhase.thinking;
        _statusMessage = 'ARC REACTOR CHARGING TELEMETRY';
        notifyListeners();
        ChargingTelemetryService.instance.showCinematicHud.value = true;
        final chargingReport = await ChargingTelemetryService.instance.getSpokenTelemetry();
        _lastGenySpeech = chargingReport;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(chargingReport);
        break;

      case GenyIntentType.polyglotDiplomat:
        _phase = GenyPhase.thinking;
        _statusMessage = 'POLYGLOT DIPLOMAT // TRANSLATION';
        notifyListeners();
        _showModalSafely(const PolyglotDiplomatDialog());
        const transAck =
            'Polyglot Diplomat initialized. Ready for real-time diplomatic translation.';
        _lastGenySpeech = transAck;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(transAck);
        break;

      case GenyIntentType.codeBlack:
        _phase = GenyPhase.thinking;
        _statusMessage = 'CODE BLACK // HARDWARE LOCKOUT';
        notifyListeners();
        await CodeBlackService.instance.arm();
        _phase = GenyPhase.idle;
        notifyListeners();
        break;

      case GenyIntentType.floatingCopilot:
        _phase = GenyPhase.thinking;
        _statusMessage = 'HOLOGRAPHIC FLOATING CO-PILOT';
        notifyListeners();
        final rawCopilot = (intent.toolArg ?? trimmed).toLowerCase();
        final isHide = rawCopilot.contains('hide') ||
            rawCopilot.contains('close') ||
            rawCopilot.contains('stop') ||
            rawCopilot.contains('dismiss');
        String copilotReply;
        if (isHide) {
          await FloatingCopilotService.instance.hideOverlay();
          copilotReply = 'Floating co-pilot dismissed.';
        } else {
          await FloatingCopilotService.instance.activateOverlay();
          copilotReply =
              'Holographic floating co-pilot active. Hovering over active applications with live screen context triage.';
        }
        _lastGenySpeech = copilotReply;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(copilotReply);
        break;

      case GenyIntentType.airspaceRadar:
        _phase = GenyPhase.thinking;
        _statusMessage = 'AIRSPACE & SATELLITE RADAR';
        notifyListeners();
        _showModalSafely(const AirspaceRadarDialog());
        final radarReport = await AirspaceRadarService.instance.getSpokenAirspaceReport();
        _lastGenySpeech = radarReport;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(radarReport);
        break;

      case GenyIntentType.multiTaskDump:
        _phase = GenyPhase.thinking;
        _statusMessage = 'MULTI-TASK DECOUPLER';
        notifyListeners();
        final decoupledReport = await MultiTaskDecouplerService.instance.processBrainDump(trimmed);
        _lastGenySpeech = decoupledReport;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(decoupledReport);
        break;

      case GenyIntentType.opticalSolver:
        _phase = GenyPhase.thinking;
        _statusMessage = 'REAL-TIME OPTICAL HUD SOLVER';
        notifyListeners();
        _showModalSafely(const OpticalSolverDialog());
        final solveResult =
            await OpticalSolverService.instance.pointAndSolve(customQuery: trimmed);
        _lastGenySpeech = solveResult.spokenSummary;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(solveResult.spokenSummary);
        break;

      case GenyIntentType.networkAudit:
        _phase = GenyPhase.thinking;
        _statusMessage = 'NETWORK SECURITY AUDIT';
        notifyListeners();
        _showModalSafely(const NetworkAuditDialog());
        final netReport = await NetworkAuditService.instance.getSpokenAuditReport();
        _lastGenySpeech = netReport;
        _phase = GenyPhase.speaking;
        notifyListeners();
        await _voice.speak(netReport);
        break;

      case GenyIntentType.multistep:
        final ack = 'Initiating multi-step execution protocol for you.';
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'MULTI-STEP PROTOCOL';
        notifyListeners();
        await _voice.speak(ack);

        final steps = await ProactiveAgentService.instance.planMultiStepGoal(trimmed);
        final planSpoken = 'I have broken down this goal into ${steps.length} sequential steps: ${steps.join("; ")}. Commencing first step now.';
        _lastGenySpeech = planSpoken;
        notifyListeners();
        await _voice.speak(planSpoken);
        break;

      case GenyIntentType.system:
        await _handleSystemCommand(intent.systemCommand ?? '', intent.spoken);
        break;

      case GenyIntentType.action:
        final goal = intent.actionGoal ?? trimmed;

        // Foundation: Permission system check before risky actions
        if (SettingsService.instance.confirmRiskyActions) {
          final assessment = SecurityAlertService.instance.evaluateActionRisk(goal);
          if (assessment.requiresConfirmation) {
            final confirmPrompt = 'this action involves high-risk operations: ${assessment.reason}. Do you confirm execution?';
            _lastGenySpeech = confirmPrompt;
            _phase = GenyPhase.speaking;
            _statusMessage = 'CONFIRMATION REQUIRED // HIGH RISK';
            notifyListeners();
            await _voice.speak(confirmPrompt);
            await SecurityAlertService.instance.dispatchSecurityAlert('High-risk operation prompted: $goal');
            return;
          }
        }

        _currentTaskGoal = goal;
        final ack = intent.spoken.isNotEmpty
            ? intent.spoken
            : 'Right away. I will take care of that on your device right now.';
        _lastGenySpeech = ack;
        _phase = GenyPhase.speaking;
        _statusMessage = 'PROTOCOL ENGAGED // $goal'.toUpperCase();
        notifyListeners();

        // 1. Speak acknowledgment completely
        await _voice.speak(ack);

        // 2. Execute automation task on device
        _phase = GenyPhase.executing;
        notifyListeners();
        final status = await _executor.executeTask(goal);

        // 3. Deliver completion with caring follow-up
        _phase = GenyPhase.speaking;
        if (status == TaskStatus.success) {
          const successSpeech = 'I have completed that task for you. Is there anything else you need?';
          _lastGenySpeech = successSpeech;
          _statusMessage = 'PROTOCOL FINISHED // SUCCESS';
          notifyListeners();
          await _voice.speak(successSpeech);
        } else if (status == TaskStatus.cancelled) {
          const cancelledSpeech = 'The task was cancelled. What would you like me to do instead?';
          _lastGenySpeech = cancelledSpeech;
          _statusMessage = 'PROTOCOL CANCELLED';
          notifyListeners();
          await _voice.speak(cancelledSpeech);
        } else {
          const failedSpeech =
              'I encountered an obstruction with that task on the screen. Would you like me to try again?';
          _lastGenySpeech = failedSpeech;
          _statusMessage = 'PROTOCOL FAILED';
          notifyListeners();
          await _voice.speak(failedSpeech);
        }
        break;

      case GenyIntentType.chat:
        String chatAnswer = intent.spoken;
        if (chatAnswer.trim().isEmpty ||
            chatAnswer.length < 25 ||
            chatAnswer.toLowerCase().contains('at your service') ||
            chatAnswer.toLowerCase().contains('what would you like me to do')) {
          _phase = GenyPhase.thinking;
          _statusMessage = 'PROCESSING // NEURAL CORE';
          notifyListeners();
          chatAnswer = await _ai.chat(message: trimmed, history: _dialogHistory);
        }
        _lastGenySpeech = chatAnswer;
        _phase = GenyPhase.speaking;
        _statusMessage = 'VOCAL RESPONSE COMPLETE';
        notifyListeners();
        await _voice.speak(chatAnswer);
        break;
    }

    // Persist conversation turn and auto-extract user preferences/facts across sessions
    unawaited(ConversationalMemoryService.instance.recordTurn(trimmed, _lastGenySpeech));

    // Follow-up hands-free continuous listening
    await _startFollowUpListening();
  }

  Future<void> _handleSystemCommand(String cmd, String spoken) async {
    final speech = spoken.isNotEmpty ? spoken : PersonalityService.instance.getGeneralAck();
    _lastGenySpeech = speech;
    _phase = GenyPhase.speaking;
    _statusMessage = 'SYSTEM OVERRIDE // $cmd'.toUpperCase();
    notifyListeners();

    await _voice.speak(speech);

    switch (cmd) {
      case 'volume_up':
        await _system.volumeUp();
        break;
      case 'volume_down':
        await _system.volumeDown();
        break;
      case 'mute':
        await _system.setMuted(true);
        break;
      case 'unmute':
        await _system.setMuted(false);
        break;
      case 'brightness_up':
        final current = await _system.getBrightness() ?? 0.5;
        await _system.setBrightness((current + 0.2).clamp(0.0, 1.0));
        break;
      case 'brightness_down':
        final current = await _system.getBrightness() ?? 0.5;
        await _system.setBrightness((current - 0.2).clamp(0.0, 1.0));
        break;
      case 'screenshot':
        await _automation.takeScreenshotBase64();
        break;
      case 'home':
        await _automation.pressHome();
        break;
      case 'back':
        await _automation.pressBack();
        break;
    }

    if (_shouldListenContinuously) {
      _standDown();
    }
  }

  /// Resolves the exact top YouTube video ID for instant playback without search friction.
  Future<String?> _resolveTopYouTubeVideoId(String query) async {
    try {
      final url = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
      );
      final resp = await http.get(url, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final match =
            RegExp(r'watch\?v=([a-zA-Z0-9_-]{11})').firstMatch(resp.body);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      debugPrint('[GenyService] YouTube top video lookup error: $e');
    }
    return null;
  }
}
