/**
 * Painel de configurações: modo de operação, backend remoto/self-hosted,
 * idioma, voz (Fase 2) e nota de privacidade. No Android, a chave de API é
 * delegada ao Keystore via ponte nativa; no web fica em localStorage
 * (apenas dev).
 */
import { Capacitor } from '@capacitor/core';
import { bridge } from '../core/bridge';
import { PROVIDER_PRESETS, effectiveProvider, type OperationProfileCode } from '../core/providers';
import type { VoiceEvent, WakeWordStatus } from '../core/voice-types';
import type { VoiceCapabilities, WhisperModelStatus } from '../core/voice-types';
import type { LlmCapabilities, LlmEvent, LlmModelStatus } from '../core/llm-types';
import { LOCALES, t, tf } from '../i18n';
import type { Settings, ToolDefinition } from '../types';

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

/** Classe CSS do selo por nível de confirmação (docs §12.3). */
export const CONFIRMATION_LEVEL_CLASS: Record<ToolDefinition['confirmation'], string> = {
  none: 'level-none',
  simple: 'level-simple',
  explicit: 'level-explicit',
  authenticated: 'level-authenticated',
};

/** Selo do nível de confirmação: "nenhuma | simples | explícita | autenticada". */
export function confirmationBadge(level: ToolDefinition['confirmation']): string {
  const label = t(`settings.tools.level.${level}`);
  const cls = CONFIRMATION_LEVEL_CLASS[level] ?? 'level-none';
  return `<span class="tool-badge ${cls}">${label}</span>`;
}

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
        <span>${t('settings.profile')}</span>
        <select id="set-profile">
          <option value="default">${t('settings.profile.default')}</option>
          <option value="offline-total">${t('settings.profile.offline')}</option>
          <option value="hybrid">${t('settings.profile.hybrid')}</option>
          <option value="home-server">${t('settings.profile.home')}</option>
        </select>
        <small id="set-profile-desc"></small>
      </label>
      <label>
        <span>${t('settings.provider')}</span>
        <select id="set-provider">
          ${PROVIDER_PRESETS.map((p) => `<option value="${p.id}">${p.label}</option>`).join('')}
          <option value="custom">${t('settings.provider.custom')}</option>
        </select>
        <small id="set-provider-tier"></small>
      </label>
      <label>
        <span>${t('settings.baseUrl')}</span>
        <input id="set-baseurl" type="url" placeholder="http://localhost:11434/v1" />
      </label>
      <label>
        <span>${t('settings.model')}</span>
        <input id="set-model" type="text" placeholder="qwen2.5:1.5b" />
      </label>
      <label id="row-apikey">
        <span>${t('settings.apiKey')}</span>
        <input id="set-apikey" type="password" placeholder="sk-…" autocomplete="off" />
        <small>${t('settings.apiKey.desc')}</small>
        <small id="key-keystore-note" hidden>${t('settings.key.keystore')}</small>
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

      <h3 class="drawer-section">${t('settings.wake.title')}</h3>
      <label class="check-row">
        <input id="set-wake-enabled" type="checkbox" />
        <span>${t('settings.wake.enable')}</span>
      </label>
      <label>
        <span>${t('settings.wake.phrase')}</span>
        <select id="set-wake-model">
          <option value="oww-hey-jarvis">“Hey Jarvis”</option>
          <option value="oww-hey-mycroft">“Hey Mycroft”</option>
          <option value="oww-alexa">“Alexa”</option>
          <option value="oww-hey-rhasspy">“Hey Rhasspy”</option>
        </select>
        <small>${t('settings.wake.offbydefault')}</small>
      </label>
      <small id="set-wake-hint" hidden>${t('settings.wake.unavailable')}</small>
      <div id="wake-status" class="model-status" hidden></div>

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

      <h3 class="drawer-section">${t('settings.memory.title')}</h3>
      <button id="open-memory-screen" type="button" class="btn-primary btn-small" hidden>
        ${t('settings.memory.open')}
      </button>

      <h3 class="drawer-section">${t('settings.backup.title')}</h3>
      <small>${t('settings.backup.desc')}</small>
      <label>
        <span>${t('settings.backup.pass')}</span>
        <input id="set-backup-pass" type="password" autocomplete="new-password" />
      </label>
      <div class="check-row">
        <button id="backup-export" type="button" class="btn-primary btn-small">${t('settings.backup.export')}</button>
        <button id="backup-import" type="button" class="btn-primary btn-small">${t('settings.backup.import')}</button>
      </div>
      <small id="backup-status" class="tools-count" hidden></small>
      <small id="backup-webnote" hidden>${t('settings.backup.webnote')}</small>

      <h3 class="drawer-section">${t('settings.tools.title')}</h3>
      <small id="tools-catalog-count" class="tools-count"></small>
      <div id="tools-catalog" class="tools-catalog" aria-live="polite"></div>

      <p class="privacy-note">${t('settings.privacy')}</p>
      <button type="submit" class="btn-primary">${t('settings.save')}</button>
    </form>`;

  const $ = <T extends HTMLElement>(id: string): T => {
    const el = drawer.querySelector(`#${id}`);
    if (el === null) throw new Error(`elemento ausente: ${id}`);
    return el as T;
  };

  const mode = $<HTMLSelectElement>('set-mode');
  const profile = $<HTMLSelectElement>('set-profile');
  const profileDesc = $<HTMLElement>('set-profile-desc');
  const providerSel = $<HTMLSelectElement>('set-provider');
  const providerTier = $<HTMLElement>('set-provider-tier');
  const baseUrl = $<HTMLInputElement>('set-baseurl');
  const model = $<HTMLInputElement>('set-model');
  const apiKey = $<HTMLInputElement>('set-apikey');
  const keyRow = $<HTMLElement>('row-apikey');
  const keyKeystoreNote = $<HTMLElement>('key-keystore-note');
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

  // Fase 5 (TODO android-08 / issue #46): tela nativa de Memória — só no app.
  const openMemoryBtn = $<HTMLButtonElement>('open-memory-screen');
  const backupExportBtn = $<HTMLButtonElement>('backup-export');
  const backupImportBtn = $<HTMLButtonElement>('backup-import');
  const backupPass = $<HTMLInputElement>('set-backup-pass');
  const backupStatus = $<HTMLElement>('backup-status');
  const backupWebnote = $<HTMLElement>('backup-webnote');

  const showBackupStatus = (msg: string): void => {
    backupStatus.textContent = msg;
    backupStatus.hidden = false;
  };

  if (!Capacitor.isNativePlatform()) {
    backupWebnote.hidden = false;
  } else {
    openMemoryBtn.hidden = false;
    openMemoryBtn.addEventListener('click', () => {
      void bridge.openMemoryScreen();
    });

    // Fase 5 (TODO app-04 / issue #48): exportação/restauração cifrada —
    // o nativo grava/lê o arquivo GENYBAK1 via SAF e aplica os fatos.
    backupExportBtn.addEventListener('click', () => {
      const pass = backupPass.value;
      if (pass.length === 0) {
        showBackupStatus(t('settings.backup.fail'));
        return;
      }
      // Fase 6 (android-09): a chave vai do Keystore (ponte) para o arquivo
      // — o payload é cifrado com a senha; no navegador, mock por provedor.
      const provider = providerSel.value || 'custom';
      const legacyKey = (): string => {
        try {
          return localStorage.getItem('geny.apikey') ?? '';
        } catch {
          return '';
        }
      };
      void bridge
        .providerKeyGet({ provider })
        .then(({ value }) => (value.length > 0 ? value : legacyKey()))
        .catch(() => legacyKey())
        .then((apiKeyStored) => {
          const payload = JSON.stringify({ ...settings, provider, apiKey: apiKeyStored });
          return bridge.backupExport({ settingsJson: payload, passphrase: pass });
        })
        .then((res) => {
          showBackupStatus(res.ok ? t('settings.backup.ok') : t('settings.backup.fail'));
          if (res.ok) backupPass.value = '';
        })
        .catch(() => showBackupStatus(t('settings.backup.fail')));
    });

    backupImportBtn.addEventListener('click', () => {
      const pass = backupPass.value;
      if (pass.length === 0) {
        showBackupStatus(t('settings.backup.fail'));
        return;
      }
      void bridge
        .backupImport({ passphrase: pass })
        .then((res) => {
          if (!res.ok || res.settingsJson === undefined) {
            showBackupStatus(t('settings.backup.fail'));
            return;
          }
          try {
            const parsed = JSON.parse(res.settingsJson) as Partial<Settings> & {
              apiKey?: string;
              provider?: string;
            };
            if (typeof parsed.apiKey === 'string' && parsed.apiKey.length > 0) {
              // Fase 6 (android-09): a chave restaurada volta para o cofre do
              // provedor (Keystore no app; mock por provedor no navegador).
              const provider = parsed.provider ?? 'custom';
              bridge
                .providerKeySet({ provider, key: parsed.apiKey })
                .catch(() => localStorage.setItem('geny.apikey', parsed.apiKey ?? ''));
            }
            delete parsed.apiKey;
            cb.onSave(parsed as Settings);
            showBackupStatus(t('settings.backup.restored'));
            backupPass.value = '';
          } catch {
            showBackupStatus(t('settings.backup.fail'));
          }
        })
        .catch(() => showBackupStatus(t('settings.backup.fail')));
    });
  }

  // Catálogo de ferramentas (TODO app-03 / issue #44): nome, descrição e
  // nível de confirmação de cada ferramenta registrada na ponte nativa.
  const toolsCatalog = $<HTMLElement>('tools-catalog');
  const toolsCount = $<HTMLElement>('tools-catalog-count');
  void bridge
    .listTools()
    .then(({ tools }) => {
      toolsCount.textContent = tf('settings.tools.count', { n: tools.length });
      toolsCatalog.innerHTML = tools
        .map((tool) => {
          const params = tool.params
            .map((p) => `${p.name}${p.required ? '*' : ''}`)
            .join(', ');
          return `<div class="tool-row">
            <div class="tool-row-head">
              <strong class="tool-name">${tool.name}</strong>
              ${confirmationBadge(tool.confirmation)}
            </div>
            <small class="tool-desc">${tool.description}</small>
            ${params ? `<small class="tool-params">${params}</small>` : ''}
          </div>`;
        })
        .join('');
    })
    .catch(() => {
      // Sem catálogo (pontes antigas): seção fica vazia, sem erro visível.
      toolsCatalog.hidden = true;
    });

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

  // ------------------------------------------------ provedores e perfis --
  // Fase 6 (TODO core-10 / issue #50): presets preenchem a base URL; o
  // perfil de operação restringe o modo auto (espelho do core Rust).

  const PROFILE_DESCS: Record<OperationProfileCode, string> = {
    'default': t('settings.profile.default.desc'),
    'offline-total': t('settings.profile.offline.desc'),
    'hybrid': t('settings.profile.hybrid.desc'),
    'home-server': t('settings.profile.home.desc'),
  };

  const refreshProviderUi = (): void => {
    const preset = effectiveProvider(providerSel.value);
    providerTier.textContent = `${t(`settings.tier.${preset.tier.replace('-', '_')}`)} · ${
      preset.requiresKey ? t('settings.tier.key') : t('settings.tier.nokey')
    }`;
    keyRow.hidden = !preset.requiresKey;
  };

  const refreshProfileUi = (): void => {
    const code = profile.value as OperationProfileCode;
    profileDesc.textContent = PROFILE_DESCS[code] ?? '';
  };

  profile.value = (settings.profile ?? 'default') as string;
  providerSel.value = effectiveProvider(settings.provider).id;
  refreshProviderUi();
  refreshProfileUi();
  keyKeystoreNote.hidden = !Capacitor.isNativePlatform();

  providerSel.addEventListener('change', () => {
    // Preset escolhido: preenche a base URL (custom preserva o que há).
    const preset = effectiveProvider(providerSel.value);
    if (preset.baseUrl.length > 0) baseUrl.value = preset.baseUrl;
    refreshProviderUi();
  });
  profile.addEventListener('change', refreshProfileUi);

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

  // ------------------------------------------------------------ Wake word --
  // Fase 3 (TODO android-03b): opcional, DESLIGADO por padrão. O nativo
  // exige os 2 modelos de características + a frase escolhida antes de
  // ligar o serviço em primeiro plano.

  const wakeEnabled = $<HTMLInputElement>('set-wake-enabled');
  const wakeModel = $<HTMLSelectElement>('set-wake-model');
  const wakeHint = $<HTMLElement>('set-wake-hint');
  const wakeStatus = $<HTMLElement>('wake-status');

  let wakeState: WakeWordStatus | null = null;

  const wakeRowFor = (id: string) => wakeState?.models.find((m) => m.id === id);

  const missingForEnable = (): string[] => {
    if (!wakeState) return [];
    const needed = ['oww-melspectrogram', 'oww-embedding', wakeModel.value];
    return needed.filter((id) => !wakeRowFor(id)?.downloaded);
  };

  const wakeDownloadButtons = (ids: string[]): void => {
    for (const id of ids) {
      const row = wakeRowFor(id);
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn-primary btn-small';
      btn.textContent = `${t('settings.voice.model.download')} — ${row?.label ?? id}`;
      btn.addEventListener('click', () => {
        btn.disabled = true;
        btn.textContent = `${t('settings.voice.model.downloading')} 0%`;
        void bridge.downloadVoiceModel({ kind: 'wakeword', id });
      });
      wakeStatus.appendChild(btn);
    }
  };

  const refreshWake = (refetch = false): void => {
    if (refetch) {
      void bridge
        .getWakeWordStatus()
        .then(({ json }) => {
          wakeState = JSON.parse(json) as WakeWordStatus;
          refreshWake();
        })
        .catch(() => undefined);
      return;
    }
    if (wakeState === null) return;
    const native = Capacitor.isNativePlatform();
    wakeHint.hidden = native;
    if (!native || wakeState.models.length === 0) return;
    wakeEnabled.checked = wakeState.enabled;
    wakeModel.value = wakeState.modelId;
    wakeStatus.hidden = true;
    wakeStatus.textContent = '';
    if (wakeState.enabled) {
      wakeStatus.hidden = false;
      wakeStatus.textContent = t('settings.wake.listening');
      return;
    }
    const missing = missingForEnable();
    if (missing.length > 0 && wakeEnabled.checked) {
      wakeStatus.hidden = false;
      wakeDownloadButtons(missing);
    }
  };

  wakeEnabled.addEventListener('change', () => {
    const enable = wakeEnabled.checked;
    if (!enable) {
      void bridge.setWakeWordEnabled({ enabled: false }).then(() => refreshWake(true));
      return;
    }
    const missing = missingForEnable();
    if (missing.length > 0) {
      // Sem modelos ainda: mostra os downloads e volta o toggle para off
      // até que a ativação seja possível.
      wakeStatus.hidden = false;
      wakeStatus.textContent = t('settings.wake.needsmodels');
      wakeDownloadButtons(missing);
      wakeEnabled.checked = false;
      return;
    }
    void bridge
      .setWakeWordEnabled({ enabled: true, modelId: wakeModel.value })
      .then((res) => {
        if (!res.ok) {
          wakeStatus.hidden = false;
          wakeStatus.textContent = res.error ?? 'erro';
          wakeEnabled.checked = false;
        }
        refreshWake(true);
      })
      .catch(() => {
        wakeEnabled.checked = false;
      });
  });

  wakeModel.addEventListener('change', () => refreshWake());

  if (Capacitor.isNativePlatform()) {
    refreshWake(true);
  } else {
    wakeHint.hidden = false;
  }

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
      provider: providerSel.value,
      profile: profile.value as Settings['profile'],
      voiceReplies: voiceReplies.checked,
      sttEngine: sttEngine.value as Settings['sttEngine'],
      vadAutoStop: vadAutoStop.checked,
      whisperModel: whisperModel.value,
      localModel: llmModel.value,
      localTemperature: Number.isFinite(temp) ? Math.min(2, Math.max(0, temp)) : 0.7,
      localSeed: Number.isFinite(seed) ? seed : -1,
      ttsEngine: ttsEngine.value as Settings['ttsEngine'],
    });
    // Fase 6 (TODO android-09 / issue #51): a chave de API do provedor vai
    // para o cofre via ponte (Keystore no app; localStorage por provedor no
    // navegador). A chave legada 'geny.apikey' é limpa após a migração.
    const key = apiKey.value.trim();
    if (key.length > 0) {
      const provider = providerSel.value || 'custom';
      void bridge
        .providerKeySet({ provider, key })
        .then(() => localStorage.removeItem('geny.apikey'))
        .catch(() => localStorage.setItem('geny.apikey', key));
    }
    apiKey.value = '';
    window.setTimeout(() => {
      drawer.dispatchEvent(new CustomEvent('geny:drawer-closed'));
      drawer.hidden = true;
    }, 450);
  });
}
