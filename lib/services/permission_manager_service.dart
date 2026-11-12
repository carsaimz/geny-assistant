import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

import 'inbox_service.dart';
import 'screen_automation_service.dart';

enum AppPermissionType {
  microphone,
  sms,
  contacts,
  notifications,
  accessibility,
  overlay,
  notificationListener,
  batteryOptimization,
}

class AppPermissionInfo {
  final AppPermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final bool isSystemSettingsOnly;

  const AppPermissionInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    this.isSystemSettingsOnly = false,
  });
}

/// Centralized permissions manager that audits and requests all Android permissions
/// for hands-free voice, SMS inbox, email triage, and device automation.
class PermissionManagerService extends ChangeNotifier {
  PermissionManagerService._();
  static final PermissionManagerService instance = PermissionManagerService._();

  List<AppPermissionInfo> _permissions = [];
  bool _isLoading = false;

  List<AppPermissionInfo> get permissions => List.unmodifiable(_permissions);
  bool get isLoading => _isLoading;

  int get grantedCount => _permissions.where((p) => p.isGranted).length;
  int get totalCount => _permissions.length;

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    final micStatus = await Permission.microphone.isGranted;
    final smsStatus = await Permission.sms.isGranted;
    final contactsStatus = await Permission.contacts.isGranted;
    final notifStatus = await Permission.notification.isGranted;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.isGranted;

    final accessibilityStatus =
        await ScreenAutomationService.instance.isServiceEnabled();
    final overlayStatus =
        await FlutterOverlayWindow.isPermissionGranted();
    final notifListenerStatus =
        await InboxService.instance.isNotificationListenerEnabled();

    _permissions = [
      AppPermissionInfo(
        type: AppPermissionType.microphone,
        title: 'Microphone & Voice Input',
        description: 'Enables "Hey Geny" wake word detection and hands-free desk mode listening.',
        icon: Icons.mic_rounded,
        isGranted: micStatus,
      ),
      AppPermissionInfo(
        type: AppPermissionType.sms,
        title: 'SMS Inbox & Messaging',
        description: 'Allows reading incoming SMS messages, verification codes, and drafting text replies.',
        icon: Icons.sms_outlined,
        isGranted: smsStatus,
      ),
      AppPermissionInfo(
        type: AppPermissionType.contacts,
        title: 'Contacts Access',
        description: 'Resolves names for voice commands like "Text John" or "Call Mom".',
        icon: Icons.contacts_outlined,
        isGranted: contactsStatus,
      ),
      AppPermissionInfo(
        type: AppPermissionType.notificationListener,
        title: 'Email & Notification Access',
        description: 'Enables live incoming email triage and notification summaries for Gmail & Outlook.',
        icon: Icons.mark_email_unread_outlined,
        isGranted: notifListenerStatus,
        isSystemSettingsOnly: true,
      ),
      AppPermissionInfo(
        type: AppPermissionType.accessibility,
        title: 'Accessibility Service',
        description: 'Empowers Geny to tap, type, scroll, and execute autonomous tasks across apps.',
        icon: Icons.accessibility_new_rounded,
        isGranted: accessibilityStatus,
        isSystemSettingsOnly: true,
      ),
      AppPermissionInfo(
        type: AppPermissionType.overlay,
        title: 'Display Over Other Apps',
        description: 'Allows the floating holographic bubble and transcript panel over other applications.',
        icon: Icons.layers_outlined,
        isGranted: overlayStatus,
        isSystemSettingsOnly: true,
      ),
      AppPermissionInfo(
        type: AppPermissionType.notifications,
        title: 'System Notifications',
        description: 'Sends calendar alerts, daily morning briefings, and background status updates.',
        icon: Icons.notifications_active_outlined,
        isGranted: notifStatus,
      ),
      AppPermissionInfo(
        type: AppPermissionType.batteryOptimization,
        title: 'Unrestricted Background Battery',
        description: 'Prevents Android OS from sleeping or terminating continuous listening in desk mode.',
        icon: Icons.battery_charging_full_rounded,
        isGranted: batteryStatus,
        isSystemSettingsOnly: true,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  /// Requests or navigates to the setting for a specific permission.
  Future<bool> requestPermission(AppPermissionType type) async {
    switch (type) {
      case AppPermissionType.microphone:
        final status = await Permission.microphone.request();
        await refresh();
        return status.isGranted;

      case AppPermissionType.sms:
        final status = await Permission.sms.request();
        await refresh();
        return status.isGranted;

      case AppPermissionType.contacts:
        final status = await Permission.contacts.request();
        await refresh();
        return status.isGranted;

      case AppPermissionType.notifications:
        final status = await Permission.notification.request();
        await refresh();
        return status.isGranted;

      case AppPermissionType.accessibility:
        await ScreenAutomationService.instance.openAccessibilitySettings();
        return false;

      case AppPermissionType.overlay:
        await InboxService.instance.openOverlaySettings();
        return false;

      case AppPermissionType.notificationListener:
        await InboxService.instance.openNotificationListenerSettings();
        return false;

      case AppPermissionType.batteryOptimization:
        await InboxService.instance.openBatteryOptimizationSettings();
        return false;
    }
  }

  /// Requests all standard runtime dialog permissions in one batch.
  Future<void> requestAllCorePermissions() async {
    await [
      Permission.microphone,
      Permission.sms,
      Permission.contacts,
      Permission.notification,
    ].request();
    await refresh();
  }

  /// Opens the Android App Info page where all permissions can be managed.
  Future<void> openAppInfo() async {
    await openAppSettings();
  }
}

