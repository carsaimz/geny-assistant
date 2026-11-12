import 'dart:convert';

/// One atomic action decided by the LLM (or replayed from skill memory).
///
/// Wire format expected from the model:
/// ```json
/// {
///   "action": "click_text" | "click_at" | "type_text" | "press_enter" |
///             "scroll" | "swipe" | "press_back" | "press_home" |
///             "open_app" | "wait" | "done",
///   "params": { ... },
///   "reasoning": "short explanation",
///   "is_complete": false
/// }
/// ```
class TaskStep {
  static const actionClickText = 'click_text';
  static const actionClickAt = 'click_at';
  static const actionTypeText = 'type_text';
  static const actionPressEnter = 'press_enter';
  static const actionScroll = 'scroll';
  static const actionSwipe = 'swipe';
  static const actionPressBack = 'press_back';
  static const actionPressHome = 'press_home';
  static const actionOpenApp = 'open_app';
  static const actionWait = 'wait';
  static const actionDone = 'done';

  static const supportedActions = <String>{
    actionClickText,
    actionClickAt,
    actionTypeText,
    actionPressEnter,
    actionScroll,
    actionSwipe,
    actionPressBack,
    actionPressHome,
    actionOpenApp,
    actionWait,
    actionDone,
  };

  final String action;
  final Map<String, dynamic> params;
  final String reasoning;
  final bool isComplete;

  const TaskStep({
    required this.action,
    this.params = const {},
    this.reasoning = '',
    this.isComplete = false,
  });

