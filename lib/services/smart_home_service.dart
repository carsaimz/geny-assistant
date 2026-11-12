import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// Representation of a Home Assistant / IoT smart device entity.
class SmartDeviceEntity {
  final String entityId;
  final String friendlyName;
  final String state; // 'on', 'off', 'unavailable'
  final Map<String, dynamic> attributes;

  const SmartDeviceEntity({
    required this.entityId,
    required this.friendlyName,
    required this.state,
    this.attributes = const {},
  });

  bool get isOn => state.toLowerCase() == 'on';
  bool get isLight => entityId.startsWith('light.');
  bool get isSwitch => entityId.startsWith('switch.');
  bool get isScene => entityId.startsWith('scene.');
}

/// 🏠 Smart Home & IoT Automation (Home Assistant / Local LAN)
///
/// Controls smart lighting, relays, switches, and scenes via local network
/// Home Assistant REST API and direct webhooks.
class SmartHomeService extends ChangeNotifier {
  SmartHomeService._();
  static final SmartHomeService instance = SmartHomeService._();

  final http.Client _client = http.Client();

  final List<SmartDeviceEntity> _entities = [];
  List<SmartDeviceEntity> get entities => List.unmodifiable(_entities);

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _lastError;
  String? get lastError => _lastError;

  String _cleanUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> _headers() {
    final token = SettingsService.instance.homeAssistantToken.trim();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Tests connectivity to the Home Assistant instance.
  Future<({bool success, String message})> checkConnection() async {
    final settings = SettingsService.instance;
    final base = _cleanUrl(settings.homeAssistantUrl);
    final uri = Uri.parse('$base/api/');

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      final res = await _client.get(uri, headers: _headers()).timeout(
            const Duration(seconds: 5),
          );

      _isConnecting = false;
      if (res.statusCode == 200) {
        notifyListeners();
        return (success: true, message: 'Connected to Home Assistant successfully.');
      } else {
        final err = 'Home Assistant returned HTTP ${res.statusCode}: ${res.body}';
        _lastError = err;
        notifyListeners();
        return (success: false, message: err);
      }
    } catch (e) {
      _isConnecting = false;
      final err = 'Unable to reach Home Assistant at $base: $e';
      _lastError = err;
      notifyListeners();
      return (success: false, message: err);
    }
  }

  /// Refreshes the list of smart home entities from `/api/states`.
  Future<List<SmartDeviceEntity>> refreshEntities() async {
    final settings = SettingsService.instance;
    final base = _cleanUrl(settings.homeAssistantUrl);
    final uri = Uri.parse('$base/api/states');

    try {
      final res = await _client.get(uri, headers: _headers()).timeout(
            const Duration(seconds: 6),
          );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          _entities.clear();
          for (final item in decoded) {
            if (item is Map) {
              final id = item['entity_id']?.toString() ?? '';
              if (id.startsWith('light.') ||
                  id.startsWith('switch.') ||
                  id.startsWith('scene.')) {
                final attrs = (item['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
                final name = attrs['friendly_name']?.toString() ?? id;
                final state = item['state']?.toString() ?? 'unknown';
                _entities.add(SmartDeviceEntity(
                  entityId: id,
                  friendlyName: name,
                  state: state,
                  attributes: attrs,
                ));
              }
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[SmartHomeService] Refresh entities error: $e');
    }

    if (_entities.isEmpty) {
      // Provide standard default entities for offline/demo configuration
      _entities.clear();
      _entities.addAll([
        const SmartDeviceEntity(
          entityId: 'light.living_room',
          friendlyName: 'Living Room Lights',
          state: 'off',
        ),
        const SmartDeviceEntity(
          entityId: 'light.desk_lamp',
          friendlyName: 'Desk Lamp',
          state: 'off',
        ),
        const SmartDeviceEntity(
          entityId: 'scene.cinema_mode',
          friendlyName: 'Cinema Mode Scene',
          state: 'scening',
        ),
      ]);
      notifyListeners();
    }

    return _entities;
  }

  /// Calls a Home Assistant service endpoint (e.g. `domain: 'light'`, `service: 'turn_on'`).
  Future<bool> callService({
    required String domain,
    required String service,
    required Map<String, dynamic> serviceData,
  }) async {
    final settings = SettingsService.instance;
    final base = _cleanUrl(settings.homeAssistantUrl);
    final uri = Uri.parse('$base/api/services/$domain/$service');

    try {
      final res = await _client.post(
        uri,
        headers: _headers(),
        body: jsonEncode(serviceData),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[SmartHomeService] Service call error: $e');
      return false;
    }
  }

  /// Turns on a light or smart switch.
  Future<bool> turnOn({String? entityId, int? brightnessPct}) async {
    final target = entityId ?? SettingsService.instance.smartHomeDefaultEntity;
    final isLight = target.startsWith('light.');
    final domain = isLight ? 'light' : 'homeassistant';

    final data = <String, dynamic>{
      'entity_id': target,
      if (isLight && brightnessPct != null) 'brightness_pct': brightnessPct,
    };

    return callService(domain: domain, service: 'turn_on', serviceData: data);
  }

  /// Turns off a light or smart switch.
  Future<bool> turnOff({String? entityId}) async {
    final target = entityId ?? SettingsService.instance.smartHomeDefaultEntity;
    final isLight = target.startsWith('light.');
    final domain = isLight ? 'light' : 'homeassistant';

    return callService(
      domain: domain,
      service: 'turn_off',
      serviceData: {'entity_id': target},
    );
  }

  /// Toggles the power state of a light or switch.
  Future<bool> toggle({String? entityId}) async {
    final target = entityId ?? SettingsService.instance.smartHomeDefaultEntity;
    return callService(
      domain: 'homeassistant',
      service: 'toggle',
      serviceData: {'entity_id': target},
    );
  }

  /// Triggers a smart home scene.
  Future<bool> triggerScene(String sceneId) async {
    return callService(
      domain: 'scene',
      service: 'turn_on',
      serviceData: {'entity_id': sceneId},
    );
  }

  /// Interprets natural voice commands for smart home controls.
  Future<String> handleVoiceCommand(String speech) async {
    final lower = speech.toLowerCase();

    // 1. Turn on lights / switch
    if (lower.contains('turn on') || lower.contains('switch on')) {
      int? brightness;
      if (lower.contains('%')) {
        final match = RegExp(r'(\d+)\s*%').firstMatch(lower);
        if (match != null) {
          brightness = int.tryParse(match.group(1)!);
        }
      }

      await turnOn(brightnessPct: brightness);
      return brightness != null
          ? 'Illumination calibrated to $brightness percent. Let me know if you need anything else.'
          : 'Smart lights engaged. All systems operating normally.';
    }

    // 2. Turn off lights / switches
    if (lower.contains('turn off') || lower.contains('switch off') || lower.contains('lights out')) {
      await turnOff();
      return 'Smart lighting deactivated. Environment dimmed.';
    }

    // 3. Dim lights
    if (lower.contains('dim')) {
      var pct = 20;
      final match = RegExp(r'(\d+)\s*%').firstMatch(lower);
      if (match != null) {
        pct = int.tryParse(match.group(1)!) ?? 20;
      }
      await turnOn(brightnessPct: pct);
      return 'Lights dimmed to $pct percent for optimal focus.';
    }

    // Default toggle
    await toggle();
    return 'Smart home device state updated for you.';
  }
}

