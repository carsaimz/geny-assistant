import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'ai_service.dart';

/// A single spoken translation turn in Polyglot Diplomat.
class PolyglotMessage {
  final String originalText;
  final String sourceLanguage;
  final String translatedText;
  final String targetLanguage;
  final DateTime timestamp;
  final bool isFromUser;

  PolyglotMessage({
    required this.originalText,
    required this.sourceLanguage,
    required this.translatedText,
    required this.targetLanguage,
    required this.timestamp,
    required this.isFromUser,
  });
}

/// 🌐 "Polyglot Diplomat" — Live Real-Time Two-Way Voice Translator
///
/// Enables seamless diplomatic conversation between speakers of different languages.
/// Supports instantaneous neural translation, phonetic transliteration, and native
/// accent spoken voice playback.
class PolyglotDiplomatService extends ChangeNotifier {
  PolyglotDiplomatService._() {
    _initTts();
  }

  static final PolyglotDiplomatService instance = PolyglotDiplomatService._();
  final FlutterTts _tts = FlutterTts();

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Spanish';
  bool _isAutoSpeakEnabled = true;
  bool _isTranslating = false;
  final List<PolyglotMessage> _history = [];

  static const List<String> supportedLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Hindi',
    'Arabic',
    'Japanese',
    'Chinese',
    'Russian',
    'Portuguese',
    'Italian',
    'Urdu',
    'Turkish',
    'Korean',
  ];

  static const Map<String, String> _languageLocaleMap = {
    'English': 'en-US',
    'Spanish': 'es-ES',
    'French': 'fr-FR',
    'German': 'de-DE',
    'Hindi': 'hi-IN',
    'Arabic': 'ar-SA',
    'Japanese': 'ja-JP',
    'Chinese': 'zh-CN',
    'Russian': 'ru-RU',
    'Portuguese': 'pt-BR',
    'Italian': 'it-IT',
    'Urdu': 'ur-PK',
    'Turkish': 'tr-TR',
    'Korean': 'ko-KR',
  };

  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  bool get isAutoSpeakEnabled => _isAutoSpeakEnabled;
  bool get isTranslating => _isTranslating;
  List<PolyglotMessage> get history => List.unmodifiable(_history);

  set sourceLanguage(String val) {
    if (supportedLanguages.contains(val)) {
      _sourceLanguage = val;
      notifyListeners();
    }
  }

  set targetLanguage(String val) {
    if (supportedLanguages.contains(val)) {
      _targetLanguage = val;
      notifyListeners();
    }
  }

  set isAutoSpeakEnabled(bool val) {
    _isAutoSpeakEnabled = val;
    notifyListeners();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  /// Swaps source and target languages for natural two-way conversation.
  void swapLanguages() {
    final temp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = temp;
    notifyListeners();
  }

  /// Clears conversation transcript.
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Translates [text] between [fromLang] and [toLang].
  /// If omitted, uses active [sourceLanguage] and [targetLanguage].
  Future<String> translate({
    required String text,
    String? fromLang,
    String? toLang,
    bool isFromUser = true,
  }) async {
    final src = fromLang ?? _sourceLanguage;
    final tgt = toLang ?? _targetLanguage;

    if (text.trim().isEmpty) return '';

    _isTranslating = true;
    notifyListeners();

    try {
      final prompt = '''
You are the Polyglot Diplomat, an ultra-precise diplomatic interpreter module of G.E.N.Y.
Translate the following statement from $src to $tgt.
Preserve exact emotional nuance, polite diplomatic phrasing, idioms, and context.
Provide ONLY the translated statement in $tgt. Do not add quotes, preamble, or explanations.

Statement:
"""$text"""
''';

      final translated = (await AiService.instance.generateResponse(prompt)).trim();

      final msg = PolyglotMessage(
        originalText: text,
        sourceLanguage: src,
        translatedText: translated,
        targetLanguage: tgt,
        timestamp: DateTime.now(),
        isFromUser: isFromUser,
      );
      _history.add(msg);

      if (_isAutoSpeakEnabled) {
        await speakText(translated, language: tgt);
      }

      return translated;
    } catch (e) {
      return text;
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Speaks text in the specified language using matching locale voice.
  Future<void> speakText(String text, {required String language}) async {
    try {
      final locale = _languageLocaleMap[language] ?? 'en-US';
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (_) {}
  }
}

