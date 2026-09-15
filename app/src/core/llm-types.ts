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
  | { type: 'llmStatus'; state: 'idle' | 'loading' | 'ready'; file: string }
  | { type: 'llmToken'; text: string };

export type LlmListener = (event: LlmEvent) => void;

export interface LocalGenerateOptions {
  /**
   * Histórico serializado `[{role, content}, ...]` (contrato da ponte segue
   * a convenção `*Json` de `invokeTool`/`getDeviceContext`). Antes era
   * `messages` (array) — o plugin lia `messagesJson` e todo pedido do LLM
   * local falhava com `sem_mensagens`.
   */
  messagesJson: string;
  /**
   * Prompt de sistema por idioma/cultura (TODO Fase 3) construído em
   * `buildSystemPrompt` — fonte única para os backends remoto e local.
   * Vazio/ausente → nativo usa o fallback pelo locale do dispositivo.
   */
  system?: string;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  seed?: number;
  /** Streaming token a token (eventos `llmToken` no canal `genyLlm`). */
  stream?: boolean;
}

export interface LocalGenerateResult {
  text: string;
  tokens: number;
  ms: number;
  /** true quando a geração foi interrompida pelo usuário (stop). */
  stopped?: boolean;
}
