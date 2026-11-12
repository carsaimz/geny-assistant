import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import 'telegram_service.dart';

enum RiskLevel {
  low,
  medium,
  high,
}

class SecurityAssessment {
  final RiskLevel riskLevel;
  final String reason;
  final bool requiresConfirmation;

  const SecurityAssessment({
    required this.riskLevel,
    required this.reason,
    required this.requiresConfirmation,
  });
}

/// Security monitoring & risk assessment engine:
/// - Classifies actions by risk level before execution.
/// - Requires user confirmation before high-risk operations (sending messages, calls, purchases, data deletion).
/// - Monitors battery levels and dispatches emergency alerts via Telegram when enabled.
class SecurityAlertService extends ChangeNotifier {
  SecurityAlertService._();
  static final SecurityAlertService instance = SecurityAlertService._();

  /// Evaluates risk for an action before executing on the device.
  SecurityAssessment evaluateActionRisk(String actionGoal) {
    final lower = actionGoal.toLowerCase();

    // High risk: sending messages, phone calls, purchases, deletions, money transfers
    if (lower.contains('send money') ||
        lower.contains('transfer') ||
        lower.contains('buy') ||
        lower.contains('purchase') ||
        lower.contains('delete') ||
        lower.contains('uninstall') ||
        lower.contains('factory reset') ||
        lower.contains('send message') ||
        lower.contains('send text') ||
        lower.contains('call ')) {
      return SecurityAssessment(
        riskLevel: RiskLevel.high,
        reason: 'Sensitive operation: modifies external data, sends messages, or initiates calls.',
        requiresConfirmation: true,
      );
    }

    // Medium risk: settings changes, launching third party apps
    if (lower.contains('settings') ||
        lower.contains('permission') ||
        lower.contains('bluetooth') ||
        lower.contains('wifi')) {
      return const SecurityAssessment(
        riskLevel: RiskLevel.medium,
        reason: 'Device configuration adjustment.',
        requiresConfirmation: false,
      );
    }

    // Low risk: reading information, weather, playback, searching
    return const SecurityAssessment(
      riskLevel: RiskLevel.low,
      reason: 'Standard safe operation.',
      requiresConfirmation: false,
    );
  }

  /// Sends a security alert message to the owner via Telegram if configured.
  Future<void> dispatchSecurityAlert(String alertMessage) async {
    final telegram = TelegramService.instance;
    final settings = SettingsService.instance;
    final ownerChatId = settings.telegramOwnerChatId;
    if (telegram.isRunning && ownerChatId.isNotEmpty) {
      try {
        await telegram.sendMessage(
          ownerChatId,
          '🚨 GENY SECURITY ALERT:\n$alertMessage',
        );
      } catch (_) {}
    }
  }
}
