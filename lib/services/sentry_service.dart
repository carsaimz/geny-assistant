import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'personality_service.dart';
import 'settings_service.dart';
import 'telegram_service.dart';
import 'voice_service.dart';

/// Tactical Sentry Mode Anti-Theft Watchdog:
/// Uses device motion sensors to detect unauthorized phone handling,
/// captures silent front-camera telemetry, alerts the room,
/// and dispatches the intruder snapshot to the user's paired Telegram terminal.
class SentryService extends ChangeNotifier {
  SentryService._();
  static final SentryService instance = SentryService._();

  static const MethodChannel _channel = MethodChannel('com.privateagent/accessibility');

  bool _isArmed = false;
  bool get isArmed => _isArmed;

  bool _breachDetected = false;
  bool get breachDetected => _breachDetected;

  String? _lastBreachPhotoBase64;
  String? get lastBreachPhotoBase64 => _lastBreachPhotoBase64;

  DateTime? _lastBreachTime;
  DateTime? get lastBreachTime => _lastBreachTime;

  /// Handles incoming native sentry call dispatched by [NativeBridgeService].
  Future<void> handleNativeCall(MethodCall call) async {
    if (call.method == 'onSentryMovementDetected') {
      final args = call.arguments as Map?;
      final b64 = args?['base64']?.toString() ?? '';
      await _handleBreach(b64);
    }
  }

  Future<bool> armSentry() async {
    try {
      final success = await _channel.invokeMethod<bool>('startSentryMode') ?? false;
      _isArmed = success;
      _breachDetected = false;
      notifyListeners();

      if (success) {
        final msg = PersonalityService.instance.getSentryAck(arm: true);
        await VoiceService.instance.speak(msg);
      }
      return success;
    } catch (e) {
      debugPrint('[SentryService] Arm failed: $e');
      _isArmed = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> disarmSentry() async {
    try {
      await _channel.invokeMethod('stopSentryMode');
    } catch (e) {
      debugPrint('[SentryService] stopSentryMode channel warning: $e');
    }
    _isArmed = false;
    _breachDetected = false;
    notifyListeners();

    final msg = PersonalityService.instance.getSentryAck(arm: false);
    await VoiceService.instance.speak(msg);
    return true;
  }

  Future<void> toggleSentry() async {
    if (_isArmed) {
      await disarmSentry();
    } else {
      await armSentry();
    }
  }

  Future<void> _handleBreach(String photoBase64) async {
    if (!_isArmed) return;
    _breachDetected = true;
    _lastBreachPhotoBase64 = photoBase64.isNotEmpty ? photoBase64 : null;
    _lastBreachTime = DateTime.now();
    notifyListeners();

    HapticFeedback.heavyImpact();

    // 1. Imposing vocal deterrence (accurate: it states exactly what happens)
    const alertSpeech =
        'Security violation detected. Photo captured and sent to your paired Telegram terminal.';
    unawaited(VoiceService.instance.speak(alertSpeech));

    // 2. Dispatch photo & breach coordinates to connected Telegram terminal
    final settings = SettingsService.instance;
    final ownerChat = settings.telegramOwnerChatId;
    if (ownerChat.isNotEmpty) {
      final timeFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final caption = '🚨 *G.E.N.Y. SENTRY ALERT*\n'
          '⚠️ *Unauthorized Movement Detected!*\n'
          '⏱ *Timestamp*: $timeFormatted\n'
          '🛡 *Status*: Intruder snapshot acquired & logged.';

      if (photoBase64.isNotEmpty) {
        await TelegramService.instance.sendPhoto(ownerChat, photoBase64, caption: caption);
      } else {
        await TelegramService.instance.sendMessage(ownerChat, caption);
      }
    }
  }
}

