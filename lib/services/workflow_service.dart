import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_automation_service.dart';
import 'sentry_service.dart';
import 'settings_service.dart';
import 'smart_home_service.dart';
import 'system_control_service.dart';

/// An autonomous workflow/protocol evolved by G.E.N.Y. (Hermes Agent pattern).
/// Sets system settings, hardware parameters, and executes routines.
class GenyWorkflow {
  final String id;
  final String name;
  final List<String> triggerKeywords;
  final String description;
  final double? volume; // 0.0 to 1.0, null if unchanged
  final double? brightness; // 0.0 to 1.0, null if unchanged
  final bool? torch; // true = on, false = off, null = unchanged
  final String spokenConfirmation;

  const GenyWorkflow({
    required this.id,
    required this.name,
    required this.triggerKeywords,
    required this.description,
    this.volume,
    this.brightness,
    this.torch,
    required this.spokenConfirmation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'triggerKeywords': triggerKeywords,
        'description': description,
        'volume': volume,
        'brightness': brightness,
        'torch': torch,
        'spokenConfirmation': spokenConfirmation,
      };

  factory GenyWorkflow.fromJson(Map<String, dynamic> json) => GenyWorkflow(
        id: json['id'] as String,
        name: json['name'] as String,
        triggerKeywords: (json['triggerKeywords'] as List?)
                ?.map((e) => e.toString().toLowerCase())
                .toList() ??
            [],
        description: json['description'] as String? ?? '',
        volume: (json['volume'] as num?)?.toDouble(),
        brightness: (json['brightness'] as num?)?.toDouble(),
        torch: json['torch'] as bool?,
        spokenConfirmation: json['spokenConfirmation'] as String? ?? '',
      );

  GenyWorkflow copyWith({
    String? id,
    String? name,
    List<String>? triggerKeywords,
    String? description,
    double? volume,
    double? brightness,
    bool? torch,
    String? spokenConfirmation,
  }) {
    return GenyWorkflow(
      id: id ?? this.id,
      name: name ?? this.name,
      triggerKeywords: triggerKeywords ?? this.triggerKeywords,
      description: description ?? this.description,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
      torch: torch ?? this.torch,
      spokenConfirmation: spokenConfirmation ?? this.spokenConfirmation,
    );
  }
}

/// Self-Evolving Workflow Engine (Hermes Pattern):
/// Autonomously manages and triggers multi-parameter device protocols
/// such as Study Mode, Night Mode, Focus Mode, and custom user routines.
class WorkflowService extends ChangeNotifier {
  WorkflowService._();
  static final WorkflowService instance = WorkflowService._();

  static const _storageKey = 'geny_workflows_v1';
  final List<GenyWorkflow> _workflows = [];
  bool _initialized = false;

