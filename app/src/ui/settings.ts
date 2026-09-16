/**
 * Painel de configurações: modo de operação, backend remoto/self-hosted,
 * idioma, voz (Fase 2) e nota de privacidade. No Android, a chave de API é
 * delegada ao Keystore via ponte nativa; no web fica em localStorage
 * (apenas dev).
 */
import { Capacitor } from '@capacitor/core';
import { bridge } from '../core/bridge';
import type { VoiceEvent } from '../core/voice-types';
import type { VoiceCapabilities, WhisperModelStatus } from '../core/voice-types';
import type { LlmCapabilities, LlmEvent, LlmModelStatus } from '../core/llm-types';
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

const LLM_FALLBACK_LABELS: Record<string, string> = {
  'qwen2.5-0.5b-instruct': 'Qwen2.5 0.5B (~469 MB)',
  'llama-3.2-1b-instruct': 'Llama 3.2 1B (~770 MB)',
  'qwen2.5-1.5b-instruct': 'Qwen2.5 1.5B (~1,0 GB)',
  'gemma-2-2b-it': 'Gemma 2 2B (~1,6 GB)',
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
          <option value="auto">${t('settings.mode.auto')}</option>
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

      <h3 class="drawer-section">${t('settings.tts.title')}</h3>
      <label>
        <span>${t('settings.tts.engine')}</span>
        <select id="set-tts-engine">
          <option value="system">${t('settings.tts.engine.system')}</option>
          <option value="piper">${t('settings.tts.engine.piper')}</option>
        </select>
        <small id="set-piper-hint" hidden>${t('settings.tts.piper.unavailable')}</small>
      </label>
      <div id="piper-voices" class="model-status" hidden></div>

      <h3 class="drawer-section">${t('settings.llm.title')}</h3>
      <label>
        <span>${t('settings.llm.model')}</span>
        <select id="set-llm-model">
          <option value="">${t('settings.llm.model.none')}</option>
        </select>
        <small id="set-llm-hint" hidden>${t('settings.llm.unavailable')}</small>
      </label>
      <div class="check-row">
        <label class="llm-param">
          <span>${t('settings.llm.temperature')}</span>
          <input id="set-llm-temp" type="number" min="0" max="2" step="0.1" inputmode="decimal" />
        </label>
        <label class="llm-param">
          <span>${t('settings.llm.seed')}</span>
          <input id="set-llm-seed" type="number" step="1" inputmode="numeric" />
        </label>
      </div>
      <div class="check-row">
        <small id="llm-disk-usage" hidden></small>
      </div>
      <div id="llm-model-status" class="model-status" hidden></div>
      <button id="open-models-screen" type="button" class="btn-primary btn-small" hidden>
        ${t('settings.model.nativeScreen')}
      </button>

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
  const llmModel = $<HTMLSelectElement>('set-llm-model');
  const llmTemp = $<HTMLInputElement>('set-llm-temp');
  const llmSeed = $<HTMLInputElement>('set-llm-seed');
  const llmHint = $<HTMLElement>('set-llm-hint');
  const llmDisk = $<HTMLElement>('llm-disk-usage');
  const llmStatus = $<HTMLElement>('llm-model-status');

  // Tela nativa de Modelos (TODO android-03 / issue #35): botão só no app.
  const openModelsBtn = $<HTMLButtonElement>('open-models-screen');
  if (Capacitor.isNativePlatform()) {
    openModelsBtn.hidden = false;
    openModelsBtn.addEventListener('click', () => {
      void bridge.openModelsScreen();
    });
  }

  mode.value = settings.mode;
  baseUrl.value = settings.baseUrl;
  model.value = settings.model;
  lang.value = settings.language;
  voiceReplies.checked = settings.voiceReplies;
  sttEngine.value = settings.sttEngine;
  vadAutoStop.checked = settings.vadAutoStop;
  whisperModel.value = settings.whisperModel;
  llmModel.value = settings.localModel;
  llmTemp.value = String(settings.localTemperature ?? 0.7);
  llmSeed.value = String(settings.localSeed ?? -1);
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

  // ------------------------------------------------------------- TTS piper --
  // TODO core-03: motor neural Piper — motor, dados espeak e vozes.

  const ttsEngine = $<HTMLSelectElement>('set-tts-engine');
  const piperHint = $<HTMLElement>('set-piper-hint');
  const piperVoicesEl = $<HTMLElement>('piper-voices');

  ttsEngine.value = settings.ttsEngine ?? 'system';

  let piperCaps: VoiceCapabilities | null = null;

  const refreshPiper = (refetch = false): void => {
    if (refetch) {
      // o estado mudou no nativo: repede as capacidades e redesenha
      void bridge
        .getVoiceCapabilities()
        .then(({ json }) => {
          piperCaps = JSON.parse(json) as VoiceCapabilities;
          refreshPiper();
        })
        .catch(() => undefined);
      return;
    }
    if (piperCaps === null) return;
    piperHint.hidden = piperCaps.piperJni;
    piperVoicesEl.hidden = !piperCaps.piperJni;
    piperVoicesEl.textContent = '';
    if (!piperCaps.piperJni) return;

    // Dados de fonemização compartilhados (obrigatórios para o piper).
    const dataRow = document.createElement('div');
    dataRow.className = 'check-row';
    const dataBtn = document.createElement('button');
    dataBtn.type = 'button';
    if (piperCaps.piperEspeakData) {
      dataBtn.className = 'btn-danger btn-small';
      dataBtn.textContent = `${t('settings.voice.model.delete')} — ${t('settings.tts.espeak')}`;
      dataBtn.addEventListener('click', () => {
        void bridge.deleteVoiceModel({ file: 'espeak-ng-data.zip' }).then(() => refreshPiper(true));
      });
    } else {
      dataBtn.className = 'btn-primary btn-small';
      dataBtn.textContent = `${t('settings.voice.model.download')} — ${t('settings.tts.espeak')}`;
      dataBtn.addEventListener('click', () => {
        dataBtn.disabled = true;
        dataBtn.textContent = `${t('settings.voice.model.downloading')} 0%`;
        void bridge.downloadVoiceModel({ kind: 'tts', id: 'espeak-data' });
      });
    }
    dataRow.appendChild(dataBtn);
    piperVoicesEl.appendChild(dataRow);

    for (const v of piperCaps.piperVoices ?? []) {
      const row = document.createElement('div');
      row.className = 'check-row';
      const btn = document.createElement('button');
      btn.type = 'button';
      if (v.downloaded) {
        btn.className = 'btn-danger btn-small';
        btn.textContent = `${t('settings.voice.model.delete')} — ${v.label}`;
        btn.addEventListener('click', () => {
          void bridge.deleteVoiceModel({ file: v.file }).then(() => refreshPiper(true));
        });
      } else {
        btn.className = 'btn-primary btn-small';
        btn.textContent = `${t('settings.voice.model.download')} — ${v.label}`;
        btn.addEventListener('click', () => {
          btn.disabled = true;
          btn.textContent = `${t('settings.voice.model.downloading')} 0%`;
          void bridge.downloadVoiceModel({ kind: 'tts', id: v.id });
        });
      }
      row.appendChild(btn);
      piperVoicesEl.appendChild(row);
    }
  };

  refreshPiper(true);

  // ------------------------------------------------------------ LLM local --
  // Fase 3 (TODO app-02): catálogo, download com progresso, carga e remoção.

  let llmCaps: LlmCapabilities | null = null;
  let llmStates = new Map<string, LlmModelStatus>();

  const llmLabel = (m: LlmModelStatus): string =>
    `${LLM_FALLBACK_LABELS[m.id] ?? m.label}${m.downloaded ? ' ✓' : ''}`;

  const fillLlmSelect = (): void => {
    const selected = llmModel.value;
    for (let i = llmModel.options.length - 1; i >= 1; i -= 1) {
      llmModel.options.remove(i);
    }
    for (const m of llmCaps?.models ?? []) {
      const opt = document.createElement('option');
      opt.value = m.fileName;
      opt.textContent = llmLabel(m);
      llmModel.appendChild(opt);
    }
    if (selected.length > 0) llmModel.value = selected;
  };

  const formatMb = (bytes: number): string => `${Math.round(bytes / 1e6)} MB`;

  const refreshLlmRow = (): void => {
    const file = llmModel.value;
    llmStatus.hidden = true;
    llmStatus.textContent = '';
    if (llmDisk !== null && llmCaps !== null && llmCaps.diskUsageBytes > 0) {
      llmDisk.hidden = false;
      llmDisk.textContent = tf('settings.llm.disk', { mb: formatMb(llmCaps.diskUsageBytes) });
    }
    if (file.length === 0) return;
    const state = (llmCaps?.models ?? []).find((m) => m.fileName === file);
    if (!state || !llmCaps?.jniAvailable) return;
    if (!state.downloaded) {
      llmStatus.hidden = false;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn-primary btn-small';
      btn.textContent = `${t('settings.llm.download')} — ${llmLabel(state)}`;
      btn.addEventListener('click', () => {
        btn.disabled = true;
        btn.textContent = `${t('settings.llm.downloading')} 0%`;
        void bridge.downloadLlmModel({ id: state.id });
      });
      llmStatus.appendChild(btn);
    } else {
      llmStatus.hidden = false;
      const row = document.createElement('div');
      row.className = 'check-row';
      const load = document.createElement('button');
      load.type = 'button';
      load.className = 'btn-primary btn-small';
      load.textContent =
        llmCaps.loadedFile === file && llmCaps.state === 'ready'
          ? t('settings.llm.unload')
          : t('settings.llm.load');
      load.addEventListener('click', () => {
        if (llmCaps?.loadedFile === file && llmCaps.state === 'ready') {
          void bridge.unloadLocalModel();
        } else {
          void bridge.loadLocalModel({ file });
        }
      });
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'btn-danger btn-small';
      del.textContent = t('settings.llm.delete');
      del.addEventListener('click', () => {
        void bridge.deleteLlmModel({ file }).then(() => {
          if (llmCaps) {
            const m = llmCaps.models.find((x) => x.fileName === file);
            if (m) m.downloaded = false;
          }
          refreshLlmRow();
        });
      });
      row.appendChild(load);
      row.appendChild(del);
      llmStatus.appendChild(row);
    }
  };

  void bridge
    .getLlmCapabilities()
    .then(({ json }) => {
      llmCaps = JSON.parse(json) as LlmCapabilities;
      llmStates = new Map((llmCaps.models ?? []).map((m) => [m.id, m]));
      llmHint.hidden = llmCaps.jniAvailable;
      fillLlmSelect();
      refreshLlmRow();
    })
    .catch(() => {
      // sem capacidades (web): mantém a seção mínima
    });

  llmModel.addEventListener('change', refreshLlmRow);

  const onLlmEvent = (ev: Event): void => {
    const event = (ev as CustomEvent<LlmEvent>).detail;
    if (event.type === 'llmProgress') {
      llmStatus.hidden = false;
      llmStatus.textContent = tf('settings.llm.progress', {
        pct: Math.min(100, Math.round((event.bytes / Math.max(1, event.total)) * 100)),
      });
    } else if (event.type === 'llmReady') {
      const state = llmStates.get(event.id);
      if (state) state.downloaded = true;
      void bridge
        .getLlmCapabilities()
        .then(({ json }) => {
          llmCaps = JSON.parse(json) as LlmCapabilities;
          fillLlmSelect();
          refreshLlmRow();
        })
        .catch(() => undefined);
    } else if (event.type === 'llmStatus') {
      if (llmCaps) llmCaps.state = event.state;
      refreshLlmRow();
    } else if (event.type === 'llmError') {
      llmStatus.hidden = false;
      llmStatus.textContent = event.code;
    }
  };
  window.addEventListener('geny:llm-event', onLlmEvent);

  // Eventos de download de modelo vindos do VoiceController (via window).
  const onModelEvent = (ev: Event): void => {
    const event = (ev as CustomEvent<VoiceEvent>).detail;
    if (event.type.startsWith('model') && (event as { kind?: string }).kind === 'tts') {
      // Piper (TODO core-03): progresso/redesenho da seção TTS.
      if (event.type === 'modelReady' || event.type === 'modelError') {
        refreshPiper(true);
      } else if (event.type === 'modelProgress') {
        piperVoicesEl.hidden = false;
        const pct = Math.min(100, Math.round((event.bytes / Math.max(1, event.total)) * 100));
        piperVoicesEl.textContent = tf('settings.voice.model.progress', { pct });
      }
      return;
    }
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
    window.removeEventListener('geny:llm-event', onLlmEvent);
  });

  $<HTMLButtonElement>('btn-close-settings').addEventListener('click', () => {
    drawer.dispatchEvent(new CustomEvent('geny:drawer-closed'));
    drawer.hidden = true;
  });

  $<HTMLFormElement>('settings-form').addEventListener('submit', (ev) => {
    ev.preventDefault();
    const temp = Number.parseFloat(llmTemp.value.replace(',', '.'));
    const seed = Number.parseInt(llmSeed.value, 10);
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
      localModel: llmModel.value,
      localTemperature: Number.isFinite(temp) ? Math.min(2, Math.max(0, temp)) : 0.7,
      localSeed: Number.isFinite(seed) ? seed : -1,
      ttsEngine: ttsEngine.value as Settings['ttsEngine'],
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
