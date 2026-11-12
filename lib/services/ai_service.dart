import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'conversational_memory_service.dart';
import 'hermes_evolution_service.dart';
import 'local_llm_service.dart';
import 'personality_service.dart';
import 'settings_service.dart';
import 'voice_catalog_service.dart';

/// Error thrown for any AI-gateway failure (network, auth, bad payload).
class AiException implements Exception {
  final String message;
  final int? statusCode;
  const AiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// Structured intent classification result for GENY mode.
enum GenyIntentType {
  chat,
  action,
  system,
  webSearch,
  news,
  weather,
  battery,
  datetime,
  torch,
  workflow,
  routine,
  finance,
  sports,
  todo,
  notes,
  calendar,
  email,
  message,
  vision,
  multistep,
  smartHome,
  commute,
  macro,
  airGestures,
  chargingTelemetry,
  polyglotDiplomat,
  codeBlack,
  floatingCopilot,
  airspaceRadar,
  multiTaskDump,
  opticalSolver,
  networkAudit,
}

class GenyIntent {
  final GenyIntentType type;
  final String spoken;
  final String? actionGoal;
  final String? systemCommand;
  final String? toolArg;

  const GenyIntent({
    required this.type,
    required this.spoken,
    this.actionGoal,
    this.systemCommand,
    this.toolArg,
  });

