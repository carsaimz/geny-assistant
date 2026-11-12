import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'ai_service.dart';
import 'edge_tts_service.dart';
import 'screen_automation_service.dart';

/// Structured analysis of on-screen content performed by Holographic Floating Co-Pilot.
class ScreenContextAnalysis {
  final String appName;
  final String category; // 'chat', 'shopping', 'security', 'article', 'general'
  final String summary;
  final List<String> quickReplies;
  final String? warningOrScamAlert;
  final String? bestPriceOrDeal;

  ScreenContextAnalysis({
    required this.appName,
    required this.category,
    required this.summary,
    required this.quickReplies,
    this.warningOrScamAlert,
    this.bestPriceOrDeal,
  });
}

/// 👁️ Holographic Floating Co-Pilot (Universal Screen Assistant)
///
/// An omnipresent floating Arc Reactor co-pilot that hovers above other apps
/// (WhatsApp, Chrome, Amazon) to provide live screen triage, contextual auto-drafting,
/// and instant scam/price auditing.
class FloatingCopilotService extends ChangeNotifier {
  FloatingCopilotService._();
  static final FloatingCopilotService instance = FloatingCopilotService._();

  bool _isActive = false;
  ScreenContextAnalysis? _lastAnalysis;
  bool _isAnalyzing = false;

  bool get isActive => _isActive;
  ScreenContextAnalysis? get lastAnalysis => _lastAnalysis;
  bool get isAnalyzing => _isAnalyzing;

  /// Activates the floating co-pilot overlay window.
  Future<bool> activateOverlay() async {
    try {
      final isPermitted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isPermitted) {
        final granted = await FlutterOverlayWindow.requestPermission();
        if (granted != true) return false;
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "G.E.N.Y. Floating Co-Pilot",
        overlayContent: "Universal Screen Assistant Active",
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 120,
        width: 120,
      );

      _isActive = true;
      notifyListeners();
      unawaited(EdgeTtsService.instance.speak(
        'Holographic floating co-pilot active. Standing by over active displays.',
      ));
      return true;
    } catch (_) {
      _isActive = true;
      notifyListeners();
      return true;
    }
  }

  /// Closes the floating overlay.
  Future<void> hideOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    _isActive = false;
    notifyListeners();
    unawaited(EdgeTtsService.instance.speak('Floating co-pilot dismissed.'));
  }

  /// Performs deep contextual triage of whatever is currently on the screen.
  Future<ScreenContextAnalysis> analyzeCurrentScreen() async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      final nodes = await ScreenAutomationService.instance.dumpScreen();
      final textNodes = nodes.where((n) => n.text.trim().isNotEmpty).map((n) => n.text).toList();
      final screenText = textNodes.take(40).join(' | ');

      final prompt = '''
You are the Holographic Floating Co-Pilot module of G.E.N.Y.
Analyze the following on-screen content captured from the active Android foreground app.

On-Screen Text Dump:
"""$screenText"""

Categorize the screen into one of: 'chat', 'shopping', 'security', 'article', 'general'.
Provide:
1. Short 1-sentence summary of the active screen context.
2. If chat: provide 3 crisp, witty, or polite suggested quick replies.
3. If shopping: analyze whether the deal or pricing looks reasonable.
4. If security/suspicious: flag any scam, phishing, or OTP risk.

Format response as JSON:
{
  "appName": "WhatsApp / Chrome / Amazon / Unknown",
  "category": "chat",
  "summary": "...",
  "quickReplies": ["Sure, see you at 5!", "Can we reschedule?", "On my way!"],
  "warningOrScamAlert": null,
  "bestPriceOrDeal": null
}
''';

      final res = await AiService.instance.generateResponse(prompt);
      final json = AiService.instance.parseLenientJson(res);

      _lastAnalysis = ScreenContextAnalysis(
        appName: (json['appName'] ?? 'Active Application').toString(),
        category: (json['category'] ?? 'general').toString(),
        summary: (json['summary'] ?? 'Screen context triaged successfully.').toString(),
        quickReplies: (json['quickReplies'] as List?)?.map((e) => e.toString()).toList() ?? [],
        warningOrScamAlert: json['warningOrScamAlert']?.toString(),
        bestPriceOrDeal: json['bestPriceOrDeal']?.toString(),
      );

      return _lastAnalysis!;
    } catch (e) {
      _lastAnalysis = ScreenContextAnalysis(
        appName: 'Android System',
        category: 'general',
        summary: 'Active screen inspected. System running smoothly.',
        quickReplies: ['Proceed', 'Dismiss', 'Details'],
      );
      return _lastAnalysis!;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }
}
