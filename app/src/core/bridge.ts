/**
 * Ponte com a camada nativa (Capacitor plugin `GenyBridge`).
 *
 * No Android, os métodos são implementados por
 * android/.../bridge/GenyPlugin.kt. No navegador (dev/web), um mock local
 * executa ferramentas simuladas — mantendo o app utilizável sem dispositivo,
 * sempre local-first.
 */
import { Capacitor, registerPlugin } from '@capacitor/core';
import type { ConfirmationLevel, DeviceContext, ToolDefinition, ToolOutcome } from '../types';
import type { VoiceCapabilities, VoiceEvent, TtsEvent, WakeWordEvent, WakeWordStatus } from './voice-types';
import type { LocalGenerateOptions, LlmEvent } from './llm-types';

export interface GenyBridge {
  listTools(): Promise<{ tools: ToolDefinition[] }>;
  invokeTool(options: {
    callId: string;
    toolId: string;
    paramsJson: string;
  }): Promise<{ outcomeJson: string }>;
  requestConfirmation(options: {
    toolId: string;
    level: ConfirmationLevel;
    summary: string;
  }): Promise<{ approved: boolean }>;
  getDeviceContext(): Promise<{ json: string }>;
  // ---- Voz (Fase 2, docs §7) ----
  getVoiceCapabilities(): Promise<{ json: string }>;
  startVoiceCapture(options: {
    engine: string;
    language: string;
    vadAutoStop: boolean;
    modelId: string;
  }): Promise<{ started?: boolean }>;
  stopVoiceCapture(): Promise<void>;
  cancelVoiceCapture(): Promise<void>;
  downloadVoiceModel(options: { kind: string; id: string }): Promise<void>;
  deleteVoiceModel(options: { file: string }): Promise<{ deleted: boolean }>;
  speak(options: { text: string; language: string; engine?: string }): Promise<void>;
  stopSpeaking(): Promise<void>;
  // ---- LLM local (Fase 3, docs §6) ----
  getLlmCapabilities(): Promise<{ json: string }>;
  downloadLlmModel(options: { id: string }): Promise<void>;
  deleteLlmModel(options: { file: string }): Promise<{ deleted: boolean }>;
  loadLocalModel(options: { file: string }): Promise<void>;
  unloadLocalModel(): Promise<void>;
  generateLocal(options: LocalGenerateOptions): Promise<{ json: string }>;
  /** Pede a parada da geração local em andamento (TODO core-05b). */
  stopLocalGenerate(): Promise<void>;
  /** Abre a tela nativa de Modelos (Fase 3, TODO android-03 / issue #35). */
  openModelsScreen(): Promise<void>;
  // ---- SAF: pastas autorizadas (Fase 4, TODO android-05) ----
  /** Abre o seletor do sistema e persiste a permissão da pasta escolhida. */
  safPickFolder(): Promise<{ ok: boolean; treeUri?: string; error?: string }>;
  /** Lista as pastas autorizadas (com estado da permissão persistida). */
  safAuthorized(): Promise<{ ok: boolean; folders: Array<{ treeUri: string; persisted: boolean }> }>;
  /** Revoga a permissão de uma pasta autorizada. */
  safRevoke(options: { treeUri: string }): Promise<{ ok: boolean; error?: string }>;
  /** Lista o conteúdo de um caminho relativo dentro da pasta autorizada. */
  safList(options: { treeUri: string; path?: string }): Promise<{ json: string }>;
  /** Lê um arquivo de texto dentro da pasta autorizada. */
  safRead(options: { treeUri: string; path: string }): Promise<{ json: string }>;
  /** Escreve (cria/sobrescreve/append) um arquivo de texto. */
  safWrite(options: { treeUri: string; path: string; content: string; append?: boolean }): Promise<{ json: string }>;
  /** Cria um diretório dentro da pasta autorizada. */
  safMkdir(options: { treeUri: string; path: string }): Promise<{ json: string }>;
  /** Apaga um arquivo dentro da pasta autorizada. */
  safDelete(options: { treeUri: string; path: string }): Promise<{ json: string }>;
  /** OCR local: extrai texto de uma imagem (content://) 100% on-device. */
  ocrRead(options: { imageUri: string }): Promise<{ json: string }>;
  // ---- Wake word (Fase 3, TODO android-03b) — desligado por padrão ----
  getWakeWordStatus(): Promise<{ json: string }>;
  setWakeWordEnabled(options: { enabled: boolean; modelId?: string }): Promise<{ ok: boolean; error?: string }>;
  addListener(
    eventName: 'genyVoice' | 'genyLlm' | 'genyTts' | 'genyWake',
    listenerFunc: (event: VoiceEvent | LlmEvent | TtsEvent | WakeWordEvent) => void,
  ): Promise<{ remove: () => void }> & { remove: () => void };
}

