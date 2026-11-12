import 'settings_service.dart';

/// One neural (Edge TTS) voice entry in the catalog.
class NeuralVoiceOption {
  final String id; // e.g. pt-BR-FranciscaNeural
  final String displayName;
  final bool female;
  final String locale; // e.g. pt-BR

  const NeuralVoiceOption({
    required this.id,
    required this.displayName,
    required this.female,
    required this.locale,
  });
}

/// One supported assistant language: UI translations, STT locale and
/// default TTS voices (female by default — Geny is a female assistant).
class AssistantLanguage {
  final String code; // 'en', 'pt', 'fr', 'es'
  final String label; // endonym shown in the UI
  final String englishName;
  final String sttLocale; // SpeechRecognizer locale
  final String ttsLocale; // flutter_tts (system offline TTS) locale
  final String defaultNeuralVoice; // female default
  final String llmName; // name used in the AI system prompt
  final List<NeuralVoiceOption> neuralVoices;

  const AssistantLanguage({
    required this.code,
    required this.label,
    required this.englishName,
    required this.sttLocale,
    required this.ttsLocale,
    required this.defaultNeuralVoice,
    required this.llmName,
    required this.neuralVoices,
  });
}

/// Multilingual voice & language catalog for Geny.
///
/// - Neural (Edge TTS) voices are streamed from Microsoft Studio servers and
///   cached on device — highest quality, requires internet.
/// - Offline (system TTS) voices use the Android TTS engine; their language
///   data packs can be downloaded from the system Text-to-Speech settings,
///   which Geny can open directly ("Download offline voices").
class GenyVoiceCatalog {
  GenyVoiceCatalog._();

  static const List<NeuralVoiceOption> _en = [
    NeuralVoiceOption(id: 'en-GB-SoniaNeural', displayName: 'Sonia (British)', female: true, locale: 'en-GB'),
    NeuralVoiceOption(id: 'en-US-AvaNeural', displayName: 'Ava (American)', female: true, locale: 'en-US'),
    NeuralVoiceOption(id: 'en-US-EmmaNeural', displayName: 'Emma (American)', female: true, locale: 'en-US'),
    NeuralVoiceOption(id: 'en-GB-LibbyNeural', displayName: 'Libby (British)', female: true, locale: 'en-GB'),
    NeuralVoiceOption(id: 'en-US-AndrewNeural', displayName: 'Andrew (American)', female: false, locale: 'en-US'),
    NeuralVoiceOption(id: 'en-GB-RyanNeural', displayName: 'Ryan (British)', female: false, locale: 'en-GB'),
  ];

  static const List<NeuralVoiceOption> _pt = [
    NeuralVoiceOption(id: 'pt-BR-FranciscaNeural', displayName: 'Francisca (Brasil)', female: true, locale: 'pt-BR'),
    NeuralVoiceOption(id: 'pt-BR-ThalitaNeural', displayName: 'Thalita (Brasil)', female: true, locale: 'pt-BR'),
    NeuralVoiceOption(id: 'pt-PT-FernandaNeural', displayName: 'Fernanda (Portugal)', female: true, locale: 'pt-PT'),
    NeuralVoiceOption(id: 'pt-BR-AntonioNeural', displayName: 'Antônio (Brasil)', female: false, locale: 'pt-BR'),
    NeuralVoiceOption(id: 'pt-PT-DuarteNeural', displayName: 'Duarte (Portugal)', female: false, locale: 'pt-PT'),
  ];

  static const List<NeuralVoiceOption> _fr = [
    NeuralVoiceOption(id: 'fr-FR-DeniseNeural', displayName: 'Denise (France)', female: true, locale: 'fr-FR'),
    NeuralVoiceOption(id: 'fr-FR-EloiseNeural', displayName: 'Éloïse (France)', female: true, locale: 'fr-FR'),
    NeuralVoiceOption(id: 'fr-FR-VivienneNeural', displayName: 'Vivienne (France)', female: true, locale: 'fr-FR'),
    NeuralVoiceOption(id: 'fr-CA-SylvieNeural', displayName: 'Sylvie (Canada)', female: true, locale: 'fr-CA'),
    NeuralVoiceOption(id: 'fr-FR-HenriNeural', displayName: 'Henri (France)', female: false, locale: 'fr-FR'),
  ];

  static const List<NeuralVoiceOption> _es = [
    NeuralVoiceOption(id: 'es-ES-ElviraNeural', displayName: 'Elvira (España)', female: true, locale: 'es-ES'),
    NeuralVoiceOption(id: 'es-MX-DaliaNeural', displayName: 'Dalia (México)', female: true, locale: 'es-MX'),
    NeuralVoiceOption(id: 'es-CO-SalomeNeural', displayName: 'Salomé (Colombia)', female: true, locale: 'es-CO'),
    NeuralVoiceOption(id: 'es-ES-AlvaroNeural', displayName: 'Álvaro (España)', female: false, locale: 'es-ES'),
    NeuralVoiceOption(id: 'es-MX-JorgeNeural', displayName: 'Jorge (México)', female: false, locale: 'es-MX'),
  ];

  static const List<AssistantLanguage> languages = [
    AssistantLanguage(
      code: 'en',
      label: 'English',
      englishName: 'English',
      sttLocale: 'en-US',
      ttsLocale: 'en-US',
      defaultNeuralVoice: 'en-GB-SoniaNeural',
      llmName: 'English',
      neuralVoices: _en,
    ),
    AssistantLanguage(
      code: 'pt',
      label: 'Português',
      englishName: 'Portuguese',
      sttLocale: 'pt-BR',
      ttsLocale: 'pt-BR',
      defaultNeuralVoice: 'pt-BR-FranciscaNeural',
      llmName: 'Portuguese',
      neuralVoices: _pt,
    ),
    AssistantLanguage(
      code: 'fr',
      label: 'Français',
      englishName: 'French',
      sttLocale: 'fr-FR',
      ttsLocale: 'fr-FR',
      defaultNeuralVoice: 'fr-FR-DeniseNeural',
      llmName: 'French',
      neuralVoices: _fr,
    ),
    AssistantLanguage(
      code: 'es',
      label: 'Español',
      englishName: 'Spanish',
      sttLocale: 'es-ES',
      ttsLocale: 'es-ES',
      defaultNeuralVoice: 'es-ES-ElviraNeural',
      llmName: 'Spanish',
      neuralVoices: _es,
    ),
  ];

  /// Returns the language config for [code]; falls back to English.
  static AssistantLanguage language([String? code]) {
    final c = (code ?? SettingsService.instance.assistantLanguage).toLowerCase();
    for (final l in languages) {
      if (l.code == c) return l;
    }
    return languages.first;
  }

  /// Resolves the active neural voice: keeps a user-picked voice when it
  /// belongs to the selected language, otherwise uses the language's
  /// female default.
  static String resolveNeuralVoice([String? languageCode]) {
    final settings = SettingsService.instance;
    final lang = language(languageCode);
    final chosen = settings.genyNeuralVoice;
    final belongs = lang.neuralVoices.any((v) => v.id == chosen);
    if (chosen.isNotEmpty && belongs) return chosen;
    return lang.defaultNeuralVoice;
  }
}
