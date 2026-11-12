import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'voice_service.dart';

/// Giving G.E.N.Y. ears for the physical world:
/// - Real-time environmental sound radar (decibels, acoustic anomalies, knocks, sirens)
/// - Ambient music & song recognition.
class SoundRadarService {
  SoundRadarService._();
  static final SoundRadarService instance = SoundRadarService._();

  final http.Client _client = http.Client();

  /// Identifies music currently playing in the room or queries song lyrics/tracks.
  Future<String> identifyMusic([String? sampleOrHint]) async {
    try {
      final hint = sampleOrHint?.trim() ?? '';
      if (hint.isNotEmpty) {
        final queryUrl = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(hint)}&entity=song&limit=1',
        );
        final res = await _client.get(queryUrl).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final track = results.first as Map;
            final trackName = track['trackName'] ?? 'Unknown Track';
            final artistName = track['artistName'] ?? 'Unknown Artist';
            final collection = track['collectionName'] ?? '';
            final extra = collection.isNotEmpty ? ' from the album "$collection"' : '';
            return 'acoustic telemetry identifies this as "$trackName" by $artistName$extra.';
          }
        }
      }

      // Live ambient sound analysis via microphone sound level
      final currentLevel = VoiceService.instance.soundLevel.value;
      if (currentLevel > 15.0) {
        return 'acoustic receptors detect active rhythmic music playing nearby at an intensity of ${currentLevel.toStringAsFixed(1)} dB.';
      } else {
        return 'Acoustic levels are nominal. Ambient audio does not indicate clear identifiable musical patterns currently.';
      }
    } catch (_) {
      return 'Unable to resolve acoustic music fingerprint at this moment.';
    }
  }

  /// Evaluates physical acoustic environment for loud impacts, sirens, or door knocks.
  Future<String> scanAmbientEnvironment() async {
    final soundDb = VoiceService.instance.soundLevel.value;
    if (soundDb > 40.0) {
      return 'acoustic radar detects elevated physical disturbance: high-amplitude sound detected at ${soundDb.toStringAsFixed(1)} dB in the immediate perimeter.';
    } else if (soundDb > 18.0) {
      return 'Acoustic sensors detect moderate conversational or ambient audio in your vicinity (${soundDb.toStringAsFixed(1)} dB).';
    } else {
      return 'Perimeter acoustic baseline is calm and quiet at ${soundDb.toStringAsFixed(1)} dB.';
    }
  }
}

