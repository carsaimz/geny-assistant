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
import type { VoiceCapabilities, VoiceEvent } from './voice-types';

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
  speak(options: { text: string; language: string }): Promise<void>;
  stopSpeaking(): Promise<void>;
  addListener(
    eventName: 'genyVoice',
    listenerFunc: (event: VoiceEvent) => void,
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
    ...createWebVoiceMock(),
  };
}

// ----------------------------------------------------- mock de voz (web) --

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
  | 'addListener'
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

  const listeners = new Set<(event: VoiceEvent) => void>();
  const emit = (event: VoiceEvent): void => {
    listeners.forEach((fn) => fn(event));
  };

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
      if (typeof speechSynthesis === 'undefined') return;
      const utter = new SpeechSynthesisUtterance(text);
      utter.lang = language;
      speechSynthesis.cancel();
      speechSynthesis.speak(utter);
    },
    async stopSpeaking() {
      if (typeof speechSynthesis !== 'undefined') speechSynthesis.cancel();
    },
    addListener(_eventName, listenerFunc) {
      listeners.add(listenerFunc);
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
