import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

/// Ultra-realistic Neural Text-To-Speech powered by Microsoft Studio Neural voices.
///
/// Produces broadcast-grade natural British human speech (Paul Bettany / GENY style)
/// with authentic breathing, cadence, and intonation.
class EdgeTtsService {
  EdgeTtsService._();
  static final EdgeTtsService instance = EdgeTtsService._();

  static const MethodChannel _channel =
      MethodChannel('com.privateagent/accessibility');

  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _secMsGecVersion = '2-143.0.3650.75';
  static const String _chromiumVersion = '143.0.3650.75';
  static const int _winEpoch = 11644473600;
  static const double _sToNs = 1e9;
  static const int _u32Mask = 0xFFFFFFFF;

  static const List<int> _sha256Initial = [
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
  ];

  static const List<int> _sha256State = [
    0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A,
    0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2,
  ];

  static const List<int> _sha256Schedule = [
    0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA,
    0xA622EE8C, 0xD1DD9491, 0xC0DD25A0, 0xF9E70AB6,
    0xF0C31573, 0x7058CE4E, 0x7188E606, 0x00E5AB33,
    0xD258B060, 0x72766564,
  ];

  static const List<int> _sha256RoundConstants = [
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
  ];

  static const int _sha256Adjustment = 0xC9DC06A7;
  static final List<int> _sha256BlockConstants = [
    ..._sha256RoundConstants.sublist(0, 14),
    _sha256Adjustment,
    ..._sha256RoundConstants.sublist(15),
  ];

  static const int _sha256Sigma0Adjustment = 0x059C0B80;
  static const int _sha256Sigma1Adjustment = 0x000B92C0;

  static const List<List<int>> _cs64Coefficients = [
    [0xE82E91B1, 0xB32700D0],
    [0x44DE24C6, 0x88DFF51D],
    [0x3BEB65BC, 0x29514038],
    [0xC89C5933, 0xB328CBDF],
    [0x8D1EC211, 0xD405B4D5],
    [0x314EF5D5, 0x26E55F3C],
    [0xE92491B1, 0x607801C6],
    [0xF0A5B9D5, 0x82B2C1FB],
    [0x06064CF3, 0xFA51A3DA],
    [0xDA79FA60, 0x207CC464],
    [0xBED20560, 0x3C3C74F3],
    [0x89F9C9F8, 0xD2D14B61],
    [0x35FA38C6, 0xBB04A2C1],
    [0xCB49E3C6, 0xC5626167],
  ];

  static const int _cs64Factor = 0x82893933;
  static const int _cs64Adjustment0 = 0xF2F90B1A;
  static const int _cs64Adjustment1 = 0x0B1A0000;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  // ---------------------------------------------------------------------------
  // DRM Sec-MS-GEC v2 Cryptographic Implementation
  // ---------------------------------------------------------------------------

  static int _rol16(int value) {
    final v = value & _u32Mask;
    return (((v << 16) | (v >>> 16)) & _u32Mask);
  }

  static List<int> _wordsLe4Even(Uint8List data) {
    final padLen = (4 - (data.length % 4)) % 4;
    final padded = Uint8List(data.length + padLen);
    padded.setRange(0, data.length, data);
    final words = <int>[];
    final bd = ByteData.sublistView(padded);
    for (var i = 0; i < padded.length; i += 4) {
      words.add(bd.getUint32(i, Endian.little));
    }
    if (words.length % 2 != 0) {
      words.add(0);
    }
    return words;
  }

  static int _sigma0(int value) {
    final v = value & _u32Mask;
    return (((v >>> 7) ^
            ((v << 25) & _u32Mask) ^
            (v >>> 18) ^
            ((v << 14) & _u32Mask) ^
            (v >>> 3)) &
        _u32Mask);
  }

  static int _sigma1(int value) {
    final v = value & _u32Mask;
    return (((v >>> 17) ^
            ((v << 15) & _u32Mask) ^
            (v >>> 19) ^
            ((v << 13) & _u32Mask) ^
            (v >>> 10)) &
        _u32Mask);
  }

