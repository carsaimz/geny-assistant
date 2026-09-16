/**
 * Cliente de voz da camada web (docs §7, TODO app-01).
 *
 * **PT** Envolve os métodos/eventos de voz da ponte num fluxo simples para a
 * UI: iniciar/parar captura, níveis de microfone, transcrições parciais e
 * final, downloads de modelo e fala (TTS). No navegador (dev) o mock usa
 * Web Speech API/speechSynthesis quando disponível — no Android o pipeline
 * é o nativo (SpeechRecognizer on-device ou whisper.cpp + VAD Silero).
 * **EN** Wraps the bridge voice methods/events into a simple flow for the
 * UI: start/stop capture, mic levels, partial/final transcripts, model
 * downloads and speaking (TTS). In the browser (dev) the mock uses Web
 * Speech API/speechSynthesis when available — on Android the pipeline is
 * native (on-device SpeechRecognizer or whisper.cpp + Silero VAD).
 */

export type VoiceEngine = 'system' | 'whisper';

export type VoiceEvent =
  | { type: 'level'; level: number }
  | { type: 'speech'; active: boolean }
  | { type: 'partial'; text: string }
  | { type: 'transcribing'; }
  | {
      type: 'result';
      final: boolean;
      source: string;
      text: string;
      sttMs?: number;
      samples?: number;
      reason?: string;
    }
  | { type: 'error'; code: string; message?: string }
  | { type: 'stopped'; reason: string }
  | {
      type: 'modelProgress';
      kind: string;
      id: string;
      bytes: number;
      total: number;
    }
  | { type: 'modelReady'; kind: string; id: string }
  | { type: 'modelError'; kind: string; id: string; message?: string };

export interface WhisperModelStatus {
  id: string;
  file: string;
  bytes: number;
  downloaded: boolean;
}

/** Voz Piper (TODO core-03): estado do download na UI. */
export interface PiperVoiceStatus {
  id: string;
  file: string;
  label: string;
  language: string;
  bytes: number;
  downloaded: boolean;
}

export interface VoiceCapabilities {
  mic: boolean;
  systemStt: boolean;
  whisperNative: boolean;
  vadSilero: boolean;
  vadEngine: string;
  tts: boolean;
  whisperModels: WhisperModelStatus[];
  /** Motor neural Piper (Fase 3): disponibilidade + vozes. */
  piperJni: boolean;
  piperEspeakData: boolean;
  piperVoices: PiperVoiceStatus[];
}

export interface CaptureOptions {
  engine: VoiceEngine;
  language: string;
  vadAutoStop: boolean;
  modelId: string;
}

export type VoiceListener = (event: VoiceEvent) => void;

/** Eventos do canal `genyTts` — progresso da fala (TTS) nativo/mock. */
export type TtsEvent = { type: 'start' } | { type: 'done' } | { type: 'error' };

/**
 * Eventos do canal `genyWake` (Fase 3, TODO android-03b) — wake word
 * opcional, desligado por padrão no lado nativo.
 */
export type WakeWordEvent =
  | { type: 'triggered'; score: number; model: string }
  | { type: 'listening'; model: string }
  | { type: 'error'; code: string; message?: string };

/** Modelo do catálogo de wake word (estado do download na UI). */
export interface WakeWordModelStatus {
  id: string;
  file: string;
  label: string;
  bytes: number;
  downloaded: boolean;
}

export interface WakeWordStatus {
  enabled: boolean;
  modelId: string;
  ready: boolean;
  models: WakeWordModelStatus[];
}