/** Handler de confirmação registrado pela UI (modal). */
export type ConfirmationHandler = (
  toolId: string,
  level: ConfirmationLevel,
  summary: string,
) => Promise<boolean>;

let confirmationHandler: ConfirmationHandler | null = null;

/** Registra o modal de confirmação usado pelo mock web. */
export function setConfirmationHandler(handler: ConfirmationHandler | null): void {
  confirmationHandler = handler;
}

// ---------------------------------------------------------------- mock web --

function webCatalog(): ToolDefinition[] {
  const def = (
    id: string,
    name: string,
    description: string,
    params: ToolDefinition['params'],
    confirmation: ConfirmationLevel,
  ): ToolDefinition => ({
    id,
    name,
    description,
    params,
    permissions: [],
    confirmation,
    context: 'app',
    timeout_ms: 10_000,
  });
  const str = (name: string, required: boolean): ToolDefinition['params'][number] => ({
    name,
    type: 'string',
    required,
  });

  return [
    def('time.now', 'Hora atual', 'Data e hora do dispositivo.', [], 'none'),
    def('device.battery', 'Bateria', 'Nível e estado da bateria.', [], 'none'),
    def(
      'apps.list',
      'Listar apps',
      'Lista aplicativos (mock web: lista fixa).',
      [str('query', false)],
      'none',
    ),
    def('apps.open', 'Abrir app', 'Abre um aplicativo pelo nome.', [str('app', true)], 'none'),
    def(
      'notes.create',
      'Criar nota',
      'Cria uma nota local (localStorage no web).',
      [str('title', true), str('body', true)],
      'simple',
    ),
    def(
      'notifications.reply',
      'Responder notificação',
      'Responde uma notificação pelo id (mock web: sem efeito).',
      [str('id', true), str('text', true)],
      'explicit',
    ),
    def(
      'ocr.read',
      'Ler texto de imagem (OCR)',
      'Extrai texto de imagem 100% no dispositivo (mock web: indisponível).',
      [str('imageUri', true)],
      'simple',
    ),
    def(
      'web.search',
      'Pesquisar web',
      'Abre o navegador com a pesquisa.',
      [str('query', true)],
      'none',
    ),
  ];
}

function mockInvoke(toolId: string, params: Record<string, unknown>): ToolOutcome {
  const ok = (data: unknown): ToolOutcome => ({ status: 'ok', tool_id: toolId, data });
  switch (toolId) {
    case 'time.now':
      return ok({ iso: new Date().toISOString(), tz: Intl.DateTimeFormat().resolvedOptions().timeZone });
    case 'device.battery':
      return ok({ levelPct: 80, charging: false, saver: false, simulated: true });
    case 'apps.list':
      return ok({
        apps: ['Geny Assistant', 'Câmera', 'Navegador', 'Calculadora'],
        query: params['query'] ?? null,
        simulated: true,
      });
    case 'apps.open':
      return ok({ opened: params['app'] ?? null, simulated: true });
    case 'notes.create': {
      const notes = JSON.parse(localStorage.getItem('geny.notes') ?? '[]') as unknown[];
      notes.push({ title: params['title'], body: params['body'], at: Date.now() });
      localStorage.setItem('geny.notes', JSON.stringify(notes));
      return ok({ created: true, total: notes.length });
    }
    case 'web.search':
      window.open(
        `https://duckduckgo.com/?q=${encodeURIComponent(String(params['query'] ?? ''))}`,
        '_blank',
        'noopener',
      );
      return ok({ opened: 'browser' });
    default:
      return { status: 'failed', tool_id: toolId, error: 'mock web: ferramenta indisponível' };
  }
}

