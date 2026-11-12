import '../services/voice_catalog_service.dart';

/// Lightweight internationalization for Geny.
///
/// Usage: `S.t(S.appTagline)` — resolves the string in the assistant's
/// configured language (SettingsService.assistantLanguage), falling back to
/// English when a translation is missing.
///
/// Languages: English (en), Português (pt), Français (fr), Español (es).
class S {
  S._();

  static String get _code => GenyVoiceCatalog.language().code;

  static String t(String key, [String? forcedLang]) {
    final entry = _dict[key];
    if (entry == null) return key;
    final c = (forcedLang ?? _code);
    return entry[c] ?? entry['en'] ?? key;
  }

  // -------------------------------------------------------------------
  // Keys
  // -------------------------------------------------------------------
  static const appTagline = 'app.tagline';
  static const homeTitle = 'home.title';
  static const chatHint = 'home.chatHint';
  static const askGeny = 'home.askGeny';
  static const modeAgent = 'home.modeAgent';
  static const modeChat = 'home.modeChat';
  static const modeGeny = 'home.modeGeny';
  static const settings = 'menu.settings';
  static const language = 'menu.language';
  static const voice = 'menu.voice';
  static const theme = 'menu.theme';
  static const history = 'menu.history';
  static const tasks = 'menu.tasks';
  static const cancel = 'btn.cancel';
  static const save = 'btn.save';
  static const close = 'btn.close';
  static const listening = 'voice.listening';
  static const tapToSpeak = 'voice.tapToSpeak';
  static const offlineModels = 'menu.offlineModels';
  static const onbWelcomeTitle = 'onb.welcome.title';
  static const onbWelcomeBody = 'onb.welcome.body';
  static const onbAiTitle = 'onb.ai.title';
  static const onbAiBody = 'onb.ai.body';
  static const onbScreenTitle = 'onb.screen.title';
  static const onbScreenBody = 'onb.screen.body';
  static const onbPrivacyTitle = 'onb.privacy.title';
  static const onbPrivacyBody = 'onb.privacy.body';
  static const onbGetStarted = 'onb.getStarted';
  static const onbEnableScreen = 'onb.enableScreen';
  static const onbScreenEnabled = 'onb.screenEnabled';
  static const onbScreenOff = 'onb.screenOff';
  static const privacyNote = 'onb.privacyNote';
}

