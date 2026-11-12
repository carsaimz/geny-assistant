import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/charging_telemetry_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/arc_reactor_charging_dialog.dart';

/// Root application widget with theme + onboarding routing.
class GenyApp extends StatefulWidget {
  const GenyApp({super.key});

  /// Global key for overlay dialogs and system-level screen pushes.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<GenyApp> createState() => _GenyAppState();
}

class _GenyAppState extends State<GenyApp> {
  final _settings = SettingsService.instance;
  bool _chargingHudModalOpen = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    ChargingTelemetryService.instance.showCinematicHud
        .addListener(_onChargingHudTriggered);
  }

  @override
  void dispose() {
    ChargingTelemetryService.instance.showCinematicHud
        .removeListener(_onChargingHudTriggered);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onChargingHudTriggered() {
    if (ChargingTelemetryService.instance.showCinematicHud.value &&
        !_chargingHudModalOpen) {
      ChargingTelemetryService.instance.showCinematicHud.value = false;
      final nav = GenyApp.navigatorKey.currentState;
      if (nav != null) {
        _chargingHudModalOpen = true;
        showDialog(
          context: nav.context,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (_) => const ArcReactorChargingDialog(),
        ).whenComplete(() {
          _chargingHudModalOpen = false;
        });
      }
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: GenyApp.navigatorKey,
      title: 'Geny',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _settings.themeMode,
      home: _settings.onboardingComplete
          ? const HomeScreen()
          : OnboardingScreen(onFinished: () => setState(() {})),
    );
  }
}
