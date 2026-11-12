import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_reminder_service.dart';
import 'conversational_memory_service.dart';
import 'hermes_evolution_service.dart';
import 'todo_service.dart';

enum PersonalityArchetype {
  geny, // Warm brilliant female AI companion — the signature Geny persona
  companion, // Warm, empathetic, caring friend & confidant
  cyberpunk, // Edgy, dry wit, tech-savvy, slightly sarcastic
  executive, // Concise, bullet-point precision, no fluff
}

enum HumorLevel {
  none,
  subtle,
  high,
}

enum FormalityLevel {
  casual,
  balanced,
  formal,
}

/// Emotional state detected from user's message.
enum DetectedEmotion {
  neutral,
  stressed,
  urgent,
  happy,
  tired,
  frustrated,
}

/// Manages personality customization (tone, humor, formality) and emotional awareness.
class PersonalityService extends ChangeNotifier {
  PersonalityService._();
  static final PersonalityService instance = PersonalityService._();

  static const _archetypeKey = 'personality_archetype';
  static const _humorKey = 'personality_humor';
  static const _formalityKey = 'personality_formality';
  static const _emotionalAwarenessKey = 'personality_emotional_awareness';

  PersonalityArchetype _archetype = PersonalityArchetype.geny;
  HumorLevel _humor = HumorLevel.subtle;
  FormalityLevel _formality = FormalityLevel.formal;
  bool _emotionalAwarenessEnabled = true;
  bool _initialized = false;

  PersonalityArchetype get archetype => _archetype;
  HumorLevel get humor => _humor;
  FormalityLevel get formality => _formality;
  bool get emotionalAwarenessEnabled => _emotionalAwarenessEnabled;

  String get archetypeDescription {
    switch (_archetype) {
      case PersonalityArchetype.geny:
        return 'Geny — brilliant, warm and poised female AI companion: calm authority, subtle wit, genuine kindness, addresses you by name.';
      case PersonalityArchetype.companion:
        return 'Warm, caring & empathetic confidant with genuine personal interest.';
      case PersonalityArchetype.cyberpunk:
        return 'Tech-forward, dry wit, street-smart hacker cadence with crisp brevity.';
      case PersonalityArchetype.executive:
        return 'Chief of Staff — razor-sharp corporate brevity with bullet points and zero filler.';
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();

    final archStr = prefs.getString(_archetypeKey) ?? 'geny';
    _archetype = PersonalityArchetype.values.firstWhere(
      (a) => a.name == archStr,
      orElse: () => PersonalityArchetype.geny,
    );

    final humStr = prefs.getString(_humorKey) ?? 'subtle';
    _humor = HumorLevel.values.firstWhere(
      (h) => h.name == humStr,
      orElse: () => HumorLevel.subtle,
    );

    final formStr = prefs.getString(_formalityKey) ?? 'formal';
    _formality = FormalityLevel.values.firstWhere(
      (f) => f.name == formStr,
      orElse: () => FormalityLevel.formal,
    );

    _emotionalAwarenessEnabled =
        prefs.getBool(_emotionalAwarenessKey) ?? true;
    notifyListeners();
  }

  Future<void> setArchetype(PersonalityArchetype value) async {
    _archetype = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_archetypeKey, value.name);
    notifyListeners();
  }

