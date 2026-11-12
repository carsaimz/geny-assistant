import 'package:flutter/services.dart';

/// Service providing direct queries for top installed applications
/// and daily screen time / most used apps via UsageStatsManager.
class AppUsageService {
  AppUsageService._();
  static final AppUsageService instance = AppUsageService._();

  static const MethodChannel _channel = MethodChannel('com.privateagent/accessibility');

  Future<List<Map<String, dynamic>>> getInstalledApps({int limit = 10}) async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getInstalledApps', {'limit': limit});
      if (res == null) return [];
      return res
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> getInstalledAppsSpoken({int limit = 10}) async {
    final apps = await getInstalledApps(limit: limit);
    if (apps.isEmpty) {
      return 'No installed application records could be indexed directly.';
    }

    final names = apps.map((a) => a['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return 'No primary applications indexed.';

    final joined = names.take(6).join(', ');
    final remaining = names.length > 6 ? ', and ${names.length - 6} other applications' : '';
    return 'Your primary installed applications include $joined$remaining.';
  }

  Future<bool> hasUsageStatsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getAppUsageStats() async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getAppUsageStats');
      if (res == null) return [];
      return res
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> getTopUsedAppsSpoken() async {
    final hasPerm = await hasUsageStatsPermission();
    if (!hasPerm) {
      await openUsageStatsSettings();
      return 'Usage access permission is required to analyze screen time. I have opened the system permission window.';
    }

    final stats = await getAppUsageStats();
    if (stats.isEmpty) {
      return 'No significant application usage recorded for today yet.';
    }

    final top = stats.take(4).map((s) {
      final name = s['name']?.toString() ?? 'App';
      final formatted = s['formatted']?.toString() ?? '';
      return '$name with $formatted';
    }).join(', ');

    return 'Your most used applications today are $top.';
  }
}

