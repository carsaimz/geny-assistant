import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'ai_service.dart';
import 'app_launcher_service.dart';
import 'app_usage_service.dart';
import 'phone_storage_service.dart';
import 'screen_automation_service.dart';
import 'sentry_service.dart';
import 'sound_radar_service.dart';
import 'system_control_service.dart';
import 'system_diagnostics_service.dart';
import 'workflow_service.dart';

/// Real-time tools powering the G.E.N.Y. intelligence core:
/// - Real-Time Breaking News (Google News Live RSS Feed)
/// - Live Web Search (DuckDuckGo & Wikipedia APIs)
/// - Real-Time Weather (wttr.in)
/// - Self-Evolving Workflows (Hermes Engine)
/// - Hardware Telemetry (Battery, Flashlight/Torch, Volume, Brightness)
/// - Temporal Computations (Exact Local & World Times)
/// - App Launching & Contact Dialer
class GenyToolsService {
  GenyToolsService._();
  static final GenyToolsService instance = GenyToolsService._();

  static const MethodChannel _channel =
      MethodChannel('com.privateagent/accessibility');

  final http.Client _client = http.Client();

  // ------------------------------------------------------------------
  // 1. Live Breaking News (Google News & Bing News Multi-Feed)
  // ------------------------------------------------------------------

