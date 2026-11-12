import 'package:android_intent_plus/android_intent.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

/// Queries installed apps and launches them by fuzzy name / package match.
class AppLauncherService {
  AppLauncherService._();
  static final AppLauncherService instance = AppLauncherService._();

  List<AppInfo>? _cache;

  static const Map<String, String> _aliasPackages = {
    'play store': 'com.android.vending',
    'playstore': 'com.android.vending',
    'google play': 'com.android.vending',
    'google play store': 'com.android.vending',
    'app store': 'com.android.vending',
    'store': 'com.android.vending',
    'youtube': 'com.google.android.youtube',
    'yt': 'com.google.android.youtube',
    'whatsapp': 'com.whatsapp',
    'instagram': 'com.instagram.android',
    'insta': 'com.instagram.android',
    'chrome': 'com.android.chrome',
    'browser': 'com.android.chrome',
    'settings': 'com.android.settings',
    'maps': 'com.google.android.apps.maps',
    'google maps': 'com.google.android.apps.maps',
    'gmail': 'com.google.android.gm',
    'email': 'com.google.android.gm',
    'photos': 'com.google.android.apps.photos',
    'gallery': 'com.google.android.apps.photos',
    'contacts': 'com.google.android.contacts',
    'messages': 'com.google.android.apps.messaging',
    'sms': 'com.google.android.apps.messaging',
  };

  /// All launchable, non-system apps (cached for the process lifetime).
  Future<List<AppInfo>> installedApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;
    try {
      _cache = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );
    } catch (_) {
      _cache = const [];
    }
    return _cache!;
  }

  /// Best-matching app for a free-text [query]: exact package id, exact
  /// name, "starts with", "contains", then word-overlap scoring.
  Future<AppInfo?> findApp(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final apps = await installedApps();
    if (apps.isEmpty) return null;

    for (final app in apps) {
      if (app.packageName.toLowerCase() == q) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase() == q) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase().startsWith(q)) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q)) {
        return app;
      }
    }

    // Token overlap fallback (handles "google maps" vs "Maps").
    final tokens =
        q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 2).toSet();
    if (tokens.isEmpty) return null;
    AppInfo? best;
    var bestScore = 0;
    for (final app in apps) {
      final name = app.name.toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (name.contains(t)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = app;
      }
    }
    return best;
  }

  /// Launches [query] (name or package). Returns a human-readable outcome
  /// message: the app name on success, null on failure.
  Future<String?> launch(String query) async {
    final q = query.trim().toLowerCase();

    // Check alias packages first for 100% reliable opening of core apps
    final knownPkg = _aliasPackages[q];
    if (knownPkg != null) {
      try {
        final ok = await InstalledApps.startApp(knownPkg) ?? false;
        if (ok) return q;
      } catch (_) {}
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: knownPkg,
        );
        await intent.launch();
        return q;
      } catch (_) {}
    }

    for (final entry in _aliasPackages.entries) {
      if (q.contains(entry.key)) {
        try {
          final ok = await InstalledApps.startApp(entry.value) ?? false;
          if (ok) return entry.key;
        } catch (_) {}
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: entry.value,
          );
          await intent.launch();
          return entry.key;
        } catch (_) {}
      }
    }

    // Direct URL scheme fallbacks for high-frequency targets
    if (q.contains('play store') || q.contains('playstore') || q.contains('google play')) {
      try {
        final ok = await launchUrl(
          Uri.parse('market://search?q=apps'),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return 'Play Store';
      } catch (_) {}
    }

    if (q.contains('youtube') || q.contains('yt')) {
      try {
        final ok = await launchUrl(
          Uri.parse('https://www.youtube.com'),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return 'YouTube';
      } catch (_) {}
    }

    final app = await findApp(query);
    if (app == null) return null;
    try {
      final ok = await InstalledApps.startApp(app.packageName) ?? false;
      return ok ? app.name : null;
    } catch (_) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: app.packageName,
        );
        await intent.launch();
        return app.name;
      } catch (_) {
        return null;
      }
    }
  }
}
