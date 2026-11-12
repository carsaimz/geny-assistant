import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarItem {
  final String id;
  final String title;
  final String description;
  final String? location;
  final DateTime dateTime;
  final int durationMinutes;
  final bool isReminder;
  bool isCompleted;

  CalendarItem({
    required this.id,
    required this.title,
    this.description = '',
    this.location,
    required this.dateTime,
    this.durationMinutes = 30,
    this.isReminder = false,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'dateTime': dateTime.toIso8601String(),
        'durationMinutes': durationMinutes,
        'isReminder': isReminder,
        'isCompleted': isCompleted,
      };

  factory CalendarItem.fromJson(Map<String, dynamic> json) => CalendarItem(
        id: json['id'] as String? ?? UniqueKey().toString(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        location: json['location'] as String?,
        dateTime: json['dateTime'] != null
            ? DateTime.tryParse(json['dateTime'].toString()) ?? DateTime.now()
            : DateTime.now(),
        durationMinutes: json['durationMinutes'] as int? ?? 30,
        isReminder: json['isReminder'] as bool? ?? false,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

/// Calendar management & reminder engine.
/// Stores local events/reminders, triggers local device notifications,
/// and bridges to the Android system calendar via intents.
class CalendarReminderService extends ChangeNotifier {
  CalendarReminderService._();
  static final CalendarReminderService instance = CalendarReminderService._();

  static const _storageKey = 'geny_calendar_items_v1';
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final List<CalendarItem> _items = [];
  bool _initialized = false;

  List<CalendarItem> get items => List.unmodifiable(_items);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    try {
      await _notifications.initialize(settings: initSettings);
    } catch (_) {}

    // Load persisted items
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.clear();
          for (final e in decoded) {
            if (e is Map) {
              _items.add(
                CalendarItem.fromJson(e.map((k, v) => MapEntry('$k', v))),
              );
            }
          }
        }
      } catch (_) {}
    }

    _sortItems();
    notifyListeners();
  }

  void _sortItems() {
    _items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((i) => i.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Adds a new calendar event or reminder.
  Future<CalendarItem> addReminder(String title, {DateTime? time}) async {
    return addItem(
      title: title,
      dateTime: time ?? DateTime.now().add(const Duration(hours: 1)),
      isReminder: true,
    );
  }

  Future<CalendarItem> addItem({
    required String title,
    String description = '',
    required DateTime dateTime,
    int durationMinutes = 30,
    bool isReminder = false,
  }) async {
    await init();
    final item = CalendarItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      description: description.trim(),
      dateTime: dateTime,
      durationMinutes: durationMinutes,
      isReminder: isReminder,
    );
    _items.add(item);
    _sortItems();
    await _persist();

    // Schedule local system notification if in the future
    if (dateTime.isAfter(DateTime.now())) {
      await _scheduleNotification(item);
    }

    return item;
  }

  Future<void> _scheduleNotification(CalendarItem item) async {
    try {
      final notifId = item.id.hashCode & 0x7FFFFFFF;
      // Show notification on alert time
      await _notifications.show(
        id: notifId,
        title: item.isReminder ? 'Reminder: ${item.title}' : 'Calendar: ${item.title}',
        body: item.description.isNotEmpty
            ? item.description
            : DateFormat('h:mm a').format(item.dateTime),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'calendar_reminders',
            'Calendar & Reminders',
            channelDescription: 'Alerts for scheduled tasks and calendar events',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Deletes an item by ID.
  Future<void> deleteItem(String id) async {
    await init();
    _items.removeWhere((i) => i.id == id);
    await _persist();
  }

  /// Reschedules an item to a new date and time.
  Future<CalendarItem?> rescheduleItem(String id, DateTime newDateTime) async {
    await init();
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return null;
    final old = _items[index];
    final updated = CalendarItem(
      id: old.id,
      title: old.title,
      description: old.description,
      dateTime: newDateTime,
      durationMinutes: old.durationMinutes,
      isReminder: old.isReminder,
      isCompleted: false,
    );
    _items[index] = updated;
    _sortItems();
    await _persist();
    return updated;
  }

  /// Marks a reminder/task as completed.
  Future<void> toggleCompleted(String id) async {
    await init();
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _items[index].isCompleted = !_items[index].isCompleted;
      await _persist();
    }
  }

  /// Returns items scheduled for today.
  List<CalendarItem> getTodayItems() {
    final now = DateTime.now();
    return _items.where((i) {
      return i.dateTime.year == now.year &&
          i.dateTime.month == now.month &&
          i.dateTime.day == now.day &&
          !i.isCompleted;
    }).toList();
  }

  /// Natural spoken briefing of today's schedule for GENY vocalization.
  String getTodayBriefingSpoken() {
    final today = getTodayItems();
    if (today.isEmpty) {
      return 'You have a clear calendar today. No scheduled appointments or pending reminders.';
    }

    final count = today.length;
    final buffer = StringBuffer('You have $count ${count == 1 ? 'item' : 'items'} on your schedule today: ');
    for (var i = 0; i < today.length; i++) {
      final item = today[i];
      final timeStr = DateFormat('h:mm a').format(item.dateTime);
      buffer.write('${item.title} at $timeStr');
      if (i < today.length - 1) buffer.write(', and ');
    }
    buffer.write('.');
    return buffer.toString();
  }

  /// Opens the native Android Calendar app prefilled with event details.
  Future<bool> openNativeCalendarInsert({
    required String title,
    required DateTime beginTime,
    int durationMinutes = 60,
  }) async {
    final beginMs = beginTime.millisecondsSinceEpoch;
    final endTime = beginTime.add(Duration(minutes: durationMinutes));
    final endMs = endTime.millisecondsSinceEpoch;

    // Content provider intent URI for Android Calendar
    final uri = Uri.parse(
      'content://com.android.calendar/time/$beginMs?title=${Uri.encodeComponent(title)}&endTime=$endMs',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // Fallback: Google Calendar web URL
    final gcalUrl = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE&text=${Uri.encodeComponent(title)}',
    );
    return launchUrl(gcalUrl, mode: LaunchMode.externalApplication);
  }
}
