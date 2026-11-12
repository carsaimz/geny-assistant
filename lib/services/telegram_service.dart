import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/task_history_entry.dart';
import 'settings_service.dart';

/// Remote control through a Telegram bot.
///
/// Long-polls `getUpdates` in the background while enabled. Incoming text
/// messages from authorized chats are executed as agent tasks; status
/// updates and screenshots are sent back to the chat.
///
/// Authorization model: if [SettingsService.telegramAllowedChats] is empty,
/// the first chat that writes to the bot becomes the remembered owner.
class TelegramService extends ChangeNotifier {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  final http.Client _client = http.Client();

  bool _running = false;
  int _consecutiveErrors = 0;

  bool get isRunning => _running;

  /// Invoked for each incoming command text from an authorized chat.
  void Function(String chatId, String text)? onCommand;

  String get _token => SettingsService.instance.telegramToken;
  String get _api => 'https://api.telegram.org/bot$_token';

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  Future<void> start() async {
    if (_running) return;
    if (_token.isEmpty) return;
    _running = true;
    _consecutiveErrors = 0;
    notifyListeners();
    unawaited(_pollLoop());
  }

  void stop() {
    _running = false;
    notifyListeners();
  }

  Future<void> restart() async {
    stop();
    await Future.delayed(const Duration(milliseconds: 500));
    await start();
  }

  Future<void> _pollLoop() async {
    while (_running) {
      try {
        final offset = SettingsService.instance.telegramUpdateOffset;
        final uri = Uri.parse(
            '$_api/getUpdates?timeout=25&offset=${offset == 0 ? -1 : offset}');
        final res = await _client
            .get(uri)
            .timeout(const Duration(seconds: 35));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        _consecutiveErrors = 0;
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final updates = decoded['result'];
        if (updates is List) {
          for (final update in updates) {
            await _handleUpdate(update);
          }
        }
      } catch (_) {
        if (!_running) break;
        _consecutiveErrors++;
        final backoff = (_consecutiveErrors.clamp(1, 6)) * 5;
        await Future.delayed(Duration(seconds: backoff));
      }
    }
  }

  Future<void> _handleUpdate(dynamic update) async {
    if (update is! Map) return;
    final updateId = update['update_id'];
    if (updateId is int) {
      await SettingsService.instance.setTelegramUpdateOffset(updateId + 1);
    }

    final message = update['message'];
    if (message is! Map) return;
    final chat = message['chat'];
    final chatId = chat is Map ? '${chat['id']}' : null;
    final text = message['text'];
    if (chatId == null || text is! String || text.trim().isEmpty) return;

    final settings = SettingsService.instance;
    final allowed = settings.telegramAllowedChats;
    final owner = settings.telegramOwnerChatId;

    // SECURITY HARDENING: automatic first-contact pairing was removed.
    // A leaked bot token must not let a stranger claim ownership of the
    // device. The owner chat ID must be entered by the user inside
    // Geny's settings, or be part of the explicit allow-list.
    if (allowed.isEmpty && owner.isEmpty) {
      await sendMessage(chatId,
          '🔐 Pairing is disabled for security.\n\n'
          'Open Geny → Settings → Telegram and enter your own Chat ID '
          'to authorize this chat. Your Chat ID: $chatId');
      return;
    }
    final isAuthorized =
        allowed.contains(chatId) || (allowed.isEmpty && chatId == owner);
    if (!isAuthorized) return;

    onCommand?.call(chatId, text.trim());
  }

  // ------------------------------------------------------------------
  // Sending
  // ------------------------------------------------------------------

  Future<bool> sendMessage(String chatId, String text) async {
    if (_token.isEmpty) return false;
    try {
      final res = await _client.post(
        Uri.parse('$_api/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          // Telegram hard limit is 4096 chars.
          'text': text.length > 4000 ? '${text.substring(0, 4000)}…' : text,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends a PNG screenshot (base64) as a photo message.
  Future<bool> sendScreenshot(String chatId, String base64Png,
      {String? caption}) async {
    return sendPhoto(chatId, base64Png, caption: caption ?? 'Geny screenshot');
  }

  /// Sends a photo (base64 string or byte array) to Telegram with custom caption.
  Future<bool> sendPhoto(String chatId, dynamic photoData, {String? caption}) async {
    if (_token.isEmpty) return false;
    try {
      final List<int> bytes = photoData is String
          ? base64Decode(photoData)
          : (photoData as List<int>);
      if (bytes.isEmpty) return false;
      final request = http.MultipartRequest(
          'POST', Uri.parse('$_api/sendPhoto'))
        ..fields['chat_id'] = chatId
        ..fields['caption'] = caption ?? '📸 G.E.N.Y. Photo Telemetry'
        ..files.add(http.MultipartFile.fromBytes(
            'photo', bytes,
            filename: 'snapshot.jpg'));
      final streamed = await _client.send(request);
      return streamed.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Convenience formatter for task-finished push messages.
  String formatTaskResult(TaskHistoryEntry entry) {
    final icon = switch (entry.status) {
      TaskStatus.success => '✅',
      TaskStatus.cancelled => '⏹️',
      TaskStatus.failed => '❌',
    };
    final duration = entry.duration;
    final seconds = duration == null ? '' : ' in ${duration.inSeconds}s';
    return '$icon ${entry.goal}\n'
        'Status: ${entry.status.name} • ${entry.steps} step(s)$seconds';
  }
}
