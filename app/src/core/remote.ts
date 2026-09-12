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