  factory TaskStep.fromJson(Map<dynamic, dynamic> json) {
    var rawAction = (json['action'] ?? '').toString().trim().toLowerCase();
    final rawParams = json['params'];
    final params = rawParams is Map
        ? rawParams.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    // Normalize action aliases commonly produced by various LLM models
    if (rawAction == 'open' ||
        rawAction == 'launch' ||
        rawAction == 'start' ||
        rawAction == 'launch_app' ||
        rawAction == 'openapp') {
      rawAction = actionOpenApp;
      if (!params.containsKey('app')) {
        params['app'] = params['name'] ??
            params['package'] ??
            params['app_name'] ??
            params['target'] ??
            '';
      }
    } else if (rawAction == 'click' ||
        rawAction == 'tap' ||
        rawAction == 'press' ||
        rawAction == 'touch') {
      if (params.containsKey('x') || params.containsKey('y') || params.containsKey('coordinates')) {
        rawAction = actionClickAt;
      } else if (params.containsKey('app')) {
        rawAction = actionOpenApp;
      } else {
        rawAction = actionClickText;
        if (!params.containsKey('text')) {
          params['text'] = params['label'] ??
              params['target'] ??
              params['name'] ??
              params['value'] ??
              '';
        }
      }
    } else if (rawAction == 'type' ||
        rawAction == 'input' ||
        rawAction == 'write' ||
        rawAction == 'enter_text' ||
        rawAction == 'set_text') {
      rawAction = actionTypeText;
      if (!params.containsKey('text')) {
        params['text'] = params['input'] ??
            params['query'] ??
            params['value'] ??
            params['content'] ??
            '';
      }
    } else if (rawAction == 'enter' || rawAction == 'search' || rawAction == 'submit') {
      rawAction = actionPressEnter;
    } else if (rawAction == 'back') {
      rawAction = actionPressBack;
    } else if (rawAction == 'home') {
      rawAction = actionPressHome;
    } else if (rawAction == 'finish' ||
        rawAction == 'complete' ||
        rawAction == 'completed' ||
        rawAction == 'success' ||
        rawAction == 'end') {
      rawAction = actionDone;
    }

    return TaskStep(
      action: rawAction,
      params: params,
      reasoning: (json['reasoning'] ?? '').toString(),
      isComplete: json['is_complete'] == true ||
          json['isComplete'] == true ||
          rawAction == actionDone,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'params': params,
        'reasoning': reasoning,
        'is_complete': isComplete,
      };

  bool get isSupported => supportedActions.contains(action);

  /// Stable signature used by the recovery engine to detect repeated actions.
  String get signature => '$action:${jsonEncode(params)}';

  /// Numeric param with forgiving parsing (int / double / numeric string).
  int? intParam(String key) {
    final v = params[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
    return null;
  }

  String? stringParam(String key) {
    final v = params[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Robustly extracts the first JSON object from raw LLM output, tolerating
  /// markdown fences, leading prose, trailing commentary, and natural language.
  static TaskStep? tryParse(String aiText) {
    var text = aiText.trim();
    if (text.isEmpty) return null;

    // 1. Strip markdown code fences if present.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    final fenceMatch = fence.firstMatch(text);
    if (fenceMatch != null) text = fenceMatch.group(1)!.trim();

    Map<dynamic, dynamic>? decode(String candidate) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map && decoded.containsKey('action')) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
      return null;
    }

    // 2. Direct decode attempt
    var parsed = decode(text);

    // 3. Fall back to scanning for balanced { ... } blocks containing "action"
    if (parsed == null) {
      var start = 0;
      while (start < text.length) {
        final braceStart = text.indexOf('{', start);
        if (braceStart == -1) break;
        int depth = 0;
        int end = -1;
        for (int i = braceStart; i < text.length; i++) {
          if (text[i] == '{') depth++;
          if (text[i] == '}') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        if (end > braceStart) {
          final candidate = text.substring(braceStart, end + 1);
          if (candidate.contains('"action"') || candidate.contains("'action'")) {
            parsed = decode(candidate);
            if (parsed != null) break;
          }
          start = braceStart + 1;
        } else {
          break;
        }
      }
    }

    // 4. Widest balanced { ... } fallback
    if (parsed == null) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        parsed = decode(text.substring(start, end + 1));
      }
    }

    // 5. If JSON was found, return normalized TaskStep
    if (parsed != null) {
      final step = TaskStep.fromJson(parsed);
      if (step.isSupported) return step;
    }

    // 6. Intelligent heuristic fallback for natural language / conversational output from models
    final lower = text.toLowerCase();
    if (lower.contains('open ') || lower.contains('launch ')) {
      final match = RegExp(
        r'(?:open|launch)\s+(?:the\s+)?([a-zA-Z0-9\s]+?)(?:\s+to|\s+app|\s+and|\.|\n|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final app = match.group(1)!.trim();
        if (app.isNotEmpty && app.length < 35) {
          return TaskStep(
            action: actionOpenApp,
            params: {'app': app},
            reasoning: 'Extracted action: open $app',
          );
        }
      }
    }

    if (lower.contains('click ') || lower.contains('tap ') || lower.contains('press ')) {
      final match = RegExp(
        r'(?:click|tap|press)\s+(?:on\s+)?(?:the\s+)?["\x27]?([^"\x27.\n]+)["\x27]?',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        var target = match.group(1)!.trim();
        // Clean up prefixes like [0] (Button) Search -> Search
        target = target
            .replaceAll(RegExp(r'^\([a-zA-Z]+\)\s*'), '')
            .replaceAll(RegExp(r'^\[\d+\]\s*'), '')
            .replaceAll(RegExp(r'^\([a-zA-Z]+\)\s*'), '')
            .replaceAll(RegExp(r'^["\x27\[\(]+|["\x27\]\)]+$'), '')
            .trim();
        if (target.isNotEmpty && target.length < 50) {
          return TaskStep(
            action: actionClickText,
            params: {'text': target},
            reasoning: 'Extracted action: click $target',
          );
        }
      }
    }

    if (lower.contains('type ') || lower.contains('enter ') || lower.contains('search for ')) {
      final match = RegExp(
        r'(?:type|enter|search for)\s+["\x27]?([^"\x27.\n]+)["\x27]?',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final query = match.group(1)!.trim();
        if (query.isNotEmpty && query.length < 50) {
          return TaskStep(
            action: actionTypeText,
            params: {'text': query},
            reasoning: 'Extracted action: type $query',
          );
        }
      }
    }

    if (lower.contains('task complete') ||
        lower.contains('task completed') ||
        lower.contains('goal complete') ||
        lower.contains('successfully installed') ||
        lower.contains('finished')) {
      return const TaskStep(
        action: actionDone,
        reasoning: 'Task marked complete in response',
        isComplete: true,
      );
    }

    return null;
  }

  @override
  String toString() =>
      'TaskStep($action, params=$params, complete=$isComplete)';
}