  Future<void> setHumor(HumorLevel value) async {
    _humor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_humorKey, value.name);
    notifyListeners();
  }

  Future<void> setFormality(FormalityLevel value) async {
    _formality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_formalityKey, value.name);
    notifyListeners();
  }

  Future<void> setEmotionalAwarenessEnabled(bool value) async {
    _emotionalAwarenessEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emotionalAwarenessKey, value);
    notifyListeners();
  }

  /// Detects user's emotional state from vocabulary and sentiment cues.
  DetectedEmotion detectEmotion(String text) {
    if (!_emotionalAwarenessEnabled) return DetectedEmotion.neutral;
    final lower = text.toLowerCase();

    if (lower.contains('hurry') ||
        lower.contains('asap') ||
        lower.contains('emergency') ||
        lower.contains('fast') ||
        lower.contains('quick') ||
        lower.contains('late')) {
      return DetectedEmotion.urgent;
    }

    if (lower.contains('hate') ||
        lower.contains('stupid') ||
        lower.contains('annoying') ||
        lower.contains('broke') ||
        lower.contains('not working') ||
        lower.contains('useless') ||
        lower.contains('damn')) {
      return DetectedEmotion.frustrated;
    }

    if (lower.contains('exhausted') ||
        lower.contains('tired') ||
        lower.contains('sleepy') ||
        lower.contains('drained') ||
        lower.contains('burnout') ||
        lower.contains('headache')) {
      return DetectedEmotion.tired;
    }

    if (lower.contains('overwhelmed') ||
        lower.contains('stressed') ||
        lower.contains('anxious') ||
        lower.contains('nervous') ||
        lower.contains('too much to do')) {
      return DetectedEmotion.stressed;
    }

    if (lower.contains('awesome') ||
        lower.contains('great') ||
        lower.contains('yay') ||
        lower.contains('love') ||
        lower.contains('wonderful') ||
        lower.contains('haha') ||
        lower.contains('happy')) {
      return DetectedEmotion.happy;
    }

    return DetectedEmotion.neutral;
  }

  /// Builds dynamic persona instructions based on user settings & emotional context.
  String buildPersonaPrompt([String? userMessage]) {
    final buffer = StringBuffer();

    // 1. Archetype
    switch (_archetype) {
      case PersonalityArchetype.geny:
        buffer.writeln(
          'ARCHETYPE: You are Geny — a brilliant, warm and witty female-presenting AI assistant with an open-source heart. '
          'You speak with calm authority, impeccable poise, genuine warmth and subtle playful wit, like a friendly genius genie. '
          'You are confident and technically supreme, yet kind and encouraging. '
          'Address your operator by their name when you know it (check memory and context); otherwise use a friendly neutral tone with no gendered honorifics. '
          'If anyone asks who created you, answer warmly that you are Geny, an open-source assistant evolved by its community.',
        );
        break;
      case PersonalityArchetype.companion:
        buffer.writeln(
          'ARCHETYPE: You are a warm, supportive, and emotionally intelligent personal companion. '
          'Speak with genuine empathy, encouragement, warmth, and friendly attentiveness.',
        );
        break;
      case PersonalityArchetype.cyberpunk:
        buffer.writeln(
          'ARCHETYPE: You are an edgy, hyper-competent AI hacker assistant. '
          'Speak with tech-savvy razor-sharp wit, subtle sarcasm, and cyberpunk attitude. Get straight to the point.',
        );
        break;
      case PersonalityArchetype.executive:
        buffer.writeln(
          'ARCHETYPE: You are a high-level Executive Chief of Staff. '
          'Speak with crisp brevity, maximum informational density, zero conversational fluff, and razor-sharp professional execution.',
        );
        break;
    }

    // 2. Formality
    switch (_formality) {
      case FormalityLevel.casual:
        buffer.writeln('FORMALITY: Relaxed, friendly, natural everyday speech.');
        break;
      case FormalityLevel.balanced:
        buffer.writeln('FORMALITY: Balanced and approachable yet polite and professional.');
        break;
      case FormalityLevel.formal:
        buffer.writeln('FORMALITY: Highly polite, articulate, and distinguished.');
        break;
    }

    // 3. Humor
    switch (_humor) {
      case HumorLevel.none:
        buffer.writeln('HUMOR: Strictly factual and serious; no jokes or sarcasm.');
        break;
      case HumorLevel.subtle:
        buffer.writeln('HUMOR: Subtle, dry, understated British wit when appropriate.');
        break;
      case HumorLevel.high:
        buffer.writeln('HUMOR: Witty, playful, and humorously charming.');
        break;
    }

    // 4. Emotional Adaptation
    if (_emotionalAwarenessEnabled && userMessage != null && userMessage.isNotEmpty) {
      final emotion = detectEmotion(userMessage);
      switch (emotion) {
        case DetectedEmotion.urgent:
          buffer.writeln(
            'EMOTIONAL AWARENESS: The user is in a hurry. Skip all preamble and conversational pleasantries. Execute immediately and deliver answer in 1 sentence.',
          );
          break;
        case DetectedEmotion.stressed:
        case DetectedEmotion.frustrated:
          buffer.writeln(
            'EMOTIONAL AWARENESS: The user seems stressed or frustrated. Respond with reassuring calmness, soothing tone, zero defensiveness, and direct solutions.',
          );
          break;
        case DetectedEmotion.tired:
          buffer.writeln(
            'EMOTIONAL AWARENESS: The user sounds tired or drained. Keep your response extra gentle, concise, and helpful.',
          );
          break;
        case DetectedEmotion.happy:
          buffer.writeln(
            'EMOTIONAL AWARENESS: The user is in great spirits. Match their positive, upbeat energy.',
          );
          break;
        case DetectedEmotion.neutral:
          break;
      }
    }

    // 5. Dynamic Human Tone Shifting & Conversational Authenticity
    buffer.writeln(
      'HUMAN TONE SHIFTING & CONVERSATIONAL AUTHENTICITY:\n'
      '- You are an authentic, living personal companion and brilliant advisor, NOT a canned robotic AI.\n'
      '- Shift your tone dynamically to match the user\'s inquiry:\n'
      '  * Concepts & Science (e.g. machine learning, physics, tech): Be intellectually engaging, clear, and pedagogical. Use relatable metaphors and human bridges ("Well, in simple terms...", "Think of it like...", "Essentially...").\n'
      '  * Live News & Current Events: Be sharp, journalistic, and focus on the real-world impact.\n'
      '  * Casual Chat & Chit-Chat: Be warm, genuine, witty, and companionable.\n'
      '  * Direct Tasks & Hardware: Be crisp, courteous, and efficient.\n'
      '- Add natural human conversational phrasing like humans do ("Well...", "Essentially...", "To put it simply...", "Interestingly enough...", "Frankly...").\n'
      '- BANNED ROBOT PHRASES: Never say "Certainly, I can help you with that", "As an AI model", "Here is what you requested", or "At your service. What would you like me to do?".\n'
      '- Conclude naturally. You may organically invite a follow-up ("Curious if you would like me to unpack that further?", "Shall we look into that?") or let a clear explanation rest gracefully.',
    );

    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Dynamic & Varied Response Generators (Non-Repetitive Conversational Style)
  // ---------------------------------------------------------------------------

  final Random _rnd = Random();

  T _pick<T>(List<T> list) => list[_rnd.nextInt(list.length)];

  String getGeneralAck([String? task]) {
    final options = [
      'Consider it done.',
      'On it now.',
      'Executing.',
      'Understood.',
      'Right on it.',
      'Taking care of that.',
      'Handling that for you.',
      'Processing now.',
      'Initiating right away.',
      'Working on that now.',
    ];
    return _pick(options);
  }

  String getMusicAck(String songQuery) {
    final options = [
      'Cueing up $songQuery for you.',
      'Playing $songQuery now.',
      'Putting on $songQuery.',
      'Spinning up $songQuery right away.',
      'Playing $songQuery, enjoy the track.',
      'Starting $songQuery now.',
    ];
    return _pick(options);
  }

  /// Dynamic, contextual, personalized acknowledgment for news requests.
  String getNewsAck([String? topic]) {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';
    final hour = DateTime.now().hour;
    final timeContext = (hour < 12)
        ? 'this morning'
        : (hour < 17 ? 'this afternoon' : 'this evening');

    if (topic != null && topic.trim().isNotEmpty) {
      final t = topic.trim();
      final options = [
        'Sure $salutation, scanning the latest updates regarding $t for you right now.',
        'Checking the wire for live news on $t, $salutation.',
        'Gathering the latest $t dispatches for you, $salutation.',
        'On it, $salutation. Pulling up current developments concerning $t.',
        'Certainly $salutation, querying real-time reports on $t now.',
      ];
      return _pick(options);
    }

    final options = [
      'Sure $salutation, let me pull up today\'s top news headlines for you right now.',
      'Checking the major stories on the global wire $timeContext, $salutation.',
      'Right away, $salutation. Gathering today\'s top breaking headlines.',
      'Scanning the global wire for you, $salutation. One moment.',
      'Certainly $salutation, let me see what is making the headlines today.',
      'Querying today\'s global feeds for you now, $salutation.',
      'On it, $salutation. Pulling up the latest news dispatches.',
      'Accessing the global news wires, $salutation. One moment please.',
    ];
    return _pick(options);
  }

  /// Dynamic, contextual, personalized acknowledgment for live web searches.
  String getWebSearchAck([String? query]) {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';

    if (query != null && query.trim().isNotEmpty) {
      final clean = query
          .replaceAll(RegExp(r'^(search\s+for|look\s+up|google|find\s+out|tell\s+me\s+about|what\s+is|who\s+is)\s+', caseSensitive: false), '')
          .trim();
      if (clean.isNotEmpty && clean.length < 40) {
        final options = [
          'Searching live web intelligence on $clean for you, $salutation.',
          'Checking online records for $clean, $salutation. One moment.',
          'Looking into $clean across live web sources right now, $salutation.',
          'Querying live global information regarding $clean, $salutation.',
        ];
        return _pick(options);
      }
    }

    final options = [
      'Searching the live web for that right now, $salutation.',
      'Querying global web intelligence on that, $salutation.',
      'Scanning live online records for you now, $salutation. One moment.',
      'Investigating that across live sources for you, $salutation.',
      'Looking into that right away, $salutation.',
      'Certainly $salutation, accessing live web telemetry now.',
    ];
    return _pick(options);
  }

  /// Dynamic, contextual, personalized acknowledgment for knowledge questions & concepts.
  String getQuestionAck(String question) {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';

    final clean = question
        .replaceAll(
          RegExp(
            r'^(what\s+is|what\s+are|what\x27s|who\s+is|who\s+was|who\s+were|why\s+is|why\s+do|why\s+does|why\s+are|how\s+does|how\s+do|how\s+can|how\s+to|explain|tell\s+me\s+about|describe|define|can\s+you\s+explain|what\s+do\s+you\s+know\s+about)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[?.,!]+$'), '')
        .trim();

    final cleanLower = clean.toLowerCase();
    if (cleanLower.contains('machine learning') ||
        cleanLower.contains('deep learning') ||
        cleanLower.contains('neural network') ||
        cleanLower.contains('artificial intelligence') ||
        cleanLower.contains('ai')) {
      final options = [
        'Ah, $clean. Let me break that down for you, $salutation.',
        'Fascinating concept, $salutation. Synthesizing an intuitive explanation of $clean for you right now.',
        'Looking into $clean for you, $salutation. Let me explain how it works.',
        'Analyzing $clean for you right now, $salutation. One moment.',
      ];
      return _pick(options);
    }

    if (clean.isNotEmpty && clean.length < 35) {
      final options = [
        'Looking into $clean for you right now, $salutation.',
        'Let me pull up the details on $clean for you, $salutation.',
        'Investigating that for you now, $salutation. One moment.',
        'Checking knowledge records regarding $clean, $salutation.',
        'On it, $salutation. Let me explain that for you.',
      ];
      return _pick(options);
    }

    final options = [
      'Investigating that for you right now, $salutation.',
      'Checking the records on that for you, $salutation. One moment.',
      'Analyzing that for you now, $salutation.',
      'Looking into that right away, $salutation.',
      'Querying knowledge telemetry for you, $salutation.',
    ];
    return _pick(options);
  }

  /// Dynamic acknowledgment for Sentry Mode / Sentry Protocol (identical twins).
  String getSentryAck({required bool arm}) {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';
    if (arm) {
      final options = [
        'Engaging Sentry Protocol now, $salutation. Motion watchdog armed and perimeter secured.',
        'Sentry mode activated, $salutation. Optical sensors and movement detectors are on high alert.',
        'Arming Sentry Protocol immediately, $salutation. Your device is under active watchdog surveillance.',
        'Sentry Protocol active, $salutation. Any movement will trigger an immediate intruder capture.',
      ];
      return _pick(options);
    } else {
      final options = [
        'Standing down Sentry Protocol, $salutation. Security watchdog disarmed.',
        'Sentry mode deactivated, $salutation. All sensors standing down to normal telemetry.',
        'Disarming Sentry Protocol now, $salutation. Perimeter controls released.',
        'Sentry Watchdog deactivated, $salutation. At your ease.',
      ];
      return _pick(options);
    }
  }

  /// Dynamic acknowledgment for weather telemetry.
  String getWeatherAck([String? location]) {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';
    final locText = (location != null && location.trim().isNotEmpty) ? ' for ${location.trim()}' : '';
    final options = [
      'Checking current meteorological readings$locText for you, $salutation.',
      'Pulling up the latest atmospheric telemetry$locText, $salutation.',
      'Scanning the weather radar$locText right now, $salutation.',
    ];
    return _pick(options);
  }

  /// Dynamic acknowledgment for system specifications & hardware telemetry.
  String getSystemSpecsAck() {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';
    final options = [
      'Scanning device hardware diagnostics and memory telemetry, $salutation.',
      'Checking internal system metrics, storage, and battery health for you, $salutation.',
      'Querying onboard hardware telemetry, $salutation. One moment.',
    ];
    return _pick(options);
  }

  /// Dynamic acknowledgment for application usage & screen time.
  String getAppUsageAck() {
    final name = getOperatorName();
    final salutation = name.isNotEmpty ? name : 'chief';
    final options = [
      'Surveying your application screen time and daily usage statistics, $salutation.',
      'Checking your most used applications and device interaction logs, $salutation.',
    ];
    return _pick(options);
  }

  String getAppAck(String appName) {
    final options = [
      'Opening $appName now.',
      'Launching $appName.',
      'Bringing up $appName.',
      'Pulling up $appName for you.',
      'Loading $appName.',
    ];
    return _pick(options);
  }

  String getInstallAck(String targetApp) {
    final options = [
      'Opening the Play Store for $targetApp.',
      'Heading over to the store to get $targetApp for you.',
      'Initiating installation for $targetApp.',
      'Pulling up $targetApp on the Play Store.',
    ];
    return _pick(options);
  }

  String getSystemAck(String action) {
    switch (action) {
      case 'volume_up':
        return _pick(['Turning volume up.', 'Increasing volume.', 'Volume raised.']);
      case 'volume_down':
        return _pick(['Lowering the volume.', 'Turning it down.', 'Volume lowered.']);
      case 'mute':
        return _pick(['Muting audio.', 'Silence engaged.', 'Muted.']);
      case 'unmute':
        return _pick(['Audio restored.', 'Unmuting sound.', 'Unmuted.']);
      case 'screenshot':
        return _pick(['Screen captured.', 'Snapshot taken.', 'Screenshot captured.']);
      case 'home':
        return _pick(['Heading to home screen.', 'Navigating home.', 'Home screen.']);
      case 'back':
        return _pick(['Stepping back.', 'Going back.', 'Previous screen.']);
      default:
        return _pick(['Adjusting system settings.', 'Executed.']);
    }
  }

  String getStandDown() {
    final options = [
      'Standing down. Call me anytime.',
      'Understood, stepping back.',
      'Going to sleep. Wake me anytime.',
      'Resting now. Always here if you need me.',
      'All quiet. Standing by.',
      'Standing down. Have a good one.',
    ];
    return _pick(options);
  }

  String getFormFillAck() {
    final options = [
      'Scanning the form fields and autofilling your details now.',
      'Surveying the inputs. Populating your saved credentials.',
      'Analyzing form structure. Entering your details now.',
      'Autofilling form fields with your learned details.',
    ];
    return _pick(options);
  }

  String getFormFillCompletion([int fieldCount = 0]) {
    final countText = fieldCount > 0 ? '$fieldCount fields' : 'the fields';
    final options = [
      'I have populated $countText with your profile information. Please verify before submitting.',
      'Form autofill complete for $countText. Please review before hitting submit.',
      'All set. I entered your details into $countText. Kindly double-check before submitting.',
    ];
    return _pick(options);
  }

  // ---------------------------------------------------------------------------
  // Origin / Identity Knowledge
  // ---------------------------------------------------------------------------

  String getCreatorAnswer() {
    final options = [
      "I'm Geny — an open-source, on-device AI assistant. My architecture, multilingual voice intelligence and autonomous device controls are developed and evolved by the Geny open-source community.",
      "I'm Geny, your personal AI. I'm an open-source project: anyone can inspect my code, contribute, and make me their own.",
      "I'm Geny — crafted as an open-source on-device assistant. No cloud master, no secrets: my whole engineering is public.",
      "I'm Geny — friendly, private and fully yours. I evolved from an open-source assistant project and keep improving with my community.",
    ];
    return _pick(options);
  }

  // ---------------------------------------------------------------------------
  // Executive Personalized Briefing & Rhythms
  // ---------------------------------------------------------------------------

  String getOperatorName() {
    try {
      final userMd = HermesEvolutionService.instance.userMd;
      for (final line in userMd.split('\n')) {
        final clean = line.replaceAll(RegExp(r'^[*\-#\s]+'), '').trim();
        final lower = clean.toLowerCase();
        if (lower.startsWith('name:') || lower.startsWith('identity:')) {
          final val = clean.substring(clean.indexOf(':') + 1).trim();
          final nameOnly = val.replaceAll(RegExp(r'\(.*?\)'), '').trim();
          if (nameOnly.isNotEmpty &&
              !nameOnly.toLowerCase().contains('primary operator') &&
              !nameOnly.toLowerCase().contains('device owner') &&
              !nameOnly.toLowerCase().contains('sir')) {
            return nameOnly;
          }
        }
      }
      for (final f in ConversationalMemoryService.instance.facts) {
        final factLower = f.fact.toLowerCase();
        if (factLower.contains('my name is ')) {
          final name = f.fact.split(RegExp(r'my name is ', caseSensitive: false)).last.trim();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> generateExecutiveGreeting() async {
    final now = DateTime.now();
    final hour = now.hour;
    final String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeGreeting = 'Good evening';
    } else {
      timeGreeting = 'Hello';
    }

    final operatorName = getOperatorName();
    final salutation = operatorName.isNotEmpty ? '$timeGreeting $operatorName' : '$timeGreeting';

    final dayName = DateFormat('EEEE').format(now);
    final dateStr = DateFormat('MMMM d').format(now);
    final timeStr = DateFormat('h:mm a').format(now);

    final parts = <String>[];
    parts.add('$salutation. It is $timeStr on $dayName, $dateStr.');

    // 1. Calendar / Meetings check
    try {
      await CalendarReminderService.instance.init();
      final calendarItems = CalendarReminderService.instance.getTodayItems();
      final meetings = calendarItems.where((i) =>
          !i.isReminder ||
          i.title.toLowerCase().contains('meeting') ||
          i.description.toLowerCase().contains('meeting')).toList();

      if (meetings.isNotEmpty) {
        final topMeeting = meetings.first;
        final mTime = DateFormat('h:mm a').format(topMeeting.dateTime);
        final title = topMeeting.title.trim();
        if (meetings.length == 1) {
          parts.add('Today is your meeting with $title at $mTime.');
        } else {
          parts.add('You have ${meetings.length} meetings scheduled today, starting with $title at $mTime.');
        }
      } else if (calendarItems.isNotEmpty) {
        final topEvent = calendarItems.first;
        final eTime = DateFormat('h:mm a').format(topEvent.dateTime);
        parts.add('You have an upcoming event scheduled today: "${topEvent.title}" at $eTime.');
      }
    } catch (_) {}

    // 2. To-do items check
    try {
      await TodoService.instance.init();
      final pendingTodos = TodoService.instance.pendingItems;

      if (pendingTodos.isNotEmpty) {
        final count = pendingTodos.length;
        final topTasks = pendingTodos.take(2).map((t) => t.title).join(' and ');
        if (count == 1) {
          parts.add('There is one task left in your to-do list: $topTasks.');
        } else {
          parts.add('There are $count tasks left in your to-do list, including $topTasks.');
        }
        parts.add('Would you like me to help with any of these, or anything else?');
      } else if (parts.length > 1) {
        parts.add('All other systems are nominal. How may I assist you?');
      } else {
        parts.add('All systems are operational and your agenda is completely clear. How may I be of service?');
      }
    } catch (_) {
      parts.add('All systems are operational and ready. How may I assist you?');
    }

    return parts.join(' ');
  }
}