const Map<String, Map<String, String>> _dict = {
  // --- App / home -----------------------------------------------------
  S.appTagline: {
    'en': 'Your private, multilingual AI genie',
    'pt': 'Seu gênio de IA privado e multilíngue',
    'fr': 'Votre génie privé et multilingue',
    'es': 'Tu genio privado y multilingüe',
  },
  S.homeTitle: {
    'en': 'Geny',
    'pt': 'Geny',
    'fr': 'Geny',
    'es': 'Geny',
  },
  S.chatHint: {
    'en': 'Ask me anything, or say "Hey Geny"...',
    'pt': 'Pergunte qualquer coisa, ou diga "Ei Geny"...',
    'fr': 'Demandez-moi ce que vous voulez, ou dites « Hey Geny »...',
    'es': 'Pregúntame lo que quieras, o di "Oye Geny"...',
  },
  S.askGeny: {
    'en': 'Ask Geny',
    'pt': 'Perguntar à Geny',
    'fr': 'Demander à Geny',
    'es': 'Preguntar a Geny',
  },
  S.modeAgent: {
    'en': 'Agent',
    'pt': 'Agente',
    'fr': 'Agent',
    'es': 'Agente',
  },
  S.modeChat: {
    'en': 'Chat',
    'pt': 'Conversa',
    'fr': 'Dialogue',
    'es': 'Chat',
  },
  S.modeGeny: {
    'en': 'Geny Mode',
    'pt': 'Modo Geny',
    'fr': 'Mode Geny',
    'es': 'Modo Geny',
  },
  // --- Menus / buttons --------------------------------------------------
  S.settings: {'en': 'Settings', 'pt': 'Configurações', 'fr': 'Paramètres', 'es': 'Ajustes'},
  S.language: {'en': 'Language', 'pt': 'Idioma', 'fr': 'Langue', 'es': 'Idioma'},
  S.voice: {'en': 'Voice', 'pt': 'Voz', 'fr': 'Voix', 'es': 'Voz'},
  S.theme: {'en': 'Theme', 'pt': 'Tema', 'fr': 'Thème', 'es': 'Tema'},
  S.history: {'en': 'History', 'pt': 'Histórico', 'fr': 'Historique', 'es': 'Historial'},
  S.tasks: {'en': 'Tasks', 'pt': 'Tarefas', 'fr': 'Tâches', 'es': 'Tareas'},
  S.cancel: {'en': 'Cancel', 'pt': 'Cancelar', 'fr': 'Annuler', 'es': 'Cancelar'},
  S.save: {'en': 'Save', 'pt': 'Salvar', 'fr': 'Enregistrer', 'es': 'Guardar'},
  S.close: {'en': 'Close', 'pt': 'Fechar', 'fr': 'Fermer', 'es': 'Cerrar'},
  S.listening: {'en': 'Listening...', 'pt': 'Ouvindo...', 'fr': 'Écoute...', 'es': 'Escuchando...'},
  S.tapToSpeak: {'en': 'Tap to speak', 'pt': 'Toque para falar', 'fr': 'Appuyez pour parler', 'es': 'Toca para hablar'},
  S.offlineModels: {
    'en': 'Offline AI Models',
    'pt': 'Modelos de IA Offline',
    'fr': 'Modèles IA Hors-ligne',
    'es': 'Modelos de IA Sin conexión',
  },
  // --- Onboarding -------------------------------------------------------
  S.onbWelcomeTitle: {
    'en': 'Welcome to Geny',
    'pt': 'Bem-vindo à Geny',
    'fr': 'Bienvenue chez Geny',
    'es': 'Bienvenido a Geny',
  },
  S.onbWelcomeBody: {
    'en': 'Your personal AI assistant — private by design, multilingual by nature. She listens, speaks and automates your device.',
    'pt': 'Sua assistente de IA pessoal — privada por design, multilíngue por natureza. Ela ouve, fala e automatiza seu aparelho.',
    'fr': 'Votre assistante IA personnelle — privée par conception, multilingue par nature. Elle écoute, parle et automatise votre appareil.',
    'es': 'Tu asistente de IA personal — privada por diseño, multilingüe por naturaleza. Escucha, habla y automatiza tu dispositivo.',
  },
  S.onbAiTitle: {
    'en': 'Connect your AI brain',
    'pt': 'Conecte o cérebro de IA',
    'fr': 'Connectez le cerveau IA',
    'es': 'Conecta el cerebro de IA',
  },
  S.onbAiBody: {
    'en': 'Bring your own API key (DeepSeek, OpenAI, Gemini, OpenRouter...) — or download an offline model later to run everything on-device.',
    'pt': 'Use sua própria chave de API (DeepSeek, OpenAI, Gemini, OpenRouter...) — ou baixe depois um modelo offline para rodar tudo no aparelho.',
    'fr': 'Apportez votre propre clé API (DeepSeek, OpenAI, Gemini, OpenRouter...) — ou téléchargez plus tard un modèle hors-ligne pour tout exécuter sur l\'appareil.',
    'es': 'Usa tu propia clave de API (DeepSeek, OpenAI, Gemini, OpenRouter...) — o descarga luego un modelo sin conexión para ejecutarlo todo en el dispositivo.',
  },
  S.onbScreenTitle: {
    'en': 'Screen automation (optional)',
    'pt': 'Automação de tela (opcional)',
    'fr': 'Automatisation d\'écran (optionnel)',
    'es': 'Automatización de pantalla (opcional)',
  },
  S.onbScreenBody: {
    'en': 'Geny can read the current screen and perform taps, swipes and typing on your behalf to complete tasks. Screen content is only sent to the AI provider you configure.',
    'pt': 'A Geny pode ler a tela atual e executar toques, deslizes e digitação por você para concluir tarefas. O conteúdo da tela só é enviado ao provedor de IA que você configurar.',
    'fr': 'Geny peut lire l\'écran actuel et effectuer des taps, des glissements et de la saisie en votre nom pour accomplir des tâches. Le contenu de l\'écran n\'est envoyé qu\'au fournisseur d\'IA que vous configurez.',
    'es': 'Geny puede leer la pantalla actual y realizar toques, deslizamientos y escritura en tu nombre para completar tareas. El contenido de la pantalla solo se envía al proveedor de IA que configures.',
  },
  S.onbPrivacyTitle: {
    'en': 'Privacy first',
    'pt': 'Privacidade em primeiro lugar',
    'fr': 'La confidentialité d\'abord',
    'es': 'Privacidad primero',
  },
  S.onbPrivacyBody: {
    'en': 'Your keys, your data, your device. Nothing leaves your phone except what you explicitly configure: your AI provider, your Telegram bot, your smart home. No telemetry. No trackers.',
    'pt': 'Suas chaves, seus dados, seu aparelho. Nada sai do seu telefone além do que você configurar explicitamente: seu provedor de IA, seu bot do Telegram, sua casa inteligente. Sem telemetria. Sem rastreadores.',
    'fr': 'Vos clés, vos données, votre appareil. Rien ne quitte votre téléphone sauf ce que vous configurez explicitement : votre fournisseur d\'IA, votre bot Telegram, votre maison connectée. Aucune télémétrie. Aucun traceur.',
    'es': 'Tus claves, tus datos, tu dispositivo. Nada sale de tu teléfono salvo lo que configures explícitamente: tu proveedor de IA, tu bot de Telegram, tu casa inteligente. Sin telemetría. Sin rastreadores.',
  },
  S.onbGetStarted: {
    'en': 'Get Started',
    'pt': 'Começar',
    'fr': 'Commencer',
    'es': 'Empezar',
  },
  S.onbEnableScreen: {
    'en': 'Enable Screen Control',
    'pt': 'Ativar controle de tela',
    'fr': 'Activer le contrôle d\'écran',
    'es': 'Activar control de pantalla',
  },
  S.onbScreenEnabled: {
    'en': 'Geny Screen Control is enabled',
    'pt': 'O controle de tela da Geny está ativado',
    'fr': 'Le contrôle d\'écran Geny est activé',
    'es': 'El control de pantalla de Geny está activado',
  },
  S.onbScreenOff: {
    'en': 'Geny Screen Control is OFF',
    'pt': 'O controle de tela da Geny está DESLIGADO',
    'fr': 'Le contrôle d\'écran Geny est DÉSACTIVÉ',
    'es': 'El control de pantalla de Geny está APAGADO',
  },
  S.privacyNote: {
    'en': 'No telemetry. No trackers. Data goes only where you configure it.',
    'pt': 'Sem telemetria. Sem rastreadores. Os dados vão apenas onde você configurar.',
    'fr': 'Aucune télémétrie. Aucun traceur. Les données vont uniquement où vous les configurez.',
    'es': 'Sin telemetría. Sin rastreadores. Los datos van solo donde los configures.',
  },
};
