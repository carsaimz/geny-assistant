/**
 * Bootstrap do app Geny Assistant (camada de apresentação).
 * Liga bridge, i18n, chat, voz e configurações.
 */
import './style.css';
import { bridge } from './core/bridge';
import type { RemoteConfig } from './core/remote';
import { applyI18nDom, setLocale, t } from './i18n';
import type { Settings } from './types';
import { ChatUI } from './ui/chat';
import { renderSettingsDrawer } from './ui/settings';
import { VoiceController } from './ui/voice';

const SETTINGS_KEY = 'geny.settings';

function defaultSettings(): Settings {
  return {
    mode: 'local',
    language: navigator.language.startsWith('pt') ? navigator.language : 'pt-BR',
    model: '',
    baseUrl: '',
    apiKeySet: false,
    voiceReplies: false,
    sttEngine: 'system',
    vadAutoStop: true,
    whisperModel: 'whisper-tiny',
    localModel: '',
    localTemperature: 0.7,
    localSeed: -1,
    ttsEngine: 'system' as const,
  };
}

function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (raw !== null) {
      return { ...defaultSettings(), ...(JSON.parse(raw) as Partial<Settings>) };
    }
  } catch {
    // configurações corrompidas: recomeça com padrões
  }
  return defaultSettings();
}

function loadRemoteConfig(settings: Settings): RemoteConfig | null {
  const apiKey = localStorage.getItem('geny.apikey') ?? '';
  if (settings.baseUrl.length === 0 || settings.model.length === 0) return null;
  return { baseUrl: settings.baseUrl, apiKey, model: settings.model };
}

async function refreshStatus(): Promise<void> {
  const el = document.getElementById('status');
  if (el === null) return;
  try {
    const { json } = await bridge.getDeviceContext();
    const ctx = JSON.parse(json) as { online: boolean; rootAvailable: boolean };
    el.textContent = !ctx.online ? t('status.offline') : t('status.ready');
    el.className = `status ${ctx.online ? 'status-online' : 'status-offline'}`;
  } catch {
    el.textContent = t('status.ready');
  }
}

function redrawStatic(inputEl: HTMLInputElement): void {
  const tagline = document.getElementById('app-tagline');
  if (tagline !== null) tagline.textContent = t('app.tagline');
  inputEl.placeholder = t('chat.placeholder');
  applyI18nDom();
  void refreshStatus();
}

function $(id: string): HTMLElement {
  const el = document.getElementById(id);
  if (el === null) throw new Error(`DOM incompleto: ${id}`);
  return el;
}

async function boot(): Promise<void> {
  let currentSettings: Settings = loadSettings();
  setLocale(currentSettings.language);

  const chatEl = $('chat');
  const composer = $('composer');
  const input = $('input');
  const btnSend = $('btn-send');
  const btnSettings = $('btn-settings');
  const drawer = $('settings-drawer');
  const btnStopGen = $('btn-stop-gen');
  if (
    !(chatEl instanceof HTMLElement) ||
    !(composer instanceof HTMLFormElement) ||
    !(input instanceof HTMLInputElement) ||
    !(btnSend instanceof HTMLButtonElement) ||
    !(btnSettings instanceof HTMLButtonElement) ||
    !(btnStopGen instanceof HTMLButtonElement) ||
    !(drawer instanceof HTMLElement)
  ) {
    throw new Error('DOM incompleto');
  }

  const chat = new ChatUI(chatEl, {
    getSettings: () => currentSettings,
    getRemoteConfig: () => loadRemoteConfig(currentSettings),
    onStatusChange: (busy) => {
      btnSend.disabled = busy;
      void refreshStatus();
    },
    onAssistantReply: (text) => {
      // Responder por voz (docs §7.4): TTS local do texto da Geny.
      if (currentSettings.voiceReplies) {
        void bridge.speak({
          text,
          language: currentSettings.language,
          engine: currentSettings.ttsEngine ?? 'system',
        });
      }
      // Tela de voz: registra a resposta e dispara o ciclo mãos-livres.
      voice.notifyAssistantReply(text);
    },
    onLocalStream: (active) => {
      // Streaming do LLM local (TODO core-05b): mostra o botão de parar.
      btnStopGen.hidden = !active;
    },
  });

  const voice = new VoiceController(
    {
      micBtn: $('btn-mic') as HTMLButtonElement,
      panel: $('voice-panel'),
      dot: $('voice-dot'),
      statusText: $('voice-status-text'),
      levelBar: $('voice-level-bar'),
      transcript: $('voice-transcript'),
      stop: $('btn-voice-stop') as HTMLButtonElement,
      cancel: $('btn-voice-cancel') as HTMLButtonElement,
    },
    {
      getEngine: () => currentSettings.sttEngine,
      getLanguage: () => currentSettings.language,
      getVadAutoStop: () => currentSettings.vadAutoStop,
      getWhisperModel: () => currentSettings.whisperModel,
      getVoiceReplies: () => currentSettings.voiceReplies,
      onSend: (text) => {
        input.value = '';
        void chat.send(text);
      },
      onModelEvent: (event) => {
        window.dispatchEvent(new CustomEvent('geny:model-event', { detail: event }));
      },
    },
    {
      screen: $('voice-screen'),
      orb: $('voice-orb'),
      caption: $('voice-caption'),
      log: $('voice-log'),
      close: $('btn-voice-close') as HTMLButtonElement,
      bigMic: $('btn-voice-big') as HTMLButtonElement,
      handsFree: $('btn-voice-handsfree') as HTMLButtonElement,
      stopAudio: $('btn-voice-stop-audio') as HTMLButtonElement,
    },
  );

  const openDrawer = (): void => {
    renderSettingsDrawer(drawer, currentSettings, {
      onSave: (s) => {
        currentSettings = s;
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(s));
        setLocale(s.language);
        redrawStatic(input);
        drawer.hidden = true;
      },
    });
    drawer.hidden = false;
  };

  btnSettings.addEventListener('click', openDrawer);

  btnStopGen.addEventListener('click', () => {
    // Parada do streaming (TODO core-05b): o motor devolve o texto parcial.
    void bridge.stopLocalGenerate();
  });

  composer.addEventListener('submit', (ev) => {
    ev.preventDefault();
    const text = input.value;
    input.value = '';
    void chat.send(text);
  });

  window.addEventListener('online', () => void refreshStatus());
  window.addEventListener('offline', () => void refreshStatus());

  // Eventos do LLM local (Fase 3): re-difunde para a UI de configurações.
  void bridge.addListener('genyLlm', (event) => {
    window.dispatchEvent(new CustomEvent('geny:llm-event', { detail: event }));
  });

  await chat.init();
  await voice.init();
  redrawStatic(input);
  input.focus();
}

void boot().catch((err) => {
  console.error('falha ao iniciar o Geny Assistant', err);
});
