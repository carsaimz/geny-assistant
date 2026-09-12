/**
 * Bootstrap do app Geny Assistant (camada de apresentação).
 * Liga bridge, i18n, chat e configurações.
 */
import './style.css';
import { bridge } from './core/bridge';
import type { RemoteConfig } from './core/remote';
import { applyI18nDom, setLocale, t } from './i18n';
import type { Settings } from './types';
import { ChatUI } from './ui/chat';
import { renderSettingsDrawer } from './ui/settings';

const SETTINGS_KEY = 'geny.settings';

function defaultSettings(): Settings {
  return {
    mode: 'local',
    language: navigator.language.startsWith('pt') ? navigator.language : 'pt-BR',
    model: '',
    baseUrl: '',
    apiKeySet: false,
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

async function boot(): Promise<void> {
  let currentSettings: Settings = loadSettings();
  setLocale(currentSettings.language);

  const chatEl = document.getElementById('chat');
  const composer = document.getElementById('composer');
  const input = document.getElementById('input');
  const btnSend = document.getElementById('btn-send');
  const btnSettings = document.getElementById('btn-settings');
  const drawer = document.getElementById('settings-drawer');
  if (
    !(chatEl instanceof HTMLElement) ||
    !(composer instanceof HTMLFormElement) ||
    !(input instanceof HTMLInputElement) ||
    !(btnSend instanceof HTMLButtonElement) ||
    !(btnSettings instanceof HTMLButtonElement) ||
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
  });

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

  composer.addEventListener('submit', (ev) => {
    ev.preventDefault();
    const text = input.value;
    input.value = '';
    void chat.send(text);
  });

  window.addEventListener('online', () => void refreshStatus());
  window.addEventListener('offline', () => void refreshStatus());

  await chat.init();
  redrawStatic(input);
  input.focus();
}

void boot().catch((err) => {
  console.error('falha ao iniciar o Geny Assistant', err);
});
