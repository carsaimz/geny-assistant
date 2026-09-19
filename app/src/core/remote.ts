/**
 * Backend remoto / self-hosted compatível com a API OpenAI (§7.3, §7.4).
 *
 * Funciona com provedores gratuitos, free-tier, premium e servidores próprios
 * (Ollama, LM Studio, vLLM, text-generation-webui). A chave de API nunca é
 * registrada em log; no Android ela vive no Keystore via ponte nativa.
 */
import type { ToolIntent } from '../types';

export interface RemoteConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
}

export function remoteConfigured(cfg: RemoteConfig | null): cfg is RemoteConfig {
  return cfg !== null && cfg.baseUrl.trim().length > 0 && cfg.model.trim().length > 0;
}

export interface RemoteResult {
  text: string;
  intent: ToolIntent | null;
}

/** Extrai o primeiro objeto JSON `{"tool": ..., "params": ...}` do conteúdo. */
export function tryParseToolCall(content: string): ToolIntent | null {
  const start = content.indexOf('{');
  const end = content.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(content.slice(start, end + 1)) as {
      tool?: unknown;
      params?: Record<string, unknown>;
    };
    if (typeof parsed.tool === 'string' && parsed.tool.length > 0) {
      return { toolId: parsed.tool, params: parsed.params ?? {} };
    }
    return null;
  } catch {
    return null;
  }
}

/** Chamada chat/completions com injeção do catálogo no prompt de sistema. */
export async function remoteComplete(
  cfg: RemoteConfig,
  systemPrompt: string,
  history: { role: string; content: string }[],
): Promise<RemoteResult> {
  const url = `${cfg.baseUrl.replace(/\/+$/, '')}/chat/completions`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);
  try {
    const res = await fetch(url, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...(cfg.apiKey.length > 0 ? { Authorization: `Bearer ${cfg.apiKey}` } : {}),
      },
      body: JSON.stringify({
        model: cfg.model,
        temperature: 0.7,
        max_tokens: 1024,
        messages: [{ role: 'system', content: systemPrompt }, ...history],
      }),
    });
    if (!res.ok) {
      throw new Error(`backend respondeu ${res.status}`);
    }
    const data = (await res.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const content = data.choices?.[0]?.message?.content ?? '';
    return { text: content, intent: tryParseToolCall(content) };
  } finally {
    clearTimeout(timeout);
  }
}

// ------------------------------------------------------------------ SSE --
// TODO app-05 (Fase 6, issue #49): streaming de respostas no modo remoto —
// paridade com o streaming do LLM local (core-05b).

export interface RemoteStreamHandlers {
  /** Chamado para cada delta de texto chegado do servidor. */
  onToken: (piece: string) => void;
  /** Abort externo (botão Parar da UI). */
  signal?: AbortSignal;
}

/** Timeout de INATIVIDADE: reiniciado a cada chunk (streams podem ser longos). */
const SSE_IDLE_TIMEOUT_MS = 60_000;

/**
 * Converte um ReadableStream de bytes SSE em tokens (`delta.content`).
 * Separada da chamada HTTP para ser testável com streams falsos.
 */
export async function consumeSseStream(
  body: ReadableStream<Uint8Array>,
  onToken: (piece: string) => void,
  signal?: AbortSignal,
): Promise<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let full = '';
  let idle: ReturnType<typeof setTimeout> | null = null;
  const resetIdle = (): void => {
    if (idle !== null) clearTimeout(idle);
    idle = setTimeout(() => controller.abort(), SSE_IDLE_TIMEOUT_MS);
  };
  const controller = new AbortController();
  const onExternalAbort = (): void => controller.abort();
  if (signal) {
    if (signal.aborted) controller.abort();
    else signal.addEventListener('abort', onExternalAbort, { once: true });
  }
  try {
    resetIdle();
    for (;;) {
      if (controller.signal.aborted) {
        throw new DOMException('stream abortado', 'AbortError');
      }
      const { done, value } = await reader.read();
      if (done) break;
      resetIdle();
      buffer += decoder.decode(value, { stream: true });
      // Eventos SSE separados por linha em branco; `data:` é o que usamos.
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';
      for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (payload.length === 0) continue;
        if (payload === '[DONE]') return full;
        try {
          const parsed = JSON.parse(payload) as {
            choices?: { delta?: { content?: string } }[];
          };
          const piece = parsed.choices?.[0]?.delta?.content ?? '';
          if (piece.length > 0) {
            full += piece;
            onToken(piece);
          }
        } catch {
          // linha parcial/keepalive não-JSON: ignora sem quebrar o stream
        }
      }
    }
    return full;
  } finally {
    if (idle !== null) clearTimeout(idle);
    if (signal) signal.removeEventListener('abort', onExternalAbort);
    reader.releaseLock();
  }
}

/**
 * Chamada chat/completions COM streaming (SSE, `stream: true`). Os tokens
 * chegam por `onToken` conforme o servidor os envia; no fim devolve o texto
 * completo (com detecção de tool call, igual ao `remoteComplete`).
 */
export async function remoteStream(
  cfg: RemoteConfig,
  systemPrompt: string,
  history: { role: string; content: string }[],
  handlers: RemoteStreamHandlers,
): Promise<RemoteResult> {
  const url = `${cfg.baseUrl.replace(/\/+$/, '')}/chat/completions`;
  const res = await fetch(url, {
    method: 'POST',
    signal: handlers.signal,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
      ...(cfg.apiKey.length > 0 ? { Authorization: `Bearer ${cfg.apiKey}` } : {}),
    },
    body: JSON.stringify({
      model: cfg.model,
      temperature: 0.7,
      max_tokens: 1024,
      stream: true,
      messages: [{ role: 'system', content: systemPrompt }, ...history],
    }),
  });
  if (!res.ok) {
    throw new Error(`backend respondeu ${res.status}`);
  }
  if (res.body === null) {
    // Servidor sem corpo de stream: degrada para chamada única.
    const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
    const content = data.choices?.[0]?.message?.content ?? '';
    handlers.onToken(content);
    return { text: content, intent: tryParseToolCall(content) };
  }
  const text = await consumeSseStream(res.body, handlers.onToken, handlers.signal);
  return { text, intent: tryParseToolCall(text) };
}
