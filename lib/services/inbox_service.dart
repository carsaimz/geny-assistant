import 'package:flutter/services.dart';

import 'email_triage_service.dart';

/// A single SMS message from the device inbox.
class SmsMessage {
  final String id;
  final String sender;
  final String body;
  final DateTime date;
  final bool isRead;

  const SmsMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.date,
    this.isRead = false,
  });

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) {
    final rawDate = map['date'] ?? map['timestamp'];
    DateTime parsedDate;
    if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is num) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt());
    } else {
      parsedDate = DateTime.now();
    }

    return SmsMessage(
      id: map['id']?.toString() ?? '',
      sender: map['sender']?.toString() ?? (map['title']?.toString() ?? 'Unknown'),
      body: map['body']?.toString() ?? (map['text']?.toString() ?? ''),
      date: parsedDate,
      isRead: map['isRead'] == true,
    );
  }
}

/// A captured email message or email notification from Gmail/Outlook/etc.
class EmailMessage {
  final String id;
  final String package;
  final String senderOrTitle;
  final String bodyOrSnippet;
  final String subText;
  final DateTime timestamp;

  const EmailMessage({
    required this.id,
    required this.package,
    required this.senderOrTitle,
    required this.bodyOrSnippet,
    this.subText = '',
    required this.timestamp,
  });

  factory EmailMessage.fromMap(Map<dynamic, dynamic> map) {
    final rawTime = map['timestamp'];
    DateTime parsedTime;
    if (rawTime is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is num) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt());
    } else {
      parsedTime = DateTime.now();
    }

    return EmailMessage(
      id: map['id']?.toString() ?? '',
      package: map['package']?.toString() ?? '',
      senderOrTitle: map['title']?.toString() ?? 'Email',
      bodyOrSnippet: map['text']?.toString() ?? '',
      subText: map['subText']?.toString() ?? '',
      timestamp: parsedTime,
    );
  }
}

/// Inbox access service:
/// 1. Reads incoming SMS messages directly from the device's telephony inbox.
/// 2. Reads incoming email notifications from Gmail, Outlook, Yahoo, etc.
/// 3. Generates concise spoken executive summaries for G.E.N.Y.
class InboxService {
  InboxService._();
  static final InboxService instance = InboxService._();

  static const MethodChannel _channel =
      MethodChannel('com.privateagent/accessibility');

  /// Fetches the recent SMS inbox messages.
  Future<List<SmsMessage>> getSmsInbox({int limit = 15}) async {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'getSmsMessages',
        {'limit': limit},
      );
      if (list == null || list.isEmpty) return const [];
      return list.map((m) => SmsMessage.fromMap(m)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches recent email notifications from active stream.
  Future<List<EmailMessage>> getEmailInbox({int limit = 15}) async {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'getEmailNotifications',
        {'limit': limit},
      );
      if (list == null || list.isEmpty) return const [];
      return list.map((m) => EmailMessage.fromMap(m)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Generates a spoken executive summary of recent SMS messages.
  Future<String> getSmsSummary({int limit = 5}) async {
    final messages = await getSmsInbox(limit: limit);
    if (messages.isEmpty) {
      return 'You have no recent SMS messages in your inbox.';
    }

    final buffer = StringBuffer();
    buffer.writeln('You have ${messages.length} recent text messages.');
    for (int i = 0; i < messages.take(3).length; i++) {
      final m = messages[i];
      final preview = m.body.length > 90 ? '${m.body.substring(0, 90)}...' : m.body;
      buffer.writeln('${i + 1}: From ${m.sender}: "$preview"');
    }
    return buffer.toString().trim();
  }

  /// Generates a spoken executive summary of incoming emails.
  Future<String> getEmailSummary({int limit = 5}) async {
    final emails = await getEmailInbox(limit: limit);
    if (emails.isEmpty) {
      return 'No active email alerts in your inbox notification stream. All clear.';
    }

    final top = emails.first;
    final triage = await EmailTriageService.instance.triageEmail(
      'From: ${top.senderOrTitle}\n${top.bodyOrSnippet}',
    );

    return 'You have ${emails.length} new email notifications. Most recent from ${top.senderOrTitle}: "${top.bodyOrSnippet}". Triage priority is ${triage.priority.name}.';
  }

  /// Checks if Notification Listener Service is authorized.
  Future<bool> isNotificationListenerEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Notification Listener Access page.
  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationListenerSettings');
    } catch (_) {}
  }

  /// Opens overlay settings.
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } catch (_) {}
  }

  /// Opens battery optimization settings.
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }
}