function createWebMockBridge(): GenyBridge {
  return {
    async listTools() {
      return { tools: webCatalog() };
    },
    async invokeTool({ toolId, paramsJson }) {
      const params = JSON.parse(paramsJson) as Record<string, unknown>;
      return { outcomeJson: JSON.stringify(mockInvoke(toolId, params)) };
    },
    async requestConfirmation({ toolId, level, summary }) {
      if (confirmationHandler) {
        return { approved: await confirmationHandler(toolId, level, summary) };
      }
      return { approved: window.confirm(summary) };
    },
    async getDeviceContext() {
      const ctx: DeviceContext = {
        online: navigator.onLine,
        batteryPct: 80,
        batterySaver: false,
        thermalHigh: false,
        rootAvailable: false,
        locale: navigator.language,
      };
      return { json: JSON.stringify(ctx) };
    },
    async openModelsScreen() {
      // Mock web: não há tela nativa no navegador — no-op honesto.
    },
    ...createWebSafMock(),
    ...createWebWakeWordMock(),
    ...createWebVoiceMock(),
    ...createWebLlmMock(),
    async ocrRead() {
      // Mock web: o motor de OCR é Android-only — nega com honestidade.
      return { json: JSON.stringify({ ok: false, code: 'unavailable_on_web' }) };
    },
  };
}

// ------------------------------------------- mock de SAF (web) --

/**
 * **PT** Mock de SAF no navegador: o seletor de pastas e o DocumentsContract
 * são APIs Android — o mock nega com honestidade.
 * **EN** SAF mock in the browser: the folder picker and DocumentsContract are
 * Android APIs — the mock denies honestly.
 */
function createWebSafMock(): Pick<
  GenyBridge,
  'safPickFolder' | 'safAuthorized' | 'safRevoke' | 'safList' | 'safRead' | 'safWrite' | 'safMkdir' | 'safDelete'
> {
  return {
    async safPickFolder() {
      return { ok: false, error: 'unavailable_on_web' };
    },
    async safAuthorized() {
      return { ok: true, folders: [] };
    },
    async safRevoke() {
      return { ok: false, error: 'unavailable_on_web' };
    },
    async safList() {
      return { json: JSON.stringify({ ok: false, error: 'unavailable_on_web' }) };
    },
    async safRead() {
      return { json: JSON.stringify({ ok: false, error: 'unavailable_on_web' }) };
    },
    async safWrite() {
      return { json: JSON.stringify({ ok: false, error: 'unavailable_on_web' }) };
    },
    async safMkdir() {
      return { json: JSON.stringify({ ok: false, error: 'unavailable_on_web' }) };
    },
    async safDelete() {
      return { json: JSON.stringify({ ok: false, error: 'unavailable_on_web' }) };
    },
  };
}

// ---------------------------------------------- mock de wake word (web) --

/**
 * **PT** Mock de wake word no navegador: não existe captura contínua em
 * segundo plano aqui — o mock reporta indisponível de forma honesta.
 * **EN** Wake word mock in the browser: no background continuous capture
 * here — the mock reports unavailability honestly.
 */
function createWebWakeWordMock(): Pick<GenyBridge, 'getWakeWordStatus' | 'setWakeWordEnabled'> {
  return {
    async getWakeWordStatus() {
      const status: WakeWordStatus = {
        enabled: false,
        modelId: 'oww-hey-jarvis',
        ready: false,
        models: [],
      };
      return { json: JSON.stringify(status) };
    },
    async setWakeWordEnabled() {
      return { ok: false, error: 'unavailable_on_web' };
    },
  };
}

// ----------------------------------------------------- mock de voz (web) --

