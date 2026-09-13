/**
 * Cliente do LLM local da camada web (docs §6, TODO app-02).
 *
 * **PT** Espelha os tipos do pipeline nativo de GGUF (llama.cpp v0.4.0):
 * catálogo de modelos com SHA-256 pinado, capacidades do motor e eventos do
 * canal `genyLlm`. No navegador (dev) o mock reporta o motor como
 * indisponível — honesto, como o mock de voz.
 * **EN** Mirrors the native GGUF pipeline types (llama.cpp v0.4.0): model
 * catalog with pinned SHA-256, engine capabilities and events of the
 * `genyLlm` channel. In the browser (dev) the mock reports the engine as
 * unavailable — honest, like the voice mock.
 */

export interface LlmModelStatus {
  id: string;
  fileName: string;
  label: string;
  bytes: number;
  downloaded: boolean;
}

export interface LlmCapabilities {
  jniAvailable: boolean;
  state: 'idle' | 'loading' | 'ready';
  loadedFile: string | null;
  diskUsageBytes: number;
  totalRamBytes: number;
  models: LlmModelStatus[];
}

export type LlmEvent =
  | { type: 'llmProgress'; id: string; bytes: number; total: number }
  | { type: 'llmReady'; id: string }
  | { type: 'llmError'; id: string; code: string; message?: string }
  | { type: 'llmStatus'; state: 'idle' | 'loading' | 'ready'; file: string };

export type LlmListener = (event: LlmEvent) => void;

export interface LocalGenerateOptions {
  messages: Array<{ role: 'user' | 'assistant'; content: string }>;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  seed?: number;
}

export interface LocalGenerateResult {
  text: string;
  tokens: number;
  ms: number;
}