  static List<int> _sha256Rounds(List<int> state, List<int> words,
      [int firstRound = 0]) {
    var a = state[0];
    var b = state[1];
    var c = state[2];
    var d = state[3];
    var e = state[4];
    var f = state[5];
    var g = state[6];
    var h = state[7];

    final constants =
        (firstRound == 14) ? _sha256BlockConstants : _sha256RoundConstants;
    final aligned = (firstRound == 14) ? 16 : 0;

    for (var index = firstRound; index < aligned; index++) {
      final rotE = e * 0x100000001;
      final rotA = a * 0x100000001;
      final t1 = (h +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (g ^ (e & (f ^ g))) +
              constants[index] +
              words[index]) &
          _u32Mask;
      final t2 = (((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((a & b) | (c & (a | b)))) &
          _u32Mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _u32Mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _u32Mask;
    }

    for (var index = aligned; index < 64; index += 8) {
      // 0
      var rotE = e * 0x100000001;
      var rotA = a * 0x100000001;
      var t1 = (h +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (g ^ (e & (f ^ g))) +
              constants[index] +
              words[index]) &
          _u32Mask;
      d = (d + t1) & _u32Mask;
      h = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((a & b) | (c & (a | b)))) &
          _u32Mask;
      // 1
      rotE = d * 0x100000001;
      rotA = h * 0x100000001;
      t1 = (g +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (f ^ (d & (e ^ f))) +
              constants[index + 1] +
              words[index + 1]) &
          _u32Mask;
      c = (c + t1) & _u32Mask;
      g = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((h & a) | (b & (h | a)))) &
          _u32Mask;
      // 2
      rotE = c * 0x100000001;
      rotA = g * 0x100000001;
      t1 = (f +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (e ^ (c & (d ^ e))) +
              constants[index + 2] +
              words[index + 2]) &
          _u32Mask;
      b = (b + t1) & _u32Mask;
      f = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((g & h) | (a & (g | h)))) &
          _u32Mask;
      // 3
      rotE = b * 0x100000001;
      rotA = f * 0x100000001;
      t1 = (e +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (d ^ (b & (c ^ d))) +
              constants[index + 3] +
              words[index + 3]) &
          _u32Mask;
      a = (a + t1) & _u32Mask;
      e = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((f & g) | (h & (f | g)))) &
          _u32Mask;
      // 4
      rotE = a * 0x100000001;
      rotA = e * 0x100000001;
      t1 = (d +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (c ^ (a & (b ^ c))) +
              constants[index + 4] +
              words[index + 4]) &
          _u32Mask;
      h = (h + t1) & _u32Mask;
      d = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((e & f) | (g & (e | f)))) &
          _u32Mask;
      // 5
      rotE = h * 0x100000001;
      rotA = d * 0x100000001;
      t1 = (c +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (b ^ (h & (a ^ b))) +
              constants[index + 5] +
              words[index + 5]) &
          _u32Mask;
      g = (g + t1) & _u32Mask;
      c = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((d & e) | (f & (d | e)))) &
          _u32Mask;
      // 6
      rotE = g * 0x100000001;
      rotA = c * 0x100000001;
      t1 = (b +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (a ^ (g & (h ^ a))) +
              constants[index + 6] +
              words[index + 6]) &
          _u32Mask;
      f = (f + t1) & _u32Mask;
      b = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((c & d) | (e & (c | d)))) &
          _u32Mask;
      // 7
      rotE = f * 0x100000001;
      rotA = b * 0x100000001;
      t1 = (a +
              ((rotE >>> 6) ^ (rotE >>> 11) ^ (rotE >>> 25)) +
              (h ^ (f & (g ^ h))) +
              constants[index + 7] +
              words[index + 7]) &
          _u32Mask;
      e = (e + t1) & _u32Mask;
      a = (t1 +
              ((rotA >>> 2) ^ (rotA >>> 13) ^ (rotA >>> 22)) +
              ((b & c) | (d & (b | c)))) &
          _u32Mask;
    }

    return [a, b, c, d, e, f, g, h];
  }

  static void _expandSha256Schedule(List<int> words, [int firstWord = 16]) {
    for (var index = firstWord; index < 64; index++) {
      final x = words[index - 2];
      final y = words[index - 15];
      final s1 = _sigma1(x);
      final s0 = _sigma0(y);
      words.add((s1 + words[index - 7] + s0 + words[index - 16]) & _u32Mask);
    }
  }

  static List<int> _sha256Init(Uint8List data) {
    final words = List<int>.filled(14, 0, growable: true);
    final bd = ByteData.sublistView(data);
    words.add((data[0] << 16) | (data[1] << 8) | data[2]);
    words.add(bd.getUint32(3, Endian.big));

    for (var index = 16; index < 30; index++) {
      var value = _sha256Schedule[index - 16];
      if (index - 2 >= 14) {
        value += (index == 16)
            ? (_sigma1(words[index - 2]) ^ _sha256Sigma1Adjustment)
            : _sigma1(words[index - 2]);
      }
      if (index - 7 >= 14) {
        value += words[index - 7];
      }
      if (index - 15 >= 14) {
        value += (index == 29)
            ? (_sigma0(words[index - 15]) ^ _sha256Sigma0Adjustment)
            : _sigma0(words[index - 15]);
      }
      words.add(value & _u32Mask);
    }

    words.add((_sigma1(words[28]) +
            words[23] +
            _sigma0(words[15]) +
            words[14] +
            _sha256Adjustment -
            _sha256RoundConstants[14]) &
        _u32Mask);

    _expandSha256Schedule(words, 31);
    final working = _sha256Rounds(_sha256State, words, 14);
    return List<int>.generate(
        8, (i) => (_sha256Initial[i] + working[i]) & _u32Mask);
  }

  static Uint8List _sha256Digest(Uint8List data) {
    final length = 57 + data.length;
    final padCount = ((55 - length) % 64 + 64) % 64;
    final tail = data.sublist(7);
    final padded = Uint8List(tail.length + 1 + padCount + 8);
    padded.setRange(0, tail.length, tail);
    padded[tail.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint64(padded.length - 8, length * 8, Endian.big);

    var state = _sha256Init(data.sublist(0, 7));
    for (var offset = 0; offset < padded.length; offset += 64) {
      final words = <int>[];
      for (var i = 0; i < 64; i += 4) {
        words.add(bd.getUint32(offset + i, Endian.big));
      }
      _expandSha256Schedule(words);
      final working = _sha256Rounds(state, words);
      state = List<int>.generate(8, (i) => (state[i] + working[i]) & _u32Mask);
    }

    final out = Uint8List(32);
    final outBd = ByteData.sublistView(out);
    for (var i = 0; i < 8; i++) {
      outBd.setUint32(i * 4, state[i], Endian.big);
    }
    return out;
  }

  static List<int> _cs64Digest(Uint8List data, Uint8List digest) {
    final bdDigest = ByteData.sublistView(digest);
    var keyA = bdDigest.getUint32(0, Endian.little) | 1;
    var keyB = bdDigest.getUint32(4, Endian.little) | 1;

    final factors = [
      (keyA * _cs64Factor) & _u32Mask,
      (keyB * _cs64Factor) & _u32Mask,
    ];

    final terms = <int>[];
    final offsets = <int>[];
    for (var i = 0; i < _cs64Coefficients.length; i++) {
      final coeff = _cs64Coefficients[i][0];
      final off = _cs64Coefficients[i][1];
      terms.add((coeff * factors[i % 2]) & _u32Mask);
      offsets.add(off);
    }

    final prefixedData = Uint8List(data.length + 1);
    prefixedData[0] = 0;
    prefixedData.setRange(1, prefixedData.length, data);

    final words = _wordsLe4Even(prefixedData);
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      var term = word * (index % 2 == 0 ? keyA : keyB);
      var offset = _rol16(word) * (index % 2 == 0 ? 0xEF0569FB : 0xC31713DB);
      if (index == 0) {
        term += _cs64Adjustment0 * factors[0];
        offset += _cs64Adjustment1;
      }
      terms.add(term & _u32Mask);
      offsets.add(offset & _u32Mask);
    }

    var swapAcc = 0;
    var swapLast = 0;
    var state = 0;
    var acc = 0;

    for (var index = 0; index < terms.length; index += 2) {
      final x = terms[index];
      final y = terms[index + 1];
      var t = _rol16((offsets[index] + x) & _u32Mask);
      var q = (t * 0x76F50F34) & _u32Mask;
      swapAcc = (swapAcc + (_rol16(q) * 0xC3EFEA97 + q)) & _u32Mask;

      t = _rol16((offsets[index + 1] + y) & _u32Mask);
      q = (t * 0x1881CE3C) & _u32Mask;
      swapLast = ((_rol16(q) * 0x35BD1EC9 + q)) & _u32Mask;
      swapAcc = (swapAcc + swapLast) & _u32Mask;

      state = (state * keyA + x) & _u32Mask;
      state = (_rol16(state) * 0xCF98B111) & _u32Mask;
      state = (_rol16(state) * 0x87085B9F) & _u32Mask;
      state = (_rol16(state) * 0x12CEB96D) & _u32Mask;
      state = (_rol16(state) * 0x257E1D83) & _u32Mask;
      acc = (acc + state) & _u32Mask;

      t = (state * keyB + y) & _u32Mask;
      t = (_rol16(t) * 0xA27416F5) & _u32Mask;
      t = (_rol16(t) * 0xD38396FF) & _u32Mask;
      state = (_rol16((_rol16(t) * 0x7C932B89) & _u32Mask) * 0xBFA49F69) &
          _u32Mask;
      acc = (acc + state) & _u32Mask;
    }

    return [(swapLast ^ state) & _u32Mask, (swapAcc ^ acc) & _u32Mask];
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  static String _generateSecMsGecV2([double? unixTimestamp]) {
    var ticks = unixTimestamp ??
        (DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0);
    ticks += _winEpoch;
    ticks -= ticks % 300;
    ticks *= (_sToNs / 100);
    final strToHash = '${ticks.toStringAsFixed(0)}$_trustedClientToken';
    final data = Uint8List.fromList(ascii.encode(strToHash));

    final digest = _sha256Digest(data);
    final cs64Words = _cs64Digest(data, digest);

    final cs64Bytes = Uint8List(8);
    final cs64Bd = ByteData.sublistView(cs64Bytes);
    cs64Bd.setUint32(0, cs64Words[0], Endian.little);
    cs64Bd.setUint32(4, cs64Words[1], Endian.little);

    final cs64Hex = _bytesToHex(cs64Bytes);
    final sha256Hex = _bytesToHex(digest);

    return '$cs64Hex-$sha256Hex';
  }

  static String _generateMuid() {
    final rng = Random.secure();
    final bytes =
        Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));
    return _bytesToHex(bytes);
  }

  static String _generateUuidNoDashes() {
    final rng = Random.secure();
    final bytes =
        Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));
    return _bytesToHex(bytes).toLowerCase();
  }

  static String _dateToString() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll('T', ' ')
        .split('.')
        .first;
  }

  // ---------------------------------------------------------------------------
  // Audio Synthesis & Playback
  // ---------------------------------------------------------------------------

  /// Synthesizes [text] using Edge Neural TTS and writes the resulting MP3
  /// into the device cache directory. Returns the local [File].
  Future<File?> synthesize(String text, {String? voice}) async {
    final selectedVoice = voice ?? SettingsService.instance.genyNeuralVoice;

    // Fast-path: Check disk cache
    final cacheDir = await getTemporaryDirectory();
    final genyDir = Directory('${cacheDir.path}/geny_audio');
    if (!genyDir.existsSync()) {
      genyDir.createSync(recursive: true);
    }

    final key = md5.convert(utf8.encode('$selectedVoice:$text')).toString();
    final cachedFile = File('${genyDir.path}/$key.mp3');
    if (cachedFile.existsSync() && cachedFile.lengthSync() > 1024) {
      return cachedFile;
    }

    final connId = _generateUuidNoDashes();
    final gec = _generateSecMsGecV2();
    final url =
        'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$_trustedClientToken&ConnectionId=$connId&Sec-MS-GEC=$gec&Sec-MS-GEC-Version=$_secMsGecVersion';

    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$_chromiumVersion Safari/537.36 Edg/$_chromiumVersion';

    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        url,
        customClient: client,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Accept-Encoding': 'gzip, deflate, br, zstd',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cookie': 'muid=${_generateMuid()};',
        },
      ).timeout(const Duration(seconds: 7));

      final configMsg = 'X-Timestamp:${_dateToString()}\r\n'
          'Content-Type:application/json; charset=utf-8\r\n'
          'Path:speech.config\r\n\r\n'
          '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n';
      ws.add(configMsg);

      final reqId = _generateUuidNoDashes();
      // Escape XML characters
      final escapedText = text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');

      final ssml =
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='$selectedVoice'><prosody pitch='+0Hz' rate='+0%' volume='+0%'>$escapedText</prosody></voice></speak>";

      final ssmlMsg = 'X-RequestId:$reqId\r\n'
          'Content-Type:application/ssml+xml\r\n'
          'X-Timestamp:${_dateToString()}Z\r\n'
          'Path:ssml\r\n\r\n'
          '$ssml';
      ws.add(ssmlMsg);

      final audioBytes = <int>[];
      final completer = Completer<void>();

      final sub = ws.listen(
        (message) {
          if (message is String) {
            if (message.contains('Path:turn.end')) {
              if (!completer.isCompleted) completer.complete();
            }
          } else if (message is List<int>) {
            if (message.length > 2) {
              final headerLen = (message[0] << 8) | message[1];
              if (message.length > headerLen + 2) {
                final chunk = message.sublist(headerLen + 2);
                audioBytes.addAll(chunk);
              }
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future.timeout(const Duration(seconds: 15));
      await sub.cancel();

      if (audioBytes.length > 512) {
        await cachedFile.writeAsBytes(audioBytes);
        return cachedFile;
      }
      return null;
    } catch (e) {
      debugPrint('[EdgeTtsService] Synthesis failed: $e');
      return null;
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
    }
  }

  /// Synthesizes and plays [text] through Android's native hardware MediaPlayer.
  ///
  /// Waits until playback completely finishes so speech is never cut off.
  Future<bool> speak(String text, {String? voice}) async {
    try {
      _isSpeaking = true;
      final file = await synthesize(text, voice: voice);
      if (file == null || !file.existsSync()) {
        _isSpeaking = false;
        return false;
      }

      final dynamic result = await _channel.invokeMethod('playAudioFile', {
        'path': file.path,
      });

      _isSpeaking = false;
      return result == true;
    } catch (e) {
      _isSpeaking = false;
      debugPrint('[EdgeTtsService] Speak error: $e');
      return false;
    }
  }

  /// Immediately terminates any currently playing audio.
  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
  }
}