/** Registro COMPARTILHADO dos eventos dos canais no mock web. */
const webMockListeners = new Set<(event: VoiceEvent | LlmEvent | TtsEvent | WakeWordEvent) => void>();
const emitWebMockEvent = (event: VoiceEvent | LlmEvent | TtsEvent | WakeWordEvent): void => {
  webMockListeners.forEach((fn) => fn(event));
};

/**
 * **PT** Mock de voz para o navegador: Web Speech API para STT (quando o
 * browser tem reconhecimento) e speechSynthesis para TTS. Whisper nativo
 * não existe no navegador — o mock reporta com honestidade.
 * **EN** Browser voice mock: Web Speech API for STT (when the browser has
 * recognition) and speechSynthesis for TTS. Native whisper does not exist
 * in browsers — the mock reports that honestly.
 */
function createWebVoiceMock(): Pick<
  GenyBridge,
  | 'getVoiceCapabilities'
  | 'startVoiceCapture'
  | 'stopVoiceCapture'
  | 'cancelVoiceCapture'
  | 'downloadVoiceModel'
  | 'deleteVoiceModel'
  | 'speak'
  | 'stopSpeaking'
> {
  interface SpeechRecognitionLike {
    lang: string;
    continuous: boolean;
    interimResults: boolean;
    maxAlternatives: number;
    start(): void;
    stop(): void;
    abort(): void;
    onresult: ((ev: unknown) => void) | null;
    onerror: ((ev: { error?: string }) => void) | null;
    onend: (() => void) | null;
  }
  type SRConstructor = new () => SpeechRecognitionLike;
  const getSR = (): SRConstructor | null => {
    const w = window as unknown as Record<string, unknown>;
    return (w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null) as SRConstructor | null;
  };

  const emit = emitWebMockEvent;

  let recognition: SpeechRecognitionLike | null = null;
  let audioContext: AudioContext | null = null;
  let stream: MediaStream | null = null;
  let levelTimer: number | null = null;

  const stopMeter = (): void => {
    if (levelTimer !== null) {
      window.clearInterval(levelTimer);
      levelTimer = null;
    }
    if (audioContext) {
      void audioContext.close().catch(() => undefined);
      audioContext = null;
    }
    if (stream) {
      stream.getTracks().forEach((tr) => tr.stop());
      stream = null;
    }
  };

  const startMeter = async (): Promise<void> => {
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      audioContext = new AudioContext();
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);
      const buf = new Uint8Array(analyser.frequencyBinCount);
      levelTimer = window.setInterval(() => {
        if (!audioContext) return;
        analyser.getByteTimeDomainData(buf);
        let peak = 0;
        for (const v of buf) peak = Math.max(peak, Math.abs(v - 128) / 128);
        emit({ type: 'level', level: peak });
      }, 100);
    } catch {
      // sem permissão/navegador sem suporte: a UI segue sem barra de nível
    }
  };

  return {
    async getVoiceCapabilities() {
      const caps: VoiceCapabilities = {
        mic: true,
        systemStt: getSR() !== null,
        whisperNative: false,
        vadSilero: false,
        vadEngine: 'energy',
        tts: typeof speechSynthesis !== 'undefined',
        whisperModels: [],
        piperJni: false,
        piperEspeakData: false,
        piperVoices: [],
      };
      return { json: JSON.stringify(caps) };
    },
    async startVoiceCapture(options) {
      const SR = getSR();
      if (options.engine === 'whisper' || SR === null) {
        window.setTimeout(() => {
          emit({ type: 'error', code: 'unavailable' });
        }, 0);
        return { started: false };
      }
      void startMeter();
      const rec = new SR();
      rec.lang = options.language;
      rec.continuous = false;
      rec.interimResults = true;
      rec.maxAlternatives = 1;
      rec.onresult = (ev: unknown) => {
        const results = (
          ev as { results: ArrayLike<ArrayLike<{ transcript: string }>> & { length: number }; resultIndex: number }
        ).results;
        let text = '';
        for (let i = 0; i < results.length; i += 1) {
          const alt = results[i]?.[0];
          if (alt) text += alt.transcript ?? '';
        }
        if (text.length > 0) emit({ type: 'partial', text });
      };
      rec.onerror = (ev: { error?: string }) => {
        emit({ type: 'error', code: ev.error ?? 'speech_error' });
        stopMeter();
      };
      rec.onend = () => {
        stopMeter();
      };
      recognition = rec;
      rec.start();
      return { started: true };
    },
    async stopVoiceCapture() {
      // onresult final chega antes de onend; nada a fazer aqui no mock.
      recognition?.stop();
      recognition = null;
    },
    async cancelVoiceCapture() {
      recognition?.abort();
      recognition = null;
      stopMeter();
    },
    async downloadVoiceModel() {
      window.setTimeout(() => {
        emit({ type: 'error', code: 'models_unavailable_on_web' });
      }, 0);
    },
    async deleteVoiceModel() {
      return { deleted: false };
    },
    async speak({ text, language }) {
      // Mock web: o motor é sempre o do navegador (piper só existe no app).
      if (typeof speechSynthesis === 'undefined') return;
      const utter = new SpeechSynthesisUtterance(text);
      utter.lang = language;
      // Progresso da fala para a tela de voz (mãos-livres no navegador).
      utter.onstart = () => emitWebMockEvent({ type: 'start' } as TtsEvent);
      utter.onend = () => emitWebMockEvent({ type: 'done' } as TtsEvent);
      utter.onerror = () => emitWebMockEvent({ type: 'error' } as TtsEvent);
      speechSynthesis.cancel();
      speechSynthesis.speak(utter);
    },
    async stopSpeaking() {
      if (typeof speechSynthesis !== 'undefined') speechSynthesis.cancel();
    },
  };
}

