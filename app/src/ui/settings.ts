/**
 * Painel de configurações: modo de operação, backend remoto/self-hosted,
 * idioma, voz (Fase 2) e nota de privacidade. No Android, a chave de API é
 * delegada ao Keystore via ponte nativa; no web fica em localStorage
 * (apenas dev).
 */
import { bridge } from '../core/bridge';
import type { VoiceEvent } from '../core/voice-types';
import type { VoiceCapabilities, WhisperModelStatus } from '../core/voice-types';
import { LOCALES, t, tf } from '../i18n';
import type { Settings } from '../types';

export interface SettingsCallbacks {
  onSave: (s: Settings) => void;
}

const MODEL_LABELS: Record<string, string> = {
  'whisper-tiny': 'Tiny (~74 MB)',
  'whisper-base': 'Base (~141 MB)',
  'whisper-small': 'Small (~465 MB)',
  'whisper-medium': 'Medium (~1,4 GB)',
};

export function renderSettingsDrawer(
  drawer: HTMLElement,
  settings: Settings,
  cb: SettingsCallbacks,
): void {
  drawer.innerHTML = `
    <header class="drawer-head">
      <h2>${t('settings.title')}</h2>
      <button type="button" class="icon-btn" id="btn-close-settings" aria-label="${t('settings.title')}">✕</button>
    </header>
    <form id="settings-form" class="drawer-body">
      <label>
        <span>${t('settings.mode')}</span>
        <select id="set-mode">
          <option value="local">${t('settings.mode.local')}</option>
          <option value="remote">${t('settings.mode.remote')}</option>
          <option value="selfhosted">${t('settings.mode.selfhosted')}</option>
        </select>
      </label>
      <label>
        <span>${t('settings.baseUrl')}</span>
        <input id="set-baseurl" type="url" placeholder="http://localhost:11434/v1" />
      </label>
      <label>
        <span>${t('settings.model')}</span>
        <input id="set-model" type="text" placeholder="qwen2.5:1.5b" />
      </label>
      <label>
        <span>${t('settings.apiKey')}</span>
        <input id="set-apikey" type="password" placeholder="sk-…" autocomplete="off" />
        <small>${t('settings.apiKey.desc')}</small>
      </label>
      <label>
        <span>${t('settings.language')}</span>
        <select id="set-lang">
          ${LOCALES.map((l) => `<option value="${l.code}">${l.label}</option>`).join('')}
        </select>
      </label>

      <h3 class="drawer-section">${t('settings.voice.title')}</h3>
      <label class="check-row">
        <input id="set-voice-replies" type="checkbox" />
        <span>${t('settings.voice.replies')}</span>
      </label>
      <label>
        <span>${t('settings.voice.engine')}</span>
        <select id="set-stt-engine">
          <option value="system">${t('settings.voice.engine.system')}</option>
          <option value="whisper">${t('settings.voice.engine.whisper')}</option>
        </select>
        <small id="set-whisper-hint" hidden>${t('settings.voice.whisper.unavailable')}</small>
      </label>
      <label class="check-row">
        <input id="set-vad-autostop" type="checkbox" />
        <span>${t('settings.voice.vad')}</span>
        <small>${t('settings.voice.vad.desc')}</small>
      </label>
      <label>
        <span>${t('settings.voice.model')}</span>
        <select id="set-whisper-model">
          ${['whisper-tiny', 'whisper-base', 'whisper-small', 'whisper-medium']
            .map((id) => `<option value="${id}">${MODEL_LABELS[id] ?? id}</option>`)
            .join('')}
        </select>
        <small>${t('settings.voice.model.hint')}</small>
      </label>
      <div id="voice-model-status" class="model-status" hidden></div>

      <p class="privacy-note">${t('settings.privacy')}</p>
      <button type="submit" class="btn-primary">${t('settings.save')}</button>
    </form>`;

  const $ = <T extends HTMLElement>(id: string): T => {
    const el = drawer.querySelector(`#${id}`);
    if (el === null) throw new Error(`elemento ausente: ${id}`);
    return el as T;
  };

  const mode = $<HTMLSelectElement>('set-mode');
  const baseUrl = $<HTMLInputElement>('set-baseurl');
  const model = $<HTMLInputElement>('set-model');
  const apiKey = $<HTMLInputElement>('set-apikey');
  const lang = $<HTMLSelectElement>('set-lang');
  const voiceReplies = $<HTMLInputElement>('set-voice-replies');
  const sttEngine = $<HTMLSelectElement>('set-stt-engine');
  const vadAutoStop = $<HTMLInputElement>('set-vad-autostop');
  const whisperModel = $<HTMLSelectElement>('set-whisper-model');
  const whisperHint = $<HTMLElement>('set-whisper-hint');
  const modelStatus = $<HTMLElement>('voice-model-status');

  mode.value = settings.mode;
  baseUrl.value = settings.baseUrl;
  model.value = settings.model;
  lang.value = settings.language;
  voiceReplies.checked = settings.voiceReplies;
  sttEngine.value = settings.sttEngine;
  vadAutoStop.checked = settings.vadAutoStop;
  whisperModel.value = settings.whisperModel;
  if (settings.apiKeySet) apiKey.placeholder = '••••••••';

  // Capacidades de voz: whisper nativo + estado dos modelos (async).
  let caps: VoiceCapabilities | null = null;
  let modelStates = new Map<string, WhisperModelStatus>();
  void bridge
    .getVoiceCapabilities()
    .then(({ json }) => {
      caps = JSON.parse(json) as VoiceCapabilities;
      modelStates = new Map(caps.whisperModels.map((m) => [m.id, m]));
      if (!caps.whisperNative && sttEngine.value === 'whisper') {
        sttEngine.value = 'system';
      }
      whisperHint.hidden = caps.whisperNative;
      refreshModelRow();
    })
    .catch(() => {
      // sem capacidades (web sem suporte): mantém os defaults
    });

  const modelRowLabel = (id: string): string => {
    const state = modelStates.get(id);
    if (!state) return MODEL_LABELS[id] ?? id;
    return `${MODEL_LABELS[id] ?? id}${state.downloaded ? ' ✓' : ''}`;
  };

  const refreshModelRow = (): void => {
    const id = whisperModel.value;
    const option = whisperModel.options.item(whisperModel.selectedIndex);
    if (option !== null) option.textContent = modelRowLabel(id);
    const state = modelStates.get(id);
    if (!state) return;
    if (!state.downloaded && caps?.whisperNative) {
      modelStatus.hidden = false;
      modelStatus.textContent = '';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn-primary btn-small';
      btn.textContent = `${t('settings.voice.model.download')} — ${modelRowLabel(id)}`;
      btn.addEventListener('click', () => {
        btn.disabled = true;
        btn.textContent = `${t('settings.voice.model.downloading')} 0%`;
        void bridge.downloadVoiceModel({ kind: 'stt', id });
      });
      modelStatus.appendChild(btn);
    } else if (state.downloaded) {
      modelStatus.hidden = false;
      modelStatus.textContent = '';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn-danger btn-small';
      btn.textContent = t('settings.voice.model.delete');
      btn.addEventListener('click', () => {
        void bridge.deleteVoiceModel({ file: state.file }).then(() => {
          state.downloaded = false;
          refreshModelRow();
        });
      });
      modelStatus.appendChild(btn);
    } else {
      modelStatus.hidden = true;
    }
  };

  whisperModel.addEventListener('change', refreshModelRow);

  // Eventos de download de modelo vindos do VoiceController (via window).
  const onModelEvent = (ev: Event): void => {
    const event = (ev as CustomEvent<VoiceEvent>).detail;
    if (event.type === 'modelProgress') {
      modelStatus.hidden = false;
      modelStatus.textContent = tf('settings.voice.model.progress', {
        pct: Math.min(100, Math.round((event.bytes / Math.max(1, event.total)) * 100)),
      });
    } else if (event.type === 'modelReady') {
      const state = modelStates.get(event.id);
      if (state) state.downloaded = true;
      refreshModelRow();
    } else if (event.type === 'modelError') {
      modelStatus.hidden = false;
      modelStatus.textContent = event.message ?? 'erro';
    }
  };
  window.addEventListener('geny:model-event', onModelEvent);
  drawer.addEventListener('geny:drawer-closed', () => {
    window.removeEventListener('geny:model-event', onModelEvent);
  });

  $<HTMLButtonElement>('btn-close-settings').addEventListener('click', () => {
    drawer.dispatchEvent(new CustomEvent('geny:drawer-closed'));
    drawer.hidden = true;
  });

  $<HTMLFormElement>('settings-form').addEventListener('submit', (ev) => {
    ev.preventDefault();
    cb.onSave({
      mode: mode.value as Settings['mode'],
      language: lang.value,
      model: model.value.trim(),
      baseUrl: baseUrl.value.trim(),
      apiKeySet: settings.apiKeySet || apiKey.value.trim().length > 0,
      voiceReplies: voiceReplies.checked,
      sttEngine: sttEngine.value as Settings['sttEngine'],
      vadAutoStop: vadAutoStop.checked,
      whisperModel: whisperModel.value,
    });
    const key = apiKey.value.trim();
    if (key.length > 0) {
      localStorage.setItem('geny.apikey', key);
    }
    apiKey.value = '';
    window.setTimeout(() => {
      drawer.dispatchEvent(new CustomEvent('geny:drawer-closed'));
      drawer.hidden = true;
    }, 450);
  });
}