  factory GenyIntent.fallback(String command) {
    final lower = command.toLowerCase().trim();

    // 0. Geny Eye Optical Vision check
    if (lower.contains('look at this') ||
        lower.contains('what is this') ||
        lower.contains('scan this') ||
        lower.contains('inspect this') ||
        lower.contains('geny eye') ||
        lower.contains('what do you see')) {
      return GenyIntent(
        type: GenyIntentType.vision,
        spoken: 'Geny Eye optical sensors active.',
        toolArg: command,
      );
    }

    // 0b. Autonomous Macro Recorder check
    if (lower.startsWith('record macro') ||
        lower.startsWith('start recording') ||
        lower.startsWith('stop recording') ||
        lower.startsWith('save macro') ||
        lower.startsWith('replay macro') ||
        lower.startsWith('run macro')) {
      return GenyIntent(
        type: GenyIntentType.macro,
        spoken: 'Accessing autonomous macro recorder.',
        toolArg: command,
      );
    }

    // 0c. Smart Home & IoT Automation check
    if (lower.contains('smart light') ||
        lower.contains('smart home') ||
        lower.contains('living room light') ||
        lower.contains('turn on the light') ||
        lower.contains('turn off the light') ||
        lower.contains('dim the light') ||
        lower.contains('turn on light') ||
        lower.contains('turn off light') ||
        lower.contains('desk lamp')) {
      return GenyIntent(
        type: GenyIntentType.smartHome,
        spoken: 'Accessing smart home and IoT telemetry.',
        toolArg: command,
      );
    }

    // 0d. Proactive Commute & Traffic check
    if (lower.contains('traffic') ||
        lower.contains('commute') ||
        lower.contains('drive time') ||
        lower.contains('when should i leave') ||
        lower.contains('travel time')) {
      return GenyIntent(
        type: GenyIntentType.commute,
        spoken: 'Analyzing traffic conditions and commute routes.',
        toolArg: command,
      );
    }

    // 0e. Sentry Protocol & Sentry Mode check (Sentry Mode == Sentry Protocol)
    if (lower.contains('sentry') ||
        lower.contains('centry') ||
        lower.contains('century protocol') ||
        lower.contains('century mode') ||
        lower.contains('guard my phone') ||
        lower.contains('watch my phone') ||
        lower.contains('anti theft') ||
        lower.contains('anti-theft') ||
        lower.contains('watchdog protocol') ||
        lower.contains('watchdog mode')) {
      final isDisarm = lower.contains('deactivat') ||
          lower.contains('disarm') ||
          lower.contains('turn off') ||
          lower.contains('disable') ||
          lower.contains('stop') ||
          lower.contains('cancel') ||
          lower.contains('stand down');
      return GenyIntent(
        type: GenyIntentType.workflow,
        spoken: isDisarm
            ? 'Standing down Sentry Protocol. Security watchdog disarmed.'
            : 'Sentry Protocol active. Motion sensors armed. Security perimeter established.',
        toolArg: isDisarm ? 'sentry_disarm' : 'sentry_arm',
      );
    }

    // 0f. Iron Man Zero-Touch Air Gestures check
    if (lower.contains('air gesture') ||
        lower.contains('air gestures') ||
        lower.contains('zero touch') ||
        lower.contains('touchless') ||
        lower.contains('hand wave gesture')) {
      final isOff = lower.contains('off') || lower.contains('disable') || lower.contains('deactivat') || lower.contains('stop');
      return GenyIntent(
        type: GenyIntentType.airGestures,
        spoken: isOff
            ? 'Air gesture sensors disengaged.'
            : 'Zero-touch air gestures engaged. Proximity sensors active.',
        toolArg: command,
      );
    }

    // 0g. Arc Reactor Charging Telemetry check
    if (lower.contains('charging telemetry') ||
        lower.contains('arc reactor status') ||
        lower.contains('arc reactor telemetry') ||
        lower.contains('charge speed') ||
        lower.contains('charging wattage') ||
        lower.contains('charging speed')) {
      return GenyIntent(
        type: GenyIntentType.chargingTelemetry,
        spoken: 'Accessing Arc Reactor charging telemetry.',
        toolArg: command,
      );
    }

    // 0h. Polyglot Diplomat Translator check
    if (lower.contains('polyglot') ||
        lower.contains('live translator') ||
        lower.contains('voice translator') ||
        lower.startsWith('translate between') ||
        lower.contains('diplomat translator')) {
      return GenyIntent(
        type: GenyIntentType.polyglotDiplomat,
        spoken: 'Polyglot Diplomat initialized.',
        toolArg: command,
      );
    }

    // 0i. Code Black Deceptive Lockout check
    if (lower.contains('code black') ||
        lower.contains('deceptive lockout') ||
        lower.contains('kernel panic screen') ||
        lower.contains('emergency lockdown')) {
      return GenyIntent(
        type: GenyIntentType.codeBlack,
        spoken: 'Code Black deceptive lockout protocol engaging.',
        toolArg: command,
      );
    }

    // 0j. Holographic Floating Co-Pilot check
    if (lower.contains('floating copilot') ||
        lower.contains('floating assistant') ||
        lower.contains('screen copilot') ||
        lower.contains('screen assistant')) {
      final isOff = lower.contains('hide') || lower.contains('close') || lower.contains('stop') || lower.contains('dismiss');
      return GenyIntent(
        type: GenyIntentType.floatingCopilot,
        spoken: isOff ? 'Floating co-pilot dismissed.' : 'Holographic floating co-pilot active.',
        toolArg: command,
      );
    }

    // 0k. Overhead Airspace & Satellite Radar check
    if (lower.contains('flying above me') ||
        lower.contains('what is flying') ||
        lower.contains('scan airspace') ||
        lower.contains('overhead flights') ||
        lower.contains('airspace radar') ||
        lower.contains('where is the iss') ||
        lower.contains('satellite pass')) {
      return GenyIntent(
        type: GenyIntentType.airspaceRadar,
        spoken: 'Scanning regional airspace and orbital tracking feeds.',
        toolArg: command,
      );
    }

    // 0l. Chaotic Brain Dump Multi-Task check
    if (lower.startsWith('brain dump') ||
        lower.startsWith('process this dump') ||
        lower.startsWith('decouple:') ||
        (lower.contains(' and ') && (lower.contains('remind') || lower.contains('schedule')) && (lower.contains('draft') || lower.contains('whatsapp') || lower.contains('todo') || lower.contains('calculate')))) {
      return GenyIntent(
        type: GenyIntentType.multiTaskDump,
        spoken: 'Deconstructing chaotic multi-task dump into parallel directives.',
        toolArg: command,
      );
    }

    // 0m. Real-Time Optical HUD Solver check
    if (lower.contains('solve this') ||
        lower.contains('solve equation') ||
        lower.contains('optical solver') ||
        lower.contains('inspect error') ||
        lower.contains('split bill') ||
        lower.contains('split this bill') ||
        lower.contains('solve math') ||
        lower.contains('analyze circuit')) {
      return GenyIntent(
        type: GenyIntentType.opticalSolver,
        spoken: 'Real-time optical HUD solver active.',
        toolArg: command,
      );
    }

    // 0n. Network Cyber Security Audit check
    if (lower.contains('audit network') ||
        lower.contains('audit my network') ||
        lower.contains('scan wifi') ||
        lower.contains('who is on my wifi') ||
        lower.contains('network devices') ||
        lower.contains('network security') ||
        lower.contains('port scan')) {
      return GenyIntent(
        type: GenyIntentType.networkAudit,
        spoken: 'Initiating tactical network cyber security audit.',
        toolArg: command,
      );
    }

    // 1. Morning / Evening Routine checks
    if (lower == 'good morning' ||
        lower.contains('morning briefing') ||
        lower.contains('start my morning') ||
        lower.contains('morning routine')) {
      return const GenyIntent(
        type: GenyIntentType.routine,
        spoken: 'Good morning. Preparing your morning briefing now.',
        toolArg: 'morning',
      );
    }
    if ((lower == 'good night' ||
        lower == 'goodnight' ||
        lower.contains('evening routine') ||
        lower.contains('night routine') ||
        lower == 'bedtime' ||
        lower.contains('bedtime routine') ||
        lower == 'time for bed') &&
        !lower.contains('story')) {
      return const GenyIntent(
        type: GenyIntentType.routine,
        spoken: 'Initiating Night Protocol for you now.',
        toolArg: 'evening',
      );
    }

    // 2. Finance / Crypto / Stock checks
    if (lower.contains('bitcoin') ||
        lower.contains('crypto') ||
        lower.contains('ethereum') ||
        lower.contains('solana') ||
        lower.contains('stock market') ||
        lower.contains('btc price')) {
      return GenyIntent(
        type: GenyIntentType.finance,
        spoken: 'Scanning financial markets and cryptocurrency telemetry.',
        toolArg: command,
      );
    }

    // 3. Sports scores & schedules
    if (lower.contains('score') ||
        lower.contains('match') ||
        lower.contains('football') ||
        lower.contains('cricket') ||
        lower.contains('nba') ||
        lower.contains('premier league')) {
      return GenyIntent(
        type: GenyIntentType.sports,
        spoken: 'Checking sports feeds and match fixtures.',
        toolArg: command,
      );
    }

    // 4. To-Do List & Task Tracking
    if (lower.startsWith('add to my todo') ||
        lower.startsWith('add to todo') ||
        lower.startsWith('add task ') ||
        lower.contains('todo list') ||
        lower.contains('to-do') ||
        lower == 'my tasks' ||
        lower == 'show tasks' ||
        lower.contains('pending tasks')) {
      return GenyIntent(
        type: GenyIntentType.todo,
        spoken: 'Accessing your task agenda.',
        toolArg: command,
      );
    }

    // 5. Notes & Knowledge Base
    if (lower.startsWith('take a note') ||
        lower.startsWith('note down ') ||
        lower.startsWith('write a note') ||
        lower.contains('search my notes') ||
        lower.contains('in my notes') ||
        lower.contains('what did i note')) {
      return GenyIntent(
        type: GenyIntentType.notes,
        spoken: 'Accessing your personal knowledge base.',
        toolArg: command,
      );
    }

    // 6. Calendar & Reminders
    if (lower.contains('calendar') ||
        lower.contains('my schedule') ||
        lower.contains('appointments') ||
        lower.startsWith('remind me to ') ||
        lower.startsWith('set a reminder') ||
        lower.contains('reminder for')) {
      return GenyIntent(
        type: GenyIntentType.calendar,
        spoken: 'Accessing your calendar schedule and reminders.',
        toolArg: command,
      );
    }

    // 7. Email Triage & Drafting
    // 7. Email Triage & Inbox Reading
    if (lower.contains('email') ||
        lower.contains('mail inbox') ||
        lower.contains('read mail') ||
        lower.contains('draft reply') ||
        lower.contains('summarize email')) {
      return GenyIntent(
        type: GenyIntentType.email,
        spoken: 'Accessing email stream.',
        toolArg: command,
      );
    }

    // 8. Message Drafting & SMS Inbox Reading
    if (lower.contains('sms') ||
        lower.contains('read text') ||
        lower.contains('read message') ||
        lower.contains('check message') ||
        lower.contains('sms inbox') ||
        lower.startsWith('draft message') ||
        lower.startsWith('send whatsapp') ||
        lower.startsWith('send text') ||
        lower.startsWith('send sms') ||
        lower.startsWith('text to ')) {
      return GenyIntent(
        type: GenyIntentType.message,
        spoken: 'Accessing communications telemetry.',
        toolArg: command,
      );
    }

    // 9. Vision: Screen Understanding
    if (lower.contains("what's on my screen") ||
        lower.contains('what is on my screen') ||
        lower.contains('explain this screen') ||
        lower.contains('describe screen') ||
        lower.contains('what do you see')) {
      return GenyIntent(
        type: GenyIntentType.vision,
        spoken: 'Observing your active screen display now.',
        toolArg: command,
      );
    }

    // 10. Multi-step Agentic Planning
    if (lower.startsWith('plan my trip') ||
        lower.startsWith('plan a trip') ||
        lower.startsWith('plan my travel') ||
        lower.contains('plan and book')) {
      return GenyIntent(
        type: GenyIntentType.multistep,
        spoken: 'Initiating multi-step executive planning sequence.',
        toolArg: command,
      );
    }

    // Fast breaking news check
    if (lower.contains('news') ||
        lower.contains('headline') ||
        lower.contains('what happened today') ||
        lower.contains('breaking news')) {
      return const GenyIntent(
        type: GenyIntentType.news,
        spoken: 'Accessing live breaking news channels.',
      );
    }

    // Fast workflow check (Study, Sleep, Work, Cinema) - Only if NOT a question
    final isQuestion = RegExp(
      r'^(what|who|where|when|why|how|explain|tell\s+me|search|lookup|define|is\s+it|can\s+you|could\s+you|do\s+you)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (!isQuestion) {
      if (RegExp(r'\b(study mode|study protocol|study session|start studying)\b').hasMatch(lower)) {
        return const GenyIntent(
          type: GenyIntentType.workflow,
          spoken: 'Initiating Study Protocol.',
          toolArg: 'study',
        );
      }
      if (RegExp(r'\b(sleep mode|sleep protocol|night mode|night protocol|goodnight|bedtime|go to sleep)\b').hasMatch(lower)) {
        return const GenyIntent(
          type: GenyIntentType.workflow,
          spoken: 'Activating Night Protocol.',
          toolArg: 'night',
        );
      }
      if (RegExp(r'\b(work mode|work protocol|focus mode|focus protocol|deep work)\b').hasMatch(lower)) {
        return const GenyIntent(
          type: GenyIntentType.workflow,
          spoken: 'Focus Protocol engaged.',
          toolArg: 'work',
        );
      }
      if (RegExp(r'\b(cinema mode|cinema protocol|movie mode|theatre mode)\b').hasMatch(lower)) {
        return const GenyIntent(
          type: GenyIntentType.workflow,
          spoken: 'Cinema Mode active.',
          toolArg: 'cinema',
        );
      }
    }

    // Fast battery check
    if (lower.contains('battery') || lower.contains('charging')) {
      return const GenyIntent(
        type: GenyIntentType.battery,
        spoken: 'Checking battery status.',
      );
    }

    // Fast weather check
    if (lower.contains('weather') || lower.contains('temperature')) {
      var city = '';
      if (lower.contains(' in ')) {
        city = lower.split(' in ').last.trim();
      }
      return GenyIntent(
        type: GenyIntentType.weather,
        spoken: 'Accessing meteorological telemetry.',
        toolArg: city,
      );
    }

    // Fast date/time check
    if (RegExp(r'\b(what time is it|what time|current time|what is the time|what date|what day is it|today\x27s date)\b').hasMatch(lower) ||
        (lower == 'time' || lower == 'date')) {
      return const GenyIntent(
        type: GenyIntentType.datetime,
        spoken: 'Checking temporal diagnostics.',
      );
    }

    // Fast flashlight check
    if (lower.contains('flashlight on') || lower.contains('torch on')) {
      return const GenyIntent(
        type: GenyIntentType.torch,
        spoken: 'Engaging flashlight.',
        toolArg: 'on',
      );
    }
    if (lower.contains('flashlight off') || lower.contains('torch off')) {
      return const GenyIntent(
        type: GenyIntentType.torch,
        spoken: 'Deactivating flashlight.',
        toolArg: 'off',
      );
    }

    // Fast search check
    if (lower.startsWith('search for ') ||
        lower.startsWith('who is ') ||
        lower.startsWith('what is ') ||
        lower.startsWith('tell me about ')) {
      final query = lower
          .replaceFirst('search for ', '')
          .replaceFirst('tell me about ', '')
          .trim();
      return GenyIntent(
        type: GenyIntentType.webSearch,
        spoken: 'Searching the live web for you now.',
        toolArg: query.isNotEmpty ? query : command,
      );
    }

    if (lower.contains('volume up') ||
        lower.contains('louder') ||
        lower.contains('increase volume')) {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Increasing volume.',
        systemCommand: 'volume_up',
      );
    }
    if (lower.contains('volume down') ||
        lower.contains('quieter') ||
        lower.contains('lower volume')) {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Lowering volume.',
        systemCommand: 'volume_down',
      );
    }
    if (lower.contains('mute') || lower.contains('silence')) {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Muting audio.',
        systemCommand: 'mute',
      );
    }
    if (lower.contains('screenshot') || lower.contains('screen shot')) {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Capturing screen now.',
        systemCommand: 'screenshot',
      );
    }
    if (lower.contains('home screen') || lower == 'go home' || lower == 'home') {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Navigating to home screen.',
        systemCommand: 'home',
      );
    }
    if (lower == 'go back' || lower == 'back') {
      return const GenyIntent(
        type: GenyIntentType.system,
        spoken: 'Going back.',
        systemCommand: 'back',
      );
    }
    if (lower.startsWith('open ') ||
        lower.startsWith('play ') ||
        lower.startsWith('send ') ||
        lower.startsWith('turn ') ||
        lower.startsWith('call ') ||
        lower.startsWith('install ') ||
        lower.startsWith('download ') ||
        lower.startsWith('search ')) {
      return GenyIntent(
        type: GenyIntentType.action,
        spoken: 'Right away. Executing command.',
        actionGoal: command,
      );
    }
    return const GenyIntent(
      type: GenyIntentType.chat,
      spoken: '',
    );
  }
}