// ---------------------------------------------------- mock de LLM (web) --

/**
 * **PT** Mock de LLM local para o navegador: não existe llama.cpp aqui —
 * o mock reporta o motor como indisponível (honesto). TTS do navegador não
 * gera texto.
 * **EN** Browser local-LLM mock: there is no llama.cpp here — the mock
 * reports the engine as unavailable (honest). The browser TTS does not
 * generate text.
 */
function createWebLlmMock(): Pick<
  GenyBridge,
  | 'getLlmCapabilities'
  | 'downloadLlmModel'
  | 'deleteLlmModel'
  | 'loadLocalModel'
  | 'unloadLocalModel'
  | 'generateLocal'
  | 'stopLocalGenerate'
  | 'addListener'
> {
  const listeners = webMockListeners;
  const emitUnavailable = (): void => {
    window.setTimeout(() => {
      listeners.forEach((fn) => fn({ type: 'llmError', id: '', code: 'unavailable' }));
    }, 0);
  };

  return {
    async getLlmCapabilities() {
      return {
        json: JSON.stringify({
          jniAvailable: false,
          state: 'idle',
          loadedFile: null,
          diskUsageBytes: 0,
          totalRamBytes: 0,
          models: [],
        }),
      };
    },
    async downloadLlmModel() {
      emitUnavailable();
    },
    async deleteLlmModel() {
      return { deleted: false };
    },
    async loadLocalModel() {
      emitUnavailable();
    },
    async unloadLocalModel() {
      // sem modelo carregado no navegador
    },
    async generateLocal() {
      emitUnavailable();
      throw new Error('llm_unavailable');
    },
    async stopLocalGenerate() {
      // sem geração em andamento no navegador
    },
    addListener(_eventName, listenerFunc) {
      listeners.add(listenerFunc as (event: VoiceEvent | LlmEvent | TtsEvent | WakeWordEvent) => void);
      const handle = {
        remove: (): void => {
          listeners.delete(listenerFunc);
        },
      };
      return Object.assign(Promise.resolve(handle), handle);
    },
  };
}

// ------------------------------------------------------------------ export --

const nativeBridge = registerPlugin<GenyBridge>('GenyBridge');

/** Ponte ativa: nativa no Android, mock no navegador. */
export const bridge: GenyBridge = Capacitor.isNativePlatform()
  ? nativeBridge
  : createWebMockBridge();