  /// Fetches real-time live breaking news headlines across categories or topics.
  Future<String> getLiveNews([String? topic]) async {
    final cleanTopic = topic?.trim() ?? '';
    final buffer = StringBuffer();

    // 1. Google News RSS
    try {
      final gUrl = cleanTopic.isEmpty
          ? Uri.parse('https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en')
          : Uri.parse(
              'https://news.google.com/rss/search?q=${Uri.encodeComponent(cleanTopic)}&hl=en-US&gl=US&ceid=US:en',
            );

      final resp = await _client.get(
        gUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final xml = resp.body;
        final matches = RegExp(r'<item>[\s\S]*?<title>(.*?)</title>[\s\S]*?<pubDate>(.*?)</pubDate>')
            .allMatches(xml)
            .take(5)
            .map((m) {
              final t = (m.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
              final pub = (m.group(2) ?? '').trim();
              return '- $t ($pub)';
            })
            .where((t) => t.isNotEmpty)
            .toList();

        if (matches.isNotEmpty) {
          buffer.writeln('GLOBAL WIRE HEADLINES:');
          for (final m in matches) {
            buffer.writeln(m
                .replaceAll('&amp;', '&')
                .replaceAll('&quot;', '"')
                .replaceAll('&#39;', "'")
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>'));
          }
        }
      }
    } catch (_) {}

    // 2. Bing News RSS (with full paragraph descriptions)
    try {
      final bQuery = cleanTopic.isEmpty ? 'top news headlines world' : cleanTopic;
      final bUrl = Uri.parse(
        'https://www.bing.com/news/search?q=${Uri.encodeComponent(bQuery)}&format=rss',
      );

      final resp = await _client.get(
        bUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final xml = resp.body;
        final items = RegExp(r'<item>[\s\S]*?<title>(.*?)</title>[\s\S]*?<description>(.*?)</description>')
            .allMatches(xml)
            .take(4)
            .map((m) {
              final t = (m.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
              final d = (m.group(2) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
              return '- $t: $d';
            })
            .where((s) => s.length > 10)
            .toList();

        if (items.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln('');
          buffer.writeln('DETAILED NEWS BRIEFINGS:');
          for (final item in items) {
            buffer.writeln(item
                .replaceAll('&amp;', '&')
                .replaceAll('&quot;', '"')
                .replaceAll('&#39;', "'")
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>'));
          }
        }
      }
    } catch (_) {}

    if (buffer.isNotEmpty) {
      return buffer.toString().trim();
    }

    return 'Unable to retrieve live breaking news at this moment.';
  }

  // ------------------------------------------------------------------
  // 2. Multi-Source Live Web Intelligence & Fact Engine
  // ------------------------------------------------------------------

  /// Performs an industrial multi-source live web query to fetch current information,
  /// real-time events, encyclopedic facts, or live news in the background.
  Future<String> searchWeb(String query) async {
    var clean = query.trim();
    if (clean.isEmpty) return 'No search query provided.';

    // Strip leading conversational phrases
    clean = clean.replaceAll(
      RegExp(r'^(geny|search\s+for|look\s+up|google|find\s+out|tell\s+me\s+about|what\s+is|who\s+is|check\s+online\s+for)\s+', caseSensitive: false),
      '',
    ).trim();

    final lower = clean.toLowerCase();
    // Fast path: if the query is explicitly asking for today's news
    if (lower.contains('top news') ||
        lower.contains('breaking news') ||
        lower.contains('today headlines') ||
        lower.contains('what happened today')) {
      final topic = lower
          .replaceAll('news', '')
          .replaceAll('breaking', '')
          .replaceAll('headlines', '')
          .trim();
      return getLiveNews(topic.isNotEmpty ? topic : null);
    }

    final buffer = StringBuffer();
    final encoded = Uri.encodeComponent(clean);

    // Concurrently fetch Wikipedia Summary, Bing News RSS, and Google News RSS
    final results = await Future.wait([
      // 1. Wikipedia Search & Page Summary
      (() async {
        try {
          final sUrl = Uri.parse(
            'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encoded&utf8=&format=json',
          );
          final resp = await _client.get(sUrl, headers: {'User-Agent': 'GENY-Geny/1.0'}).timeout(const Duration(seconds: 4));
          if (resp.statusCode == 200) {
            final json = jsonDecode(resp.body);
            final searchList = json?['query']?['search'] as List?;
            if (searchList != null && searchList.isNotEmpty) {
              final topTitle = searchList.first['title']?.toString() ?? '';
              if (topTitle.isNotEmpty) {
                final pageUrl = Uri.parse(
                  'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(topTitle.replaceAll(' ', '_'))}',
                );
                final pageResp = await _client.get(pageUrl, headers: {'User-Agent': 'GENY-Geny/1.0'}).timeout(const Duration(seconds: 4));
                if (pageResp.statusCode == 200) {
                  final pageData = jsonDecode(pageResp.body);
                  final extract = pageData?['extract']?.toString() ?? '';
                  if (extract.isNotEmpty) {
                    return 'FACTUAL OVERVIEW ($topTitle):\n$extract';
                  }
                }
              }
            }
          }
        } catch (_) {}
        return null;
      })(),

      // 2. Bing News RSS (Titles & Summaries)
      (() async {
        try {
          final bUrl = Uri.parse('https://www.bing.com/news/search?q=$encoded&format=rss');
          final resp = await _client.get(bUrl, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
          if (resp.statusCode == 200) {
            final xml = resp.body;
            final items = RegExp(r'<item>[\s\S]*?<title>(.*?)</title>[\s\S]*?<description>(.*?)</description>')
                .allMatches(xml)
                .take(3)
                .map((m) {
                  final t = (m.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
                  final d = (m.group(2) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
                  return '- $t: $d';
                })
                .where((s) => s.length > 10)
                .toList();
            if (items.isNotEmpty) {
              return 'RECENT WEB NEWS & UPDATES:\n${items.join('\n')}';
            }
          }
        } catch (_) {}
        return null;
      })(),

      // 3. Google News RSS Headlines
      (() async {
        try {
          final gUrl = Uri.parse('https://news.google.com/rss/search?q=$encoded&hl=en-US&gl=US&ceid=US:en');
          final resp = await _client.get(gUrl, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
          if (resp.statusCode == 200) {
            final xml = resp.body;
            final titles = RegExp(r'<item>[\s\S]*?<title>(.*?)</title>')
                .allMatches(xml)
                .take(3)
                .map((m) => '- ${(m.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim()}')
                .where((t) => t.length > 5)
                .toList();
            if (titles.isNotEmpty) {
              return 'LIVE ONLINE HEADLINES:\n${titles.join('\n')}';
            }
          }
        } catch (_) {}
        return null;
      })(),

      // 4. DuckDuckGo Instant Answer
      (() async {
        try {
          final ddgUrl = Uri.parse('https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1');
          final resp = await _client.get(ddgUrl).timeout(const Duration(seconds: 3));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data is Map) {
              final answer = data['Answer']?.toString() ?? '';
              final abstractText = data['AbstractText']?.toString() ?? '';
              if (answer.isNotEmpty) return 'DIRECT ANSWER: $answer';
              if (abstractText.isNotEmpty) return 'DIRECT ABSTRACT: $abstractText';
            }
          }
        } catch (_) {}
        return null;
      })(),
    ]);

    for (final r in results) {
      if (r != null && r.trim().isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln('\n');
        buffer.write(r
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>'));
      }
    }

    if (buffer.isNotEmpty) {
      return buffer.toString().trim();
    }

    return 'No verified live web records found for "$clean".';
  }

  // ------------------------------------------------------------------
  // 3. Real-Time Meteorological Telemetry
  // ------------------------------------------------------------------

  /// Retrieves real-time weather and temperature for [location].
  Future<String> getWeather(String location) async {
    final loc = location.trim();
    try {
      final url = Uri.parse(
        'https://wttr.in/${Uri.encodeComponent(loc)}?format=%l:+%c+%t,+%C,+wind+%w,+humidity+%h',
      );
      final resp = await _client.get(url).timeout(
            const Duration(seconds: 6),
          );
      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        if (body.isNotEmpty && !body.contains('Unknown location')) {
          return body;
        }
      }
    } catch (_) {}

    return 'Unable to retrieve meteorological telemetry for "$location".';
  }

  // ------------------------------------------------------------------
  // 4. Self-Evolving Workflows (Hermes Engine)
  // ------------------------------------------------------------------

  /// Executes an evolved workflow protocol on device hardware.
  Future<String?> triggerWorkflowIfMatched(String speech) async {
    final engine = WorkflowService.instance;
    final match = engine.findMatch(speech);
    if (match != null) {
      await engine.executeWorkflow(match);
      return match.spokenConfirmation;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 5. Hardware State (Battery, Torch, System)
  // ------------------------------------------------------------------

  /// Queries the Android battery service.
  Future<Map<String, dynamic>> getBatteryStatus() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getBatteryStatus');
      return {
        'level': result?['level'] as int? ?? -1,
        'isCharging': result?['isCharging'] as bool? ?? false,
      };
    } catch (_) {
      return {'level': -1, 'isCharging': false};
    }
  }

  /// Toggles device flashlight/torch.
  Future<bool> setTorch(bool enable) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setTorch',
        {'enable': enable},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // 6. Temporal Diagnostics
  // ------------------------------------------------------------------

  /// Returns current local date and time in an articulate natural format.
  String getCurrentDateTime() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, y').format(now);
    final timeStr = DateFormat('h:mm a').format(now);
    return '$dateStr at $timeStr';
  }

  // ------------------------------------------------------------------
  // 7. Contacts & App Management
  // ------------------------------------------------------------------

  /// Launches an app by name or package identifier.
  Future<bool> launchApp(String appName) async {
    final launched = await AppLauncherService.instance.launch(appName);
    return launched != null;
  }

  /// Looks up a contact by name and initiates a dial.
  Future<String> callContact(String name) async {
    try {
      final contacts = await SystemControlService.instance.searchContacts(name);
      if (contacts.isNotEmpty) {
        final hit = contacts.first;
        if (hit.phone != null && hit.phone!.isNotEmpty) {
          await SystemControlService.instance.dial(hit.phone!);
          return 'Dialing ${hit.name} at ${hit.phone}.';
        }
      }
    } catch (_) {}
    return 'Unable to locate phone coordinates for "$name".';
  }

  // ------------------------------------------------------------------
  // 8. Complete System Health Diagnostics
  // ------------------------------------------------------------------

  /// Compiles a diagnostic summary of device hardware.
  Future<String> getSystemDiagnostics() async {
    final battery = await getBatteryStatus();
    final volume = await SystemControlService.instance.getVolume();
    final brightness = await SystemControlService.instance.getBrightness();
    final serviceOn = await ScreenAutomationService.instance.isServiceEnabled();

    final battLevel = battery['level'] as int;
    final isCharging = battery['isCharging'] as bool;

    final battText = battLevel >= 0
        ? '$battLevel% (${isCharging ? 'Charging' : 'Discharging'})'
        : 'Unknown';

    final volPercent = (volume * 100).round();
    final brightPercent =
        brightness != null ? '${(brightness * 100).round()}%' : 'Auto';

    return 'All systems nominal. '
        'Battery is at $battText. '
        'Audio volume is at $volPercent%. '
        'Display brightness is at $brightPercent. '
        'Screen automation is ${serviceOn ? 'online' : 'offline'}.';
  }

  // ------------------------------------------------------------------
  // 9. Superpowers: Hardware Specs (No UI Taps / No Settings Navigation)
  // ------------------------------------------------------------------

  /// Direct hardware specs query: Android OS, RAM, ROM, Battery, and Thermals.
  Future<String> getHardwareSpecsSpoken() async {
    return SystemDiagnosticsService.instance.getDiagnosticsSpoken();
  }

  // ------------------------------------------------------------------
  // 10. Superpowers: Top Installed Apps (No UI Taps)
  // ------------------------------------------------------------------

  /// Lists launcher applications directly from PackageManager.
  Future<String> getInstalledAppsSpoken({int limit = 10}) async {
    return AppUsageService.instance.getInstalledAppsSpoken(limit: limit);
  }

  // ------------------------------------------------------------------
  // 11. Superpowers: App Usage & Screen Time (No UI Taps)
  // ------------------------------------------------------------------

  /// Direct app usage and screen time query via UsageStatsManager.
  Future<String> getTopUsedAppsSpoken() async {
    return AppUsageService.instance.getTopUsedAppsSpoken();
  }

  // ------------------------------------------------------------------
  // 12. Superpowers: Direct Storage & File System CRUD
  // ------------------------------------------------------------------

  /// Creates or appends to a file directly in storage (Download, Documents, etc.)
  Future<Map<String, dynamic>> createStorageFile({
    required String fileName,
    required String content,
    String folder = 'Download',
    bool append = false,
  }) async {
    return PhoneStorageService.instance.createFile(
      fileName: fileName,
      content: content,
      folder: folder,
      append: append,
    );
  }

  /// Reads a file directly from device storage.
  Future<Map<String, dynamic>> readStorageFile({
    required String fileName,
    String folder = 'Download',
  }) async {
    return PhoneStorageService.instance.readFile(
      fileName: fileName,
      folder: folder,
    );
  }

  /// Lists files in a given storage directory.
  Future<Map<String, dynamic>> listStorageFiles({String folder = 'Download'}) async {
    return PhoneStorageService.instance.listFiles(folder: folder);
  }

  /// Deletes a file directly from device storage.
  Future<Map<String, dynamic>> deleteStorageFile({
    required String fileName,
    String folder = 'Download',
  }) async {
    return PhoneStorageService.instance.deleteFile(
      fileName: fileName,
      folder: folder,
    );
  }

  // ------------------------------------------------------------------
  // 13. Superpowers: Tactical Sentry Mode Anti-Theft Watchdog
  // ------------------------------------------------------------------

  /// Arms the motion-sensor Sentry Watchdog.
  Future<bool> armSentry() async {
    return SentryService.instance.armSentry();
  }

  /// Disarms the Sentry Watchdog.
  Future<bool> disarmSentry() async {
    return SentryService.instance.disarmSentry();
  }

  // ------------------------------------------------------------------
  // 14. Superpowers: Acoustic Radar & Music Identification
  // ------------------------------------------------------------------

  /// Identifies music currently playing or queries song details.
  Future<String> identifyMusic([String? sampleOrHint]) async {
    return SoundRadarService.instance.identifyMusic(sampleOrHint);
  }

  /// Scans ambient physical sound environment.
  Future<String> scanAmbientEnvironment() async {
    return SoundRadarService.instance.scanAmbientEnvironment();
  }

  // ------------------------------------------------------------------
  // 15. Superpowers: Screen & Article Summarization (Floating Arc Reactor)
  // ------------------------------------------------------------------

  /// Dumps foreground screen text nodes (e.g. from Chrome or article reader),
  /// generates an articulate executive briefing, updates the Floating HUD,
  /// and returns the spoken summary.
  Future<String> summarizeForegroundScreen() async {
    try {
      final nodes = await ScreenAutomationService.instance.dumpScreen();
      final texts = nodes
          .map((n) => n.text.isNotEmpty ? n.text : n.contentDescription)
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      if (texts.isEmpty) {
        return 'I could not detect any readable text on the current screen.';
      }

      final joinedText = texts.take(40).join('\n');
      final summary = await AiService.instance.summarizeScreenContent(joinedText);

      // Broadcast summary to Floating Overlay HUD
      try {
        FlutterOverlayWindow.shareData(jsonEncode({
          'type': 'screen_summary',
          'title': 'Article Summary',
          'summary': summary,
        }));
      } catch (_) {}

      return summary;
    } catch (e) {
      return 'Unable to analyze the foreground screen article at this moment.';
    }
  }
}