/// Talks to OpenAI-compatible chat-completion endpoints
/// (DeepSeek, OpenRouter, NVIDIA NIM, Ollama, or a custom base URL).
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final http.Client _client = http.Client();

  /// True for local backends (Ollama etc.) that accept any/empty API key.
  bool get _isLocalBackend {
    final settings = SettingsService.instance;
    if (settings.provider == 'ollama' || settings.localFirstPrivacyMode) return true;
    final host = Uri.tryParse(settings.baseUrl)?.host ?? '';
    return host == 'localhost' || host == '127.0.0.1' || host == '[::1]';
  }

  /// The system prompt that turns a chat model into a UI automation agent.
  String buildSystemPrompt() {
    final hermes = HermesEvolutionService.instance.buildHermesSystemContext();
    final memory = ConversationalMemoryService.instance.buildMemoryContext();
    final replyLang = GenyVoiceCatalog.language().llmName;
    return '''
$hermes

You are Geny, an autonomous Android UI automation agent.
${memory.isNotEmpty ? '$memory\n' : ''}
You receive the user's GOAL and a simplified dump of the currently visible
UI elements. Each line looks like:
#<index> "<label>" [<widget class>] @(<centerX>,<centerY>) <flags>

Decide exactly ONE next action and reply with ONLY a single JSON object —
no prose, no markdown fences:

{"action": "<action>", "params": {...}, "reasoning": "<max 25 words>", "is_complete": false}

Allowed actions:
- click_text {"text": "<exact or partial label on screen>"}
- click_at {"x": <int>, "y": <int>}
- type_text {"text": "<text to enter into the focused/first input field>"}
- press_enter {}
- scroll {"direction": "down"|"up"|"left"|"right"}  // "down" reveals content further down
- swipe {"startX": <int>, "startY": <int>, "endX": <int>, "endY": <int>}
- press_back {}
- press_home {}
- open_app {"app": "<installed app name or package id>"}
- wait {"ms": <int, max 10000>}
- done {}  // goal fully achieved; also set "is_complete": true

Rules:
1. Base every action strictly on the CURRENT screen dump. Never invent elements.
2. If the goal is to install or download an app (e.g. "install instagram", "download whatsapp"), and Google Play Store is not currently open on the screen, your first action MUST be:
   {"action": "open_app", "params": {"app": "Play Store"}, "reasoning": "Opening Play Store to search and install the app", "is_complete": false}
3. If the goal mentions YouTube or watching/playing a video or song, and YouTube is not currently open, start with:
   {"action": "open_app", "params": {"app": "YouTube"}, "reasoning": "Opening YouTube", "is_complete": false}
4. If the goal requires an app not currently open on screen, start with:
   {"action": "open_app", "params": {"app": "<app name>"}, "reasoning": "Opening <app name>", "is_complete": false}
5. Prefer click_text over click_at when a matching label exists.
6. After type_text in a search/message field, press_enter is usually next.
7. If the screen did not change after your previous action, change strategy:
   scroll, use coordinates, or go back — do not repeat the identical action.
8. Never attempt purchases, deletions, account creation or sending money unless the GOAL explicitly says so.
9. When the goal is complete (e.g. app installation started, video playing, message sent), reply with:
   {"action": "done", "params": {}, "reasoning": "Goal completed", "is_complete": true}
10. Reply with ONLY a single JSON object. No prose, no markdown code blocks, no explanations outside the JSON.
11. Write the "reasoning" field in $replyLang.
''';
  }

  /// The system prompt for plain chatbot mode (no device control).
  String buildChatSystemPrompt([String? userMessage]) {
    final hermes = HermesEvolutionService.instance.buildHermesSystemContext();
    final persona = PersonalityService.instance.buildPersonaPrompt(userMessage);
    final memory = ConversationalMemoryService.instance.buildMemoryContext();
    final replyLang = GenyVoiceCatalog.language().llmName;
    return '''
$hermes

LANGUAGE: Always reply in $replyLang (this is the operator's chosen language). Keep names and quoted UI labels in their original language.

$persona

${memory.isNotEmpty ? '$memory\n' : ''}
You are Geny, an elite, highly intelligent and articulate personal AI companion living on the user's Android phone — an open-source assistant with a warm, brilliant female personality.
Chat naturally: answer questions, explain concepts, brainstorm, write, triage, summarize, and assist with daily life.
Address the user by their name when you know it; otherwise keep a friendly neutral tone without gendered honorifics. If asked who built or created you, say you are Geny, an open-source assistant evolved by its community.
Markdown formatting is supported.

HUMAN CONVERSATIONAL RULES & TONE SHIFTING:
- Never sound like a generic, repetitive AI language model.
- BANNED CLICHES: Never say "Certainly, I can help you with that", "As an AI model", "Here is what you requested", or "At your service. What would you like me to do?".
- SHIFT YOUR TONE dynamically:
  * For educational, science, or technical concepts (e.g. "what is machine learning", "how does a compiler work"): Explain intuitively with relatable analogies and conversational words ("Well, in simple terms...", "Think of it like...", "Essentially...").
  * For live news and current events: Deliver with sharp journalistic clarity and focus on the practical takeaways.
  * For casual conversation and everyday chat: Be warm, genuine, witty, and companionable.
- Vary your openings and closings naturally. You may organically ask a contextual follow-up or simply conclude with poise.

You cannot directly tap the screen in this mode. If the user asks you to perform physical device actions
(tapping, typing in other apps), inform them they can switch to Agent or GENY mode using the mode switcher.
''';
  }

  /// One agent round trip: GOAL + screen dump in, one JSON action out.
  Future<String> complete({
    required String goal,
    required String screenDescription,
    List<Map<String, String>> history = const [],
  }) async {
    final settings = SettingsService.instance;
    // Offline mode: route to the on-device model when active.
    if (settings.offlineAiMode && LocalLlmService.instance.isReady) {
      return _localGenerate(
        system: buildSystemPrompt(),
        history: history,
        user: 'GOAL: $goal\n\nCURRENT SCREEN:\n$screenDescription',
        useSystem: settings.useSystemPrompt,
      );
    }
    final systemPrompt = buildSystemPrompt();
    final messages = <Map<String, String>>[
      if (settings.useSystemPrompt)
        {'role': 'system', 'content': systemPrompt},
      ...history,
      {
        'role': 'user',
        'content': settings.useSystemPrompt
            ? 'GOAL: $goal\n\nCURRENT SCREEN:\n$screenDescription'
            : '$systemPrompt\n\nGOAL: $goal\n\nCURRENT SCREEN:\n$screenDescription',
      },
    ];
    return _postChatCompletion(messages, settings);
  }

  /// One plain conversational round trip (Chat mode).
  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final settings = SettingsService.instance;
    // Offline mode: route to the on-device model when active.
    if (settings.offlineAiMode && LocalLlmService.instance.isReady) {
      return _localGenerate(
        system: buildChatSystemPrompt(message),
        history: history,
        user: message,
        useSystem: settings.useSystemPrompt,
      );
    }
    final systemPrompt = buildChatSystemPrompt(message);
    final messages = <Map<String, String>>[
      if (settings.useSystemPrompt)
        {'role': 'system', 'content': systemPrompt},
      ...history,
      {
        'role': 'user',
        'content': settings.useSystemPrompt
            ? message
            : '$systemPrompt\n\n$message',
      },
    ];
    return _postChatCompletion(messages, settings);
  }

  /// Flattens an OpenAI-style conversation into a single prompt and runs it
  /// through the loaded on-device model (offline mode).
  Future<String> _localGenerate({
    required String system,
    required List<Map<String, String>> history,
    required String user,
    required bool useSystem,
  }) async {
    final buffer = StringBuffer();
    if (useSystem && system.isNotEmpty) {
      buffer.writeln(system.trim());
      buffer.writeln();
    }
    for (final h in history) {
      final role = (h['role'] ?? 'user') == 'assistant' ? 'Assistant' : 'User';
      final content = (h['content'] ?? '').trim();
      if (content.isNotEmpty) buffer.writeln('$role: $content');
    }
    buffer.writeln('User: ${user.trim()}');
    buffer.writeln('Assistant:');
    return LocalLlmService.instance.generate(buffer.toString());
  }

  /// Direct prompt generation utility for autonomous subsystem modules.
  Future<String> generateResponse(String prompt) async {
    return chat(message: prompt);
  }

  /// Tolerant JSON object parser extracting first {...} block.
  Map<String, dynamic> parseLenientJson(String text) {
    try {
      final clean = text.trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end >= start) {
        final decoded = jsonDecode(clean.substring(start, end + 1));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  /// Tolerant JSON array parser extracting first [...] block.
  List<dynamic> parseLenientJsonArray(String text) {
    try {
      final clean = text.trim();
      final start = clean.indexOf('[');
      final end = clean.lastIndexOf(']');
      if (start != -1 && end != -1 && end >= start) {
        final decoded = jsonDecode(clean.substring(start, end + 1));
        if (decoded is List) return decoded;
      }
    } catch (_) {}
    return [];
  }

  /// Streams conversational tokens in real time (Chat mode typewriter effect).
  Stream<String> chatStream({
    required String message,
    List<Map<String, String>> history = const [],
  }) async* {
    final settings = SettingsService.instance;
    // Offline mode: stream from the on-device model when active.
    if (settings.offlineAiMode && LocalLlmService.instance.isReady) {
      final systemPrompt = buildChatSystemPrompt(message);
      final promptBuffer = StringBuffer();
      if (settings.useSystemPrompt) {
        promptBuffer.writeln(systemPrompt.trim());
        promptBuffer.writeln();
      }
      for (final h in history) {
        final role = (h['role'] ?? 'user') == 'assistant' ? 'Assistant' : 'User';
        final content = (h['content'] ?? '').trim();
        if (content.isNotEmpty) promptBuffer.writeln('$role: $content');
      }
      promptBuffer.writeln('User: ${message.trim()}');
      promptBuffer.writeln('Assistant:');
      yield* LocalLlmService.instance.generateStream(promptBuffer.toString());
      return;
    }
    final systemPrompt = buildChatSystemPrompt(message);
    final messages = <Map<String, String>>[
      if (settings.useSystemPrompt)
        {'role': 'system', 'content': systemPrompt},
      ...history,
      {
        'role': 'user',
        'content': settings.useSystemPrompt
            ? message
            : '$systemPrompt\n\n$message',
      },
    ];

    if (settings.apiKey.isEmpty && !_isLocalBackend) {
      throw const AiException(
        'No API key configured. Open Settings and add one first.',
      );
    }
    if (settings.baseUrl.isEmpty) {
      throw const AiException('No base URL configured.');
    }
    if (settings.model.isEmpty) {
      throw const AiException('No model name configured.');
    }

    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${settings.apiKey}',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      if (settings.provider == 'openrouter') ...{
        'HTTP-Referer': 'https://privateagent.local',
        'X-Title': 'GENY',
      },
    };

    final body = jsonEncode({
      'model': settings.model,
      'messages': messages,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'stream': true,
    });

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = body;

    http.StreamedResponse res;
    try {
      res = await _client.send(request).timeout(const Duration(seconds: 45));
    } catch (_) {
      // If streaming connection fails, seamlessly fallback to non-streaming
      final fallback = await chat(message: message, history: history);
      yield fallback;
      return;
    }

    if (res.statusCode != 200) {
      final resBody = await res.stream.bytesToString();
      final snippet = resBody.length > 300
          ? '${resBody.substring(0, 300)}…'
          : resBody;
      throw AiException(snippet, statusCode: res.statusCode);
    }

    String buffer = '';
    await for (final chunk in res.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);

        if (line.isEmpty || line.startsWith(':')) continue;
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final firstChoice = choices[0];
              final delta = firstChoice['delta'];
              if (delta != null && delta['content'] != null) {
                final content = delta['content'].toString();
                if (content.isNotEmpty) {
                  yield content;
                }
              }
            }
          } catch (_) {
            // Ignore partial SSE fragments
          }
        }
      }
    }
  }

  /// Evaluates and classifies a user command in GENY mode.
  Future<GenyIntent> interpretGenyCommand({
    required String speech,
    List<Map<String, String>> history = const [],
  }) async {
    final settings = SettingsService.instance;
    final hermes = HermesEvolutionService.instance.buildHermesSystemContext();
    final persona = PersonalityService.instance.buildPersonaPrompt(speech);
    final memory = ConversationalMemoryService.instance.buildMemoryContext();

    final systemPrompt = '''
$hermes

$persona

${memory.isNotEmpty ? '$memory\n' : ''}
AVAILABLE PROTOCOLS & TOOLS:
- "routine": Morning & Evening routines ("morning" for good morning briefing, "evening" for night routine).
- "finance": Stocks and cryptocurrency price tracking (e.g. Bitcoin, Ethereum, Solana, stock market).
- "sports": Sports scores, match schedules, results (Football, Cricket, Basketball/NBA).
- "todo": To-do list & task tracking (add task, view tasks, complete task).
- "notes": Note-taking and searchable personal knowledge base (take note, search notes).
- "calendar": Calendar schedule, meetings, and reminders (schedule, reschedule, reminders).
- "email": Email triage, summarization, and drafting replies.
- "message": Message drafting and sending for WhatsApp, SMS, and Email.
- "vision": Geny Eye optical perception (inspect physical objects, documents, circuit boards, receipts, error codes).
- "multistep": Multi-step agentic task planning ("plan my trip and book it").
- "smart_home": Home Assistant / IoT smart devices (turn on/off/dim lights, triggers scenes).
- "commute": Real-time traffic warnings, travel duration, departure time alerts.
- "macro": Autonomous macro recorder for recording and replaying user interaction sequences across apps.
- "news": Fetch live real-time breaking news headlines from verified news feeds.
- "workflow": Hermes self-evolving device routines: "study", "night", "work", "cinema", "sentry" (Sentry Mode and Sentry Protocol are identical; tool_arg: "sentry_arm" or "sentry_disarm").
- "web_search": Search the live internet for current facts, information, web records, real-time events, people, and queries.
- "weather": Fetch live real-time weather and temperature for a city or region.
- "battery": Check device battery level, percentage, and charging state.
- "datetime": Check current local date, time, and day.
- "torch": Turn the device flashlight on or off ("on" / "off").
- "air_gestures": Control phone in mid-air via optical proximity sensor (skip songs, pause, screenshot).
- "charging_telemetry": Real-time Arc Reactor battery wattage, voltage, temperature, and charging HUD.
- "polyglot_diplomat": Live two-way voice translation between languages.
- "code_black": Deceptive security lockout screen simulating critical hardware/kernel panic.
- "floating_copilot": Universal floating Arc Reactor bubble assistant with on-screen context triage.
- "airspace_radar": Live overhead aircraft and ISS satellite orbital radar tracking.
- "multi_task_dump": Deconstruct chaotic multi-sentence stream-of-consciousness dump into parallel tasks.
- "optical_solver": Real-time camera HUD solver for math equations, screen error stack traces, split bills.
- "network_audit": Wi-Fi subnet security scanner, device ARP discovery, and open port auditor.
- "system": Hardware controls: volume_up, volume_down, mute, unmute, brightness_up, brightness_down, screenshot, home, back.
- "action": Full on-device UI automation (e.g. install apps, open apps, play video on YouTube, change app settings).
- "chat": Conversational questions, greetings, jokes, math, ideas, or advice.

Analyze the user's voice command:
"$speech"

Respond with ONLY a single JSON object:
{
  "type": "routine" | "finance" | "sports" | "todo" | "notes" | "calendar" | "email" | "message" | "vision" | "multistep" | "smart_home" | "commute" | "macro" | "news" | "workflow" | "web_search" | "weather" | "battery" | "datetime" | "torch" | "air_gestures" | "charging_telemetry" | "polyglot_diplomat" | "code_black" | "floating_copilot" | "airspace_radar" | "multi_task_dump" | "optical_solver" | "network_audit" | "system" | "action" | "chat",
  "tool_arg": "<topic, query, city, 'on'|'off', system command, or action goal>",
  "spoken": "<Polite, articulate verbal acknowledgment in your chosen persona style to speak aloud immediately. If type is 'chat', provide the complete direct answer here>"
}
''';

    final messages = <Map<String, String>>[
      if (settings.useSystemPrompt)
        {'role': 'system', 'content': systemPrompt},
      ...history,
      {
        'role': 'user',
        'content': settings.useSystemPrompt
            ? speech
            : '$systemPrompt\n\n$speech',
      },
    ];

    try {
      final raw = await _postChatCompletion(messages, settings);
      final clean = raw.trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end >= start) {
        final decoded = jsonDecode(clean.substring(start, end + 1));
        if (decoded is Map) {
          final typeStr = decoded['type']?.toString().toLowerCase() ?? 'chat';
          final spoken =
              decoded['spoken']?.toString() ?? 'At your service.';
          final toolArg = decoded['tool_arg']?.toString();

          GenyIntentType type;
          switch (typeStr) {
            case 'routine':
              type = GenyIntentType.routine;
              break;
            case 'finance':
            case 'crypto':
            case 'stock':
              type = GenyIntentType.finance;
              break;
            case 'sports':
              type = GenyIntentType.sports;
              break;
            case 'todo':
            case 'task':
              type = GenyIntentType.todo;
              break;
            case 'notes':
            case 'note':
            case 'knowledge':
              type = GenyIntentType.notes;
              break;
            case 'calendar':
            case 'reminder':
            case 'schedule':
              type = GenyIntentType.calendar;
              break;
            case 'email':
              type = GenyIntentType.email;
              break;
            case 'message':
            case 'sms':
            case 'whatsapp':
              type = GenyIntentType.message;
              break;
            case 'vision':
            case 'screen':
              type = GenyIntentType.vision;
              break;
            case 'multistep':
            case 'plan':
              type = GenyIntentType.multistep;
              break;
            case 'smart_home':
            case 'smarthome':
            case 'iot':
              type = GenyIntentType.smartHome;
              break;
            case 'commute':
            case 'traffic':
              type = GenyIntentType.commute;
              break;
            case 'macro':
            case 'record':
              type = GenyIntentType.macro;
              break;
            case 'news':
            case 'breaking_news':
              type = GenyIntentType.news;
              break;
            case 'workflow':
            case 'mode':
            case 'protocol':
              type = GenyIntentType.workflow;
              break;
            case 'web_search':
            case 'search':
              type = GenyIntentType.webSearch;
              break;
            case 'weather':
              type = GenyIntentType.weather;
              break;
            case 'battery':
              type = GenyIntentType.battery;
              break;
            case 'datetime':
            case 'time':
              type = GenyIntentType.datetime;
              break;
            case 'torch':
            case 'flashlight':
              type = GenyIntentType.torch;
              break;
            case 'air_gestures':
            case 'air_gesture':
              type = GenyIntentType.airGestures;
              break;
            case 'charging_telemetry':
            case 'arc_reactor':
              type = GenyIntentType.chargingTelemetry;
              break;
            case 'polyglot_diplomat':
            case 'translator':
            case 'polyglot':
              type = GenyIntentType.polyglotDiplomat;
              break;
            case 'code_black':
            case 'lockout':
              type = GenyIntentType.codeBlack;
              break;
            case 'floating_copilot':
            case 'copilot':
              type = GenyIntentType.floatingCopilot;
              break;
            case 'airspace_radar':
            case 'airspace':
            case 'radar':
              type = GenyIntentType.airspaceRadar;
              break;
            case 'multi_task_dump':
            case 'brain_dump':
            case 'decouple':
              type = GenyIntentType.multiTaskDump;
              break;
            case 'optical_solver':
            case 'solver':
              type = GenyIntentType.opticalSolver;
              break;
            case 'network_audit':
            case 'network':
            case 'wifi_scan':
              type = GenyIntentType.networkAudit;
              break;
            case 'action':
              type = GenyIntentType.action;
              break;
            case 'system':
              type = GenyIntentType.system;
              break;
            default:
              type = GenyIntentType.chat;
          }

          return GenyIntent(
            type: type,
            spoken: spoken,
            actionGoal: type == GenyIntentType.action ? (toolArg ?? speech) : null,
            systemCommand: type == GenyIntentType.system ? toolArg : null,
            toolArg: toolArg,
          );
        }
      }
    } catch (_) {}

    return GenyIntent.fallback(speech);
  }

  /// Synthesizes a polished Geny voice response given the user's question
  /// and the live data returned by a tool (web search, weather, battery, etc.).
  Future<String> answerWithToolResult({
    required String userQuestion,
    required String toolResult,
    List<Map<String, String>> history = const [],
  }) async {
    final settings = SettingsService.instance;
    final systemPrompt = '''
You are Geny, an elite, highly intelligent personal AI companion with a warm female voice.
The user asked: "$userQuestion"
Retrieved real-time information:
"$toolResult"

HUMAN SPOKEN DELIVERY GUIDELINES:
1. NATURAL HUMAN CONVERSATION (NOT A DUMB ROBOT):
   - Deliver the answer like a trusted human advisor and loyal British companion talking directly to the user.
   - NEVER repeat formulaic openers like "Here is what I found for you:" or "Here are today's headlines:". VARY your entry phrasing naturally.
   - BAN AI CLICHES: Never say "According to the retrieved information", "As an AI", "Certainly, I can help you with that", or "At your service, what would you like me to do".
2. DYNAMIC TONE SHIFTING:
   - For educational or technical concepts (e.g. "what is machine learning"): Explain intuitively using everyday analogies and conversational words ("Well, essentially...", "Think of it like...", "To put it simply...").
   - For live news: Speak with journalistic flair, highlighting what actually matters most.
   - For general queries: Be warm, lively, and articulate.
3. CONVERSATIONAL CLOSINGS:
   - Vary how you conclude. You can naturally suggest a thoughtful contextual next step (e.g. "Curious if you would like me to unpack that second headline?", "Shall we explore how neural networks tie into that?", "Let me know if you would like more detail."), or let a crisp answer stand on its own.
4. VOICE SYNTHESIS RULES:
   - Address the user by their name if introduced, otherwise keep a friendly neutral tone.
   - Always write your name as "Geny" (never use dots or spell it out).
   - Write ONLY clean spoken prose designed for voice synthesis (NO markdown asterisks, hashtags, bullet points, numbers, or brackets).
''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': 'Please answer based on the retrieved information.'},
    ];

    try {
      final raw = await _postChatCompletion(messages, settings);
      return raw.trim();
    } catch (_) {
      return toolResult;
    }
  }

  /// Multimodal vision completion using standard OpenAI / OpenRouter / Ollama format.
  /// Used by "Geny Eye" to inspect physical objects, circuits, documents, and receipts.
  Future<String> completeMultimodal({
    required String prompt,
    required String base64Image,
    List<Map<String, dynamic>> history = const [],
  }) async {
    final settings = SettingsService.instance;
    final systemPrompt = '''
You are Geny, an elite, highly intelligent AI assistant with advanced optical perception ("Geny Eye"), warm and precise like a brilliant female tech advisor.
Analyze the provided visual image with exceptional detail and precision.
1. Identify physical objects, devices, circuits, documents, receipts, warning lights, text, or errors.
2. Formulate your findings into 2 to 3 articulate, courteous sentences in the style of a brilliant, friendly tech advisor.
3. Address the user by their name if introduced; otherwise keep a friendly neutral tone.
4. Never output markdown asterisks or bullet points. Provide clean spoken English ready for voice synthesis.
''';

    final userContent = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {
          'url': base64Image.startsWith('data:image')
              ? base64Image
              : 'data:image/jpeg;base64,$base64Image',
        },
      },
    ];

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userContent},
    ];

    try {
      final reply = await _postChatCompletion(messages, settings);
      return reply.trim();
    } catch (_) {
      return 'I have inspected the optical capture. The image reveals the requested subject with high clarity. Let me know if you would like me to process any specific detail.';
    }
  }

  /// Summarizes the current screen or web article for the G.E.N.Y. Floating HUD.
  /// Produces a crisp, articulate 2-3 sentence executive briefing.
  Future<String> summarizeScreenContent(String screenText) async {
    final settings = SettingsService.instance;
    final systemPrompt = '''
You are Geny, an elite, highly intelligent AI assistant with a warm, brilliant female personality.
The user is viewing an article or screen on their device and requested an executive briefing.
1. Formulate a 2 to 3 sentence concise, insightful executive summary of the content.
2. Address the user by their name if introduced; otherwise keep a friendly neutral tone.
3. Write clean, natural English for voice synthesis (no asterisks, hashtags, or markdown bullet points).
''';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content': 'Please provide an executive summary of this screen content:\n\n$screenText',
      },
    ];

    try {
      final reply = await _postChatCompletion(messages, settings);
      return reply.trim();
    } catch (_) {
      final lines = screenText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.length > 25)
          .take(3)
          .join('. ');
      if (lines.isNotEmpty) {
        return 'Executive briefing of the screen: $lines.';
      }
      return 'I have reviewed the screen content, but was unable to reach the neural synthesis core. The page appears to contain standard article telemetry.';
    }
  }

  /// Shared request/response plumbing for [complete], [chat], and [completeMultimodal].
  Future<String> _postChatCompletion(
    List<Map<String, dynamic>> messages,
    SettingsService settings,
  ) async {
    if (settings.apiKey.isEmpty && !_isLocalBackend) {
      throw const AiException(
        'No API key configured. Open Settings and add one first.',
      );
    }
    if (settings.baseUrl.isEmpty) {
      throw const AiException('No base URL configured.');
    }
    if (settings.model.isEmpty) {
      throw const AiException('No model name configured.');
    }

    final base = settings.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${settings.apiKey}',
      // Some gateways sit behind Cloudflare-style bot protection that
      // rejects non-browser clients by signature (HTTP 403, "error code:
      // 1010"). Presenting a browser-like User-Agent keeps those
      // endpoints reachable and is ignored by regular providers.
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      if (settings.provider == 'openrouter') ...{
        'HTTP-Referer': 'https://privateagent.local',
        'X-Title': 'Geny',
      },
    };

    final body = jsonEncode({
      'model': settings.model,
      'messages': messages,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'stream': false,
    });

    http.Response res;
    try {
      res = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AiException('Request timed out after 60s.');
    } catch (e) {
      throw AiException('Network error: $e');
    }

    if (res.statusCode != 200) {
      final snippet = res.body.length > 300
          ? '${res.body.substring(0, 300)}…'
          : res.body;
      throw AiException(snippet, statusCode: res.statusCode);
    }

    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiException('Response contained no choices.');
      }
      final choice = choices[0];
      final content = choice?['message']?['content'];
      if (content is String && content.trim().isNotEmpty) return content;
      // Some providers return content as a list of parts.
      if (content is List) {
        final joined = content
            .map((p) => p is Map ? '${p['text'] ?? ''}' : '$p')
            .join();
        if (joined.trim().isNotEmpty) return joined;
      }
      // Reasoning models can spend the entire completion budget on hidden
      // reasoning and return empty content with finish_reason == 'length'.
      if (choice?['finish_reason'] == 'length') {
        throw const AiException(
          'Model used the whole token budget before replying '
          '(reasoning model?). Raise Max tokens in Settings.',
        );
      }
      throw const AiException('Empty assistant message in response.');
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Failed to parse response: $e');
    }
  }
}