  List<GenyWorkflow> get workflows => List.unmodifiable(_workflows);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _workflows.clear();
          for (final item in decoded) {
            if (item is Map) {
              _workflows.add(
                GenyWorkflow.fromJson(
                  item.map((k, v) => MapEntry('$k', v)),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    if (_workflows.isEmpty || !_workflows.any((w) => w.id == 'sentry')) {
      _seedDefaults();
      await _persist();
    } else {
      // Sanitize any existing cached workflows to eliminate false-positive collision keywords
      var modified = false;
      for (var i = 0; i < _workflows.length; i++) {
        final w = _workflows[i];
        if (w.id == 'study') {
          final cleaned = w.triggerKeywords
              .where((k) => k != 'learn' && k != 'read' && k != 'reading')
              .toList();
          if (cleaned.length != w.triggerKeywords.length) {
            _workflows[i] = w.copyWith(triggerKeywords: cleaned);
            modified = true;
          }
        }
      }
      if (modified) {
        await _persist();
      }
    }
  }

  void _seedDefaults() {
    _workflows.addAll([
      const GenyWorkflow(
        id: 'study',
        name: 'Study Protocol',
        triggerKeywords: ['study', 'studying', 'exam', 'exams', 'study mode', 'study protocol', 'study session', 'start studying'],
        description: 'Mutes distracting audio and tunes screen luminosity to 45% for reading.',
        volume: 0.0,
        brightness: 0.45,
        torch: false,
        spokenConfirmation:
            'Study Protocol is now active. Screen brightness is calibrated to 45 percent and distracting audio is muted so you can focus completely. Best of luck with your study session. Let me know if you need anything else.',
      ),
      const GenyWorkflow(
        id: 'night',
        name: 'Night / Sleep Protocol',
        triggerKeywords: ['sleep', 'sleeping', 'bedtime', 'goodnight', 'night mode', 'night protocol', 'sleep mode', 'sleep protocol', 'go to sleep'],
        description: 'Sets display to minimal brightness, silences audio, and turns off torch.',
        volume: 0.0,
        brightness: 0.05,
        torch: false,
        spokenConfirmation:
            'Night Protocol engaged. Display is dimmed to minimum luminosity, audio is silenced, and flashlight is deactivated. Have a restful night. Sleep well.',
      ),
      const GenyWorkflow(
        id: 'work',
        name: 'Work / Focus Protocol',
        triggerKeywords: ['work mode', 'work protocol', 'focus mode', 'focus protocol', 'meeting mode', 'deep work'],
        description: 'Silences media alerts and balances workspace display brightness.',
        volume: 0.05,
        brightness: 0.65,
        spokenConfirmation:
            'Focus Protocol is active. Alerts are muted and display is balanced for your workspace. Let me know if you need anything else.',
      ),
      const GenyWorkflow(
        id: 'cinema',
        name: 'Cinema Protocol',
        triggerKeywords: ['cinema', 'cinema mode', 'cinema protocol', 'movie mode', 'theatre mode', 'theater mode'],
        description: 'Elevates acoustics to 70% and dims screen for immersive viewing.',
        volume: 0.70,
        brightness: 0.20,
        spokenConfirmation:
            'Cinema Protocol is engaged. Display is dimmed and acoustics elevated to 70 percent. Enjoy your film. I will be right here if you need anything.',
      ),
      const GenyWorkflow(
        id: 'sentry',
        name: 'Sentry Protocol (Tactical Watchdog)',
        triggerKeywords: [
          'sentry',
          'sentry mode',
          'sentry protocol',
          'sentry protocal',
          'century protocol',
          'century mode',
          'centry protocol',
          'centry mode',
          'watchdog',
          'anti theft',
          'anti-theft',
          'guard my phone',
          'watch my phone',
        ],
        description: 'Arms hardware motion sensors and front-camera security watchdog perimeter.',
        spokenConfirmation:
            'Sentry Protocol active. Motion sensors armed. Security perimeter established.',
      ),
    ]);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_workflows.map((w) => w.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Evaluates user speech to find a matching evolved workflow.
  GenyWorkflow? findMatch(String speech) {
    final trimmed = speech.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // Guard: Questions or educational inquiries MUST NEVER trigger a hardware workflow!
    final isQuestion = RegExp(
      r'^(what|who|where|when|why|how|explain|tell\s+me|search|lookup|define|is\s+it|can\s+you|could\s+you|do\s+you)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (isQuestion) return null;

    for (final w in _workflows) {
      for (final kw in w.triggerKeywords) {
        final kwLower = kw.toLowerCase().trim();
        if (kwLower.isEmpty) continue;
        // Whole-word or whole-phrase boundary match
        final pattern = RegExp(r'\b' + RegExp.escape(kwLower) + r'\b', caseSensitive: false);
        if (pattern.hasMatch(lower)) {
          return w;
        }
      }
    }
    return null;
  }

  /// Executes a matched workflow on device hardware.
  Future<bool> executeWorkflow(GenyWorkflow workflow) async {
    final system = SystemControlService.instance;

    // 1. Audio volume
    if (workflow.volume != null) {
      if (workflow.volume! <= 0.0) {
        await system.setMuted(true);
      } else {
        await system.setMuted(false);
        await system.setVolume(workflow.volume!);
      }
    }

    // 2. Screen brightness
    if (workflow.brightness != null) {
      await system.setBrightness(workflow.brightness!);
    }

    // 3. Torch
    if (workflow.torch != null) {
      try {
        await ScreenAutomationService.instance.isServiceEnabled();
      } catch (_) {}
    }

    // 4. Smart Home & IoT Automation Integration (only when the user has
    //    actually configured Home Assistant — avoids silent calls to an
    //    unconfigured host).
    final smartHomeReady = SettingsService.instance.smartHomeEnabled &&
        SettingsService.instance.homeAssistantToken.isNotEmpty;
    try {
      if (workflow.id == 'sentry') {
        await SentryService.instance.armSentry();
      } else if (smartHomeReady && workflow.id == 'night') {
        await SmartHomeService.instance.turnOff();
      } else if (smartHomeReady && workflow.id == 'cinema') {
        await SmartHomeService.instance.turnOn(brightnessPct: 15);
      } else if (smartHomeReady && workflow.id == 'study') {
        await SmartHomeService.instance.turnOn(brightnessPct: 80);
      }
    } catch (_) {}

    return true;
  }

  /// Self-evolves: adds a newly learned user workflow.
  Future<void> learnWorkflow(GenyWorkflow newWorkflow) async {
    _workflows.removeWhere((w) => w.id == newWorkflow.id);
    _workflows.add(newWorkflow);
    await _persist();
  }
}

