import 'package:flutter/services.dart';

/// Real-time hardware telemetry and specifications query service:
/// Android OS version, Device Model, RAM, ROM, Battery, and Thermals.
class SystemDiagnosticsService {
  SystemDiagnosticsService._();
  static final SystemDiagnosticsService instance = SystemDiagnosticsService._();

  static const MethodChannel _channel = MethodChannel('com.privateagent/accessibility');

  Future<Map<String, dynamic>?> getDiagnostics() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getSystemDiagnostics');
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Formats hardware specifications into a natural, articulate spoken summary.
  Future<String> getDiagnosticsSpoken() async {
    final diag = await getDiagnostics();
    if (diag == null) {
      return 'Unable to query onboard hardware diagnostics at this moment.';
    }

    final model = (diag['model'] ?? 'Device').toString();
    final manufacturer = (diag['manufacturer'] ?? '').toString();
    final android = (diag['androidVersion'] ?? 'Android').toString();

    final totalRam = (diag['totalRamMb'] as num?)?.toInt() ?? 0;
    final availRam = (diag['availRamMb'] as num?)?.toInt() ?? 0;
    final totalRom = (diag['totalRomGb'] as num?)?.toInt() ?? 0;
    final freeRom = (diag['freeRomGb'] as num?)?.toInt() ?? 0;

    final battery = (diag['batteryLevel'] as num?)?.toInt() ?? -1;
    final charging = diag['isCharging'] == true;
    final temp = (diag['batteryTempC'] as num?)?.toDouble() ?? 0.0;

    final ramGb = (totalRam / 1024).toStringAsFixed(1);
    final freeRamGb = (availRam / 1024).toStringAsFixed(1);

    final sb = StringBuffer();
    sb.write('System diagnostics: $manufacturer $model running $android. ');
    sb.write('Memory allocation: $freeRamGb GB free of $ramGb GB RAM. ');
    sb.write('Internal storage: $freeRom GB available of $totalRom GB. ');
    if (battery >= 0) {
      sb.write('Power cells at $battery%${charging ? ', charging' : ''}');
      if (temp > 0) {
        sb.write(', core temperature at ${temp.toStringAsFixed(1)}°C.');
      } else {
        sb.write('.');
      }
    }

    return sb.toString();
  }
}

