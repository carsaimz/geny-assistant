import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';

enum EmailPriority {
  urgent,
  important,
  actionRequired,
  newsletter,
  low,
}

class EmailTriageResult {
  final EmailPriority priority;
  final String summary;
  final List<String> actionItems;
  final List<String> suggestedReplies;

  const EmailTriageResult({
    required this.priority,
    required this.summary,
    required this.actionItems,
    required this.suggestedReplies,
  });
}

/// Email triage & drafting service:
/// - Summarizes emails into key highlights.
/// - Flags priorities (Urgent, Important, Action Required, Low).
/// - Suggests smart reply options.
/// - Launches native email clients with prefilled drafts.
class EmailTriageService {
  EmailTriageService._();
  static final EmailTriageService instance = EmailTriageService._();

  /// Analyzes and triages email text using LLM synthesis with fast local fallback.
  Future<EmailTriageResult> triageEmail(String emailContent) async {
    final clean = emailContent.trim();
    if (clean.isEmpty) {
      return const EmailTriageResult(
        priority: EmailPriority.low,
        summary: 'No email text provided to analyze.',
        actionItems: [],
        suggestedReplies: [],
      );
    }

    const prompt = '''
You are an expert executive email triage assistant.
Analyze the following email text and extract structured triage metrics:
1. "priority": One of "urgent" | "important" | "action_required" | "newsletter" | "low"
2. "summary": A concise 2-sentence executive summary.
3. "action_items": An array of specific action items or tasks requested.
4. "suggested_replies": An array of 3 distinct, professional email reply drafts (e.g., Acknowledged/Accepting, Polite Decline, Request More Info).

Output ONLY a JSON object:
{
  "priority": "urgent"|"important"|"action_required"|"newsletter"|"low",
  "summary": "...",
  "action_items": ["..."],
  "suggested_replies": ["..."]
}
''';

    try {
      final raw = await AiService.instance.chat(
        message: '$prompt\n\nEMAIL TEXT:\n$clean',
      );
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final decoded = jsonDecode(raw.substring(jsonStart, jsonEnd + 1));
        if (decoded is Map) {
          final priorityStr =
              decoded['priority']?.toString().toLowerCase() ?? 'important';
          EmailPriority pri;
          switch (priorityStr) {
            case 'urgent':
              pri = EmailPriority.urgent;
              break;
            case 'important':
              pri = EmailPriority.important;
              break;
            case 'action_required':
              pri = EmailPriority.actionRequired;
              break;
            case 'newsletter':
              pri = EmailPriority.newsletter;
              break;
            default:
              pri = EmailPriority.low;
          }

          final summary = decoded['summary']?.toString() ?? 'Email analyzed.';
          final actions = (decoded['action_items'] as List?)
                  ?.map((a) => a.toString())
                  .toList() ??
              [];
          final replies = (decoded['suggested_replies'] as List?)
                  ?.map((r) => r.toString())
                  .toList() ??
              [];

          return EmailTriageResult(
            priority: pri,
            summary: summary,
            actionItems: actions,
            suggestedReplies: replies,
          );
        }
      }
    } catch (_) {}

    // Fallback heuristic triage
    final lower = clean.toLowerCase();
    final isUrgent = lower.contains('urgent') ||
        lower.contains('asap') ||
        lower.contains('deadline') ||
        lower.contains('immediately');

    return EmailTriageResult(
      priority: isUrgent ? EmailPriority.urgent : EmailPriority.important,
      summary: clean.length > 200 ? '${clean.substring(0, 200)}...' : clean,
      actionItems: ['Review and respond to message.'],
      suggestedReplies: [
        'Thank you for reaching out. I have received your email and will follow up shortly.',
        'Thank you for the update. Everything looks good on my end.',
      ],
    );
  }

  /// Drafts an email reply and opens it directly in Gmail / default email client.
  Future<bool> openEmailDraft({
    String to = '',
    String subject = '',
    String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

