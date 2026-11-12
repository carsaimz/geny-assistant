import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'edge_tts_service.dart';

/// ⚡ Arc Reactor Charging Telemetry Service
///
/// Monitors power cell coupling, real-time charging wattage, thermal stability,
/// voltage, and battery percentage. Automatically triggers holographic Arc Reactor
/// HUD visuals and vocal Stark telemetry upon charger connection.
class ChargingTelemetryService extends ChangeNotifier {
  ChargingTelemetryService._();

  static final ChargingTelemetryService instance = ChargingTelemetryService._();
  static const MethodChannel _channel = MethodChannel('com.privateagent/accessibility');

  bool _isCharging = false;
  int _batteryLevel = -1;
  int _voltageMv = 0;
  double _temperatureC = 0.0;
  int _currentMa = 0;
  double _wattage = 0.0;
  String _chargeType = 'Internal Core';
  DateTime? _lastCoupledTime;
  bool _voiceAnnouncements = true;

  final ValueNotifier<bool> showCinematicHud = ValueNotifier<bool>(false);

  bool get isCharging => _isCharging;
  int get batteryLevel => _batteryLevel;
  int get voltageMv => _voltageMv;
  double get temperatureC => _temperatureC;
  int get currentMa => _currentMa;
  double get wattage => _wattage;
  String get chargeType => _chargeType;
  DateTime? get lastCoupledTime => _lastCoupledTime;
  bool get voiceAnnouncements => _voiceAnnouncements;

  set voiceAnnouncements(bool val) {
    _voiceAnnouncements = val;
    notifyListeners();
  }

  /// Handles native charging events dispatched by [NativeBridgeService].
  Future<void> handleNativeCall(MethodCall call) async {
    if (call.method == 'onPowerConnected') {
      final args = call.arguments;
      if (args is Map) {
        _applyTelemetryMap(args, connected: true);
      }
    } else if (call.method == 'onPowerDisconnected') {
      final args = call.arguments;
      if (args is Map) {
        _applyTelemetryMap(args, connected: false);
      }
    }
  }

  void _applyTelemetryMap(Map data, {required bool connected}) {
    _isCharging = connected;
    _batteryLevel = (data['batteryLevel'] as num?)?.toInt() ?? _batteryLevel;
    _voltageMv = (data['voltageMv'] as num?)?.toInt() ?? 4100;
    _temperatureC = (data['temperatureC'] as num?)?.toDouble() ?? 30.0;
    _currentMa = (data['currentMa'] as num?)?.toInt() ?? 2500;
    _chargeType = (data['chargeType'] ?? (connected ? 'AC Wall Supply' : 'Internal Arc Core')).toString();
    _wattage = (data['wattage'] as num?)?.toDouble() ?? (_voltageMv / 1000.0 * 2.5);

    if (connected) {
      _lastCoupledTime = DateTime.now();
      showCinematicHud.value = true;
      if (_voiceAnnouncements) {
        final wattStr = _wattage > 0 ? '${_wattage.toStringAsFixed(1)} Watts' : 'nominal levels';
        final tempStr = _temperatureC > 0 ? ', core temperature at ${_temperatureC.toStringAsFixed(1)}° Celsius' : '';
        unawaited(EdgeTtsService.instance.speak(
          'Arc reactor coupled. Energy intake active at $wattStr. Power cells at $_batteryLevel percent$tempStr.',
        ));
      }
    } else {
      if (_voiceAnnouncements) {
        unawaited(EdgeTtsService.instance.speak(
          'Arc reactor decoupled. System running on internal reserves at $_batteryLevel percent power.',
        ));
      }
    }
    notifyListeners();
  }

  /// Pulls instantaneous telemetry snapshot from native hardware.
  Future<Map<String, dynamic>> queryTelemetry() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getChargingTelemetry');
      if (res != null) {
        _applyTelemetryMap(res, connected: res['isCharging'] == true);
        return res;
      }
    } catch (_) {}

    return {
      'isCharging': _isCharging,
      'batteryLevel': _batteryLevel,
      'voltageMv': _voltageMv,
      'temperatureC': _temperatureC,
      'currentMa': _currentMa,
      'chargeType': _chargeType,
      'wattage': _wattage,
    };
  }

  /// Returns articulate spoken telemetry diagnostic.
  Future<String> getSpokenTelemetry() async {
    final t = await queryTelemetry();
    final lvl = t['batteryLevel'] ?? 85;
    final chg = t['isCharging'] == true;
    final watt = (t['wattage'] as num?)?.toDouble() ?? 18.0;
    final temp = (t['temperatureC'] as num?)?.toDouble() ?? 31.0;
    final type = t['chargeType'] ?? 'Turbine Supply';

    if (chg) {
      return 'Arc reactor telemetry: Coupled to $type. Energy flow rate is ${watt.toStringAsFixed(1)} Watts. Current core storage stands at $lvl%, with thermals steady at ${temp.toStringAsFixed(1)}°C.';
    } else {
      return 'Arc reactor core operational on internal storage at $lvl%. Thermals stable at ${temp.toStringAsFixed(1)}°C. No external charging grid detected.';
    }
  }
}

