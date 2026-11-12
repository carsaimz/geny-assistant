import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volume_controller/volume_controller.dart';

/// Lightweight contact projection for search results.
class ContactHit {
  final String id;
  final String name;
  final String? phone;
  const ContactHit({required this.id, required this.name, this.phone});
}

/// Device-level controls: volume, brightness, alarms, contacts, dialer
/// and local notifications.
class SystemControlService {
  SystemControlService._();
  static final SystemControlService instance = SystemControlService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;

  // ------------------------------------------------------------------
  // Volume
  // ------------------------------------------------------------------

  Future<double> getVolume() async {
    try {
      return await VolumeController.instance.getVolume();
    } catch (_) {
      return 0;
    }
  }

  Future<void> setVolume(double value) async {
    try {
      await VolumeController.instance.setVolume(value.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> volumeUp() async => setVolume(await getVolume() + 0.15);
  Future<void> volumeDown() async => setVolume(await getVolume() - 0.15);

  Future<void> setMuted(bool muted) async {
    try {
      await VolumeController.instance.setMute(muted);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Brightness
  // ------------------------------------------------------------------

  /// Sets system brightness (requires WRITE_SETTINGS). Falls back to
  /// app-only brightness when the permission is missing.
  Future<bool> setBrightness(double value) async {
    final v = value.clamp(0.0, 1.0);
    try {
      if (await ScreenBrightness.instance.canChangeSystemBrightness) {
        await ScreenBrightness.instance.setSystemScreenBrightness(v);
        return true;
      }
      await ScreenBrightness.instance.setApplicationScreenBrightness(v);
      return true;
    } catch (_) {
      try {
        await ScreenBrightness.instance.setApplicationScreenBrightness(v);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<double?> getBrightness() async {
    try {
      return await ScreenBrightness.instance.system;
    } catch (_) {
      try {
        return await ScreenBrightness.instance.application;
      } catch (_) {
        return null;
      }
    }
  }

  // ------------------------------------------------------------------
  // Alarms
  // ------------------------------------------------------------------

  Future<bool> setAlarm({
    required int hour,
    required int minute,
    String label = 'Geny alarm',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label,
        },
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Contacts & dialer
  // ------------------------------------------------------------------

  Future<bool> requestContactsPermission() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  /// Fuzzy name search; returns up to [limit] hits with first phone number.
  Future<List<ContactHit>> searchContacts(String query,
      {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (!await requestContactsPermission()) return const [];
    try {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      final hits = <ContactHit>[];
      for (final c in contacts) {
        final name = c.displayName ?? '';
        if (name.toLowerCase().contains(q)) {
          hits.add(ContactHit(
            id: c.id ?? '',
            name: name,
            phone: c.phones.isEmpty ? null : c.phones.first.number,
          ));
          if (hits.length >= limit) break;
        }
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> dial(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Local notifications
  // ------------------------------------------------------------------

  Future<void> _ensureNotifications() async {
    if (_notificationsReady) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings: settings);
    _notificationsReady = true;
  }

  Future<void> notify(String title, String body) async {
    try {
      await _ensureNotifications();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'agent_status',
          'Agent Status',
          channelDescription: 'Task progress and completion notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Media & Screen Automation Controls
  // ------------------------------------------------------------------

  Future<void> nextTrack() async {
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MEDIA_BUTTON',
        arguments: {'android.intent.extra.KEY_EVENT': 87}, // KEYCODE_MEDIA_NEXT
      ).sendBroadcast();
    } catch (_) {}
  }

  Future<void> previousTrack() async {
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MEDIA_BUTTON',
        arguments: {'android.intent.extra.KEY_EVENT': 88}, // KEYCODE_MEDIA_PREVIOUS
      ).sendBroadcast();
    } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MEDIA_BUTTON',
        arguments: {'android.intent.extra.KEY_EVENT': 85}, // KEYCODE_MEDIA_PLAY_PAUSE
      ).sendBroadcast();
    } catch (_) {}
  }

  Future<bool> takeScreenshot() async {
    try {
      final res = await const MethodChannel('com.privateagent/accessibility')
          .invokeMethod<bool>('takeScreenshot');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
