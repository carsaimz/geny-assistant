import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'calendar_reminder_service.dart';
import 'geny_tools_service.dart';
import 'message_drafting_service.dart';
import 'notes_knowledge_service.dart';
import 'system_control_service.dart';
import 'todo_service.dart';

/// Single atomic task extracted from a chaotic user brain dump.
class DecoupledTask {
  final String type; // reminder, draft, todo, note, calculate, system
  final String description;
  final Map<String, dynamic> params;
  String executionStatus;
  String? resultSummary;

  DecoupledTask({
    required this.type,
    required this.description,
    required this.params,
    this.executionStatus = 'pending',
    this.resultSummary,
  });
}

/// 🧠 "Chaotic Brain Dump" Multi-Task Decoupler Service (The 30-Second Life Sorter)
///
/// Disassembles rambling, unstructured streams of multiple simultaneous requests
/// into discrete parallel tasks, dispatches them across system services,
/// and returns a unified executive resolution summary.
class MultiTaskDecouplerService extends ChangeNotifier {
  MultiTaskDecouplerService._();
  static final MultiTaskDecouplerService instance = MultiTaskDecouplerService._();

  bool _isProcessing = false;
  List<DecoupledTask> _lastExecutedTasks = [];

  bool get isProcessing => _isProcessing;
  List<DecoupledTask> get lastExecutedTasks => List.unmodifiable(_lastExecutedTasks);

  /// Checks if query is likely a chaotic multi-task brain dump.
  bool isMultiTaskDump(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('brain dump') ||
        lower.startsWith('process this dump') ||
        lower.startsWith('decouple:') ||
        lower.startsWith('multitask:') ||
        lower.startsWith('multi-task:') ||
        lower.startsWith('multi task ')) {
      return true;
    }

    // Check for multiple distinct imperative verbs
    int verbCount = 0;
    if (RegExp(r'\b(remind|schedule|calendar)\b').hasMatch(lower)) verbCount++;
    if (RegExp(r'\b(draft|text|whatsapp|email|message)\b').hasMatch(lower)) verbCount++;
    if (RegExp(r'\b(todo|to-do|task|buy|list)\b').hasMatch(lower)) verbCount++;
    if (RegExp(r'\b(note|write down|remember that)\b').hasMatch(lower)) verbCount++;
    if (RegExp(r'\b(calculate|math|percent|tip)\b').hasMatch(lower)) verbCount++;
    if (RegExp(r'\b(flashlight|torch|volume|brightness|mute|screenshot)\b').hasMatch(lower)) verbCount++;

