import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';

enum MessageChannel { whatsapp, sms, email }

class MessageDraft {
  final MessageChannel channel;
  final String recipient;
  final String subject;
  final String body;

  const MessageDraft({
    required this.channel,
    required this.recipient,
    this.subject = '',
    required this.body,
  });
}

/// Message drafting and instant dispatch service for WhatsApp, SMS, and Email.
class MessageDraftingService {
  MessageDraftingService._();
  static final MessageDraftingService instance = MessageDraftingService._();

  /// Uses AI to craft a polished, tone-appropriate message draft.
  Future<String> draftMessageContent({
    required String prompt,
    String tone = 'friendly and professional',
  }) async {
    final aiPrompt = '''
You are an expert communication assistant.
Draft a concise, natural message based on this request:
"$prompt"
Tone requirement: $tone.
Write ONLY the exact message text to be sent — no greeting to the user, no explanations, no quotation marks.
''';

    try {
      final reply = await AiService.instance.chat(message: aiPrompt);
      return reply.trim().replaceAll(RegExp(r'^"|"$'), '');
    } catch (_) {
      return prompt;
    }
  }

  /// Helper to prepare and launch drafted message intent directly.
  Future<MessageDraft> prepareDraft({
    required String recipient,
    required String platform,
    required String draftText,
  }) async {
    final channel = platform.toLowerCase() == 'sms'
        ? MessageChannel.sms
        : (platform.toLowerCase() == 'email'
            ? MessageChannel.email
            : MessageChannel.whatsapp);
    final draft = MessageDraft(
      channel: channel,
      recipient: recipient,
      body: draftText,
      subject: 'Draft for $recipient: $draftText',
    );
    await dispatchDraft(draft);
    return draft;
  }

  /// Dispatches the drafted message through the selected platform intent.
  Future<bool> dispatchDraft(MessageDraft draft) async {
    Uri uri;
    switch (draft.channel) {
      case MessageChannel.whatsapp:
        final cleanPhone = draft.recipient.replaceAll(RegExp(r'[^\d+]'), '');
        final encodedBody = Uri.encodeComponent(draft.body);
        uri = cleanPhone.isNotEmpty
            ? Uri.parse('https://wa.me/$cleanPhone?text=$encodedBody')
            : Uri.parse('whatsapp://send?text=$encodedBody');
        break;

      case MessageChannel.sms:
        final cleanPhone = draft.recipient.replaceAll(RegExp(r'[^\d+]'), '');
        final encodedBody = Uri.encodeComponent(draft.body);
        uri = Uri.parse('sms:$cleanPhone?body=$encodedBody');
        break;

      case MessageChannel.email:
        uri = Uri(
          scheme: 'mailto',
          path: draft.recipient,
          queryParameters: {
            if (draft.subject.isNotEmpty) 'subject': draft.subject,
            if (draft.body.isNotEmpty) 'body': draft.body,
          },
        );
        break;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

