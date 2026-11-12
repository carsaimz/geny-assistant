import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'app.dart';
import 'overlay/overlay_app.dart';
import 'services/calendar_reminder_service.dart';
import 'services/hermes_evolution_service.dart';
import 'services/geny_service.dart';
import 'services/local_llm_service.dart';
import 'services/native_bridge_service.dart';
import 'services/screen_automation_service.dart';
import 'services/sentry_service.dart';
import 'services/settings_service.dart';
import 'services/task_executor.dart';
import 'services/telegram_service.dart';
import 'services/todo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NativeBridgeService.instance.init();

  final settings = SettingsService.instance;
  await settings.init();

  final executor = TaskExecutor.instance;
  await executor.init();

  await HermesEvolutionService.instance.init();
  await CalendarReminderService.instance.init();
  await TodoService.instance.init();
  // On-device AI (offline mode): reload the previously downloaded model if any.
  await LocalLlmService.instance.init();

  if (settings.genyAlwaysOn) {
    GenyService.instance.ensureAlwaysOnRunning();
  }

  _wireTelegram(executor, settings);
  _wireOverlayCommands(executor);

  runApp(const GenyApp());
}

/// Telegram bot -> task executor wiring.
void _wireTelegram(TaskExecutor executor, SettingsService settings) {
  final telegram = TelegramService.instance;

  telegram.onCommand = (chatId, text) async {
    final lower = text.toLowerCase();
    if (lower == '/status') {
      final running = executor.isBusy
          ? 'Running "${executor.currentGoal}" (step ${executor.step})'
          : 'Idle';
      final serviceOn =
          await ScreenAutomationService.instance.isServiceEnabled();
      await telegram.sendMessage(chatId,
          '📱 $running\nAccessibility service: ${serviceOn ? 'ON ✅' : 'OFF ❌'}');
      return;
    }
    if (lower == '/screenshot') {
      final shot =
          await ScreenAutomationService.instance.takeScreenshotBase64();
      if (shot == null) {
        await telegram.sendMessage(chatId, '⚠️ Screenshot failed.');
      } else {
        await telegram.sendScreenshot(chatId, shot);
      }
      return;
    }
    if (lower == '/cancel' || lower == '/stop') {
      if (executor.isBusy) {
        executor.cancel();
        await telegram.sendMessage(chatId, '⏹️ Cancelling current task…');
      } else {
        await telegram.sendMessage(chatId, 'Nothing is running.');
      }
      return;
    }
    if (executor.isBusy) {
      await telegram.sendMessage(
          chatId, '⏳ Busy with another task. Send /cancel to stop it.');
      return;
    }
    await telegram.sendMessage(chatId, '🚀 Starting task: $text');
    unawaited(executor.executeTask(text, telegramChatId: chatId));
  };

  // Push the final result (plus screenshot) back to the originating chat.
  executor.onTaskFinished = (chatId, entry) async {
    await telegram.sendMessage(chatId, telegram.formatTaskResult(entry));
    final shot = await ScreenAutomationService.instance.takeScreenshotBase64();
    if (shot != null) {
      await telegram.sendScreenshot(chatId, shot,
          caption: 'Final screen state');
    }
  };

  if (settings.telegramEnabled) {
    unawaited(telegram.start());
  }
}

/// Commands coming from the floating overlay bubble/panel.
void _wireOverlayCommands(TaskExecutor executor) {
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event is! String) return;
    Map<String, dynamic> decoded;
    try {
      final d = jsonDecode(event);
      if (d is! Map) return;
      decoded = d.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      return;
    }
    if (decoded['type'] != 'command') return;
    switch (decoded['command']) {
      case 'start':
        final goal = decoded['goal']?.toString().trim() ?? '';
        if (goal.isNotEmpty && !executor.isBusy) {
          unawaited(executor.executeTask(goal));
        }
        break;
      case 'pause':
        executor.pause();
        break;
      case 'resume':
        executor.resume();
        break;
      case 'cancel':
        executor.cancel();
        break;
      case 'summarize_screen':
        unawaited(GenyService.instance.processCommand('summarize this screen article'));
        break;
      case 'geny_command':
        final goal = decoded['goal']?.toString().trim() ?? '';
        if (goal.isNotEmpty) {
          unawaited(GenyService.instance.processCommand(goal));
        }
        break;
      case 'toggle_sentry':
        unawaited(SentryService.instance.toggleSentry());
        break;
    }
  });
}

/// Entry point for the floating overlay window (separate Flutter engine
/// running in its own isolate). Must stay a top-level function annotated
/// with vm:entry-point.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