    return verbCount >= 2 && (lower.contains(' and ') || lower.contains(', '));
  }

  /// Deconstructs and executes chaotic voice dump in parallel.
  Future<String> processBrainDump(String rawInput) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final prompt = '''
You are the Chaotic Brain Dump Multi-Task Decoupler module of G.E.N.Y.
Deconstruct the following rambling user statement into discrete atomic tasks.

Allowed task types:
1. "reminder": { "title": "Call Jack", "time": "4:00 PM" }
2. "draft": { "recipient": "Sarah", "platform": "whatsapp", "message": "I'll be 15 minutes late" }
3. "todo": { "title": "Buy milk and eggs", "priority": "medium" }
4. "note": { "title": "Meeting points", "body": "Discuss Q3 goals" }
5. "calculate": { "expression": "25% of 140", "answer": "35 (total 175)" }
6. "system": { "action": "turn on flashlight" }

Input:
"""$rawInput"""

Respond ONLY with valid JSON array:
[
  {
    "type": "reminder",
    "description": "Set reminder for Jack at 4:00 PM",
    "params": { "title": "Call Jack", "time": "16:00" }
  },
  ...
]
''';

      final response = await AiService.instance.generateResponse(prompt);
      final parsed = AiService.instance.parseLenientJsonArray(response);

      final tasks = parsed.map((item) {
        final map = item is Map ? item : <String, dynamic>{};
        return DecoupledTask(
          type: (map['type'] ?? 'general').toString().toLowerCase(),
          description: (map['description'] ?? 'Atomic task').toString(),
          params: map['params'] is Map ? Map<String, dynamic>.from(map['params'] as Map) : {},
        );
      }).toList();

      _lastExecutedTasks = tasks;

      // Execute all decoupled tasks in parallel
      final executionFutures = tasks.map((task) async {
        try {
          switch (task.type) {
            case 'reminder':
              final title = (task.params['title'] ?? task.description).toString();
              await CalendarReminderService.instance.addReminder(title);
              task.executionStatus = 'success';
              task.resultSummary = 'Reminder scheduled: $title';
              break;

            case 'draft':
              final recipient = (task.params['recipient'] ?? 'Contact').toString();
              final msg = (task.params['message'] ?? '').toString();
              await MessageDraftingService.instance.prepareDraft(
                recipient: recipient,
                platform: (task.params['platform'] ?? 'whatsapp').toString(),
                draftText: msg,
              );
              task.executionStatus = 'success';
              task.resultSummary = 'Draft prepped for $recipient: "$msg"';
              break;

            case 'todo':
              final title = (task.params['title'] ?? task.description).toString();
              await TodoService.instance.addTodo(title, priority: 'medium');
              task.executionStatus = 'success';
              task.resultSummary = 'Added to todo list: $title';
              break;

            case 'note':
              final title = (task.params['title'] ?? 'Quick Note').toString();
              final body = (task.params['body'] ?? task.description).toString();
              await NotesKnowledgeService.instance.addNote(title: title, content: body);
              task.executionStatus = 'success';
              task.resultSummary = 'Note saved: $title';
              break;

            case 'calculate':
              final ans = (task.params['answer'] ?? task.params['expression'] ?? 'Solved').toString();
              task.executionStatus = 'success';
              task.resultSummary = 'Calculation resolved: $ans';
              break;

            case 'system':
            case 'device':
              final act = (task.params['action'] ?? task.params['command'] ?? task.description).toString().toLowerCase();
              if (act.contains('torch') || act.contains('flashlight')) {
                final turnOn = !act.contains('off') && !act.contains('disable');
                await GenyToolsService.instance.setTorch(turnOn);
                task.executionStatus = 'success';
                task.resultSummary = turnOn ? 'Flashlight illuminated' : 'Flashlight deactivated';
              } else if (act.contains('volume up') || act.contains('louder') || act.contains('increase volume')) {
                await SystemControlService.instance.volumeUp();
                task.executionStatus = 'success';
                task.resultSummary = 'Volume increased';
              } else if (act.contains('volume down') || act.contains('quieter') || act.contains('lower volume')) {
                await SystemControlService.instance.volumeDown();
                task.executionStatus = 'success';
                task.resultSummary = 'Volume decreased';
              } else if (act.contains('mute') || act.contains('silence')) {
                await SystemControlService.instance.setMuted(true);
                task.executionStatus = 'success';
                task.resultSummary = 'Acoustics muted';
              } else if (act.contains('screenshot')) {
                await SystemControlService.instance.takeScreenshot();
                task.executionStatus = 'success';
                task.resultSummary = 'Screenshot captured';
              } else {
                task.executionStatus = 'completed';
                task.resultSummary = 'Directive acknowledged: $act';
              }
              break;

            default:
              task.executionStatus = 'completed';
              task.resultSummary = task.description;
          }
        } catch (e) {
          task.executionStatus = 'failed';
          task.resultSummary = 'Execution error on: ${task.description}';
        }
      });

      await Future.wait(executionFutures);

      final sb = StringBuffer();
      sb.write('Multi-task dump decoupled and executed: ');
      for (int i = 0; i < tasks.length; i++) {
        sb.write('${i + 1}) ${tasks[i].resultSummary}. ');
      }

      return sb.toString().trim();
    } catch (e) {
      return 'Disassembled your input, but encountered an execution hiccup: $e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
