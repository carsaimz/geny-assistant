/**
 * Streaming SSE no modo remoto (Fase 6, TODO app-05 / issue #49).
 *
 * **PT** `consumeSseStream` converte chunks de bytes (com cortes no meio de
 * linhas) em tokens `delta.content`; `[DONE]` encerra; linhas não-JSON não
 * quebram o stream. `remoteStream` envia `stream:true` com o Authorization
 * e devolve o texto completo com detecção de tool call. No chat, os tokens
 * alimentam a bolha provisória (mesma UX do LLM local) e o Parar aborta.
 * **EN** `consumeSseStream` turns byte chunks (cut mid-line) into
 * `delta.content` tokens; `[DONE]` ends; non-JSON lines don't break the
 * stream. `remoteStream` sends `stream:true` with Authorization and returns
 * the full text with tool-call detection. In the chat, tokens feed the
 * provisional bubble (same UX as the local LLM) and Stop aborts.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => {
  const listeners = new Map<string, Set<(event: unknown) => void>>();
  const fakeBridge = {
    listTools: vi.fn(async (): Promise<{ tools: ToolDefinition[] }> => ({ tools: [] })),
    addListener: vi.fn((name: string, fn: (event: unknown) => void) => {
      let set = listeners.get(name);
      if (!set) {
        set = new Set();
        listeners.set(name, set);
      }
      set.add(fn);
      const handle = { remove: (): void => void set?.delete(fn) };
      return Object.assign(Promise.resolve(handle), handle);
    }),
    getDeviceContext: vi.fn(async () => ({
      json: JSON.stringify({ online: true, batteryPct: 80, batterySaver: false, thermalHigh: false }),
    })),
    memorySearch: vi.fn(async () => ({ ok: true, hits: [] })),
    generateLocal: vi.fn(async () => ({ json: JSON.stringify({ text: 'ok' }) })),
    stopLocalGenerate: vi.fn(async () => undefined),
    requestConfirmation: vi.fn(async () => ({ approved: true })),
    invokeTool: vi.fn(async () => ({ outcomeJson: '{"status":"ok","tool_id":"x"}' })),
    speak: vi.fn(async () => undefined),
  };
  return { listeners, fakeBridge };
});

vi.mock('../core/bridge', () => ({
  bridge: mocks.fakeBridge,
  setConfirmationHandler: (): void => undefined,
}));

import { ChatUI } from '../ui/chat';
import { consumeSseStream, remoteStream, tryParseToolCall } from '../core/remote';
import type { Settings, ToolDefinition } from '../types';

/** Stream de bytes a partir de strings (cortes exatos, como na rede). */
function byteStream(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (const c of chunks) controller.enqueue(encoder.encode(c));
      controller.close();
    },
  });
}

function sseFor(pieces: string[]): string[] {
  const lines = pieces.map(
    (p) => `data: ${JSON.stringify({ choices: [{ delta: { content: p } }] })}\n\n`,
  );
  lines.push('data: [DONE]\n\n');
  return lines;
}

const cfg = { baseUrl: 'https://api.test/v1', apiKey: 'sk-test', model: 'test-model' };

function makeSettings(): Settings {
  return {
    mode: 'remote',
    language: 'pt-BR',
    model: 'test-model',
    baseUrl: 'https://api.test/v1',
    apiKeySet: true,
    voiceReplies: false,
    sttEngine: 'system',
    vadAutoStop: true,
    whisperModel: 'whisper-tiny',
    localModel: '',
    localTemperature: 0.7,
    localSeed: -1,
    ttsEngine: 'system',
  };
}

describe('consumeSseStream', () => {
  it('emite tokens na ordem, mesmo com corte no meio da linha', async () => {
    const tokens: string[] = [];
    const chunks = [
      'data: {"choices":[{"del',
      'ta":{"content":"Olá"}}]}',
      '\n\ndata: {"choices":[{"delta":{"content":", mundo!"}}]}\n\n',
      'data: [DONE]\n\n',
    ];
    const full = await consumeSseStream(byteStream(chunks), (t) => tokens.push(t));
    expect(tokens).toEqual(['Olá', ', mundo!']);
    expect(full).toBe('Olá, mundo!');
  });

  it('[DONE] encerra antes do fim e linhas não-JSON são ignoradas', async () => {
    const tokens: string[] = [];
    const chunks = [
      ': keepalive\n\n',
      'data: {"choices":[{"delta":{"content":"a"}}]}\n\n',
      'data: [DONE]\n\n',
      'data: {"depois do DONE":true}\n\n',
    ];
    const full = await consumeSseStream(byteStream(chunks), (t) => tokens.push(t));
    expect(tokens).toEqual(['a']);
    expect(full).toBe('a');
  });

  it('abort externo interrompe a leitura com AbortError', async () => {
    const controller = new AbortController();
    // stream infinito: o abort é o único jeito de sair
    const endless = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"x"}}]}\n\n'));
      },
      pull(controller) {
        controller.enqueue(new TextEncoder().encode('data: {"choices":[{"delta":{"content":"x"}}]}\n\n'));
      },
    });
    const run = consumeSseStream(endless, () => undefined, controller.signal);
    controller.abort();
    await expect(run).rejects.toThrow();
  });
});

describe('remoteStream (SSE no modo remoto)', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('envia stream:true + Authorization e devolve texto/intenção', async () => {
    const fetchMock = vi.fn(async (_url: string | URL | Request, _init?: RequestInit) => ({
      ok: true,
      body: byteStream(sseFor(['Olá', ', mundo!'])),
    }));
    vi.stubGlobal('fetch', fetchMock);

    const result = await remoteStream(cfg, 'sys', [{ role: 'user', content: 'oi' }], {
      onToken: () => undefined,
    });

    expect(result.text).toBe('Olá, mundo!');
    expect(result.intent).toBeNull();
    const body = JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body)) as Record<string, unknown>;
    expect(body['stream']).toBe(true);
    expect(body['model']).toBe('test-model');
    const headers = fetchMock.mock.calls[0]?.[1]?.headers as Record<string, string>;
    expect(headers['Authorization']).toBe('Bearer sk-test');
  });

  it('tool call no texto final é detectado (igual ao modo sem stream)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({
        ok: true,
        body: byteStream(sseFor(['{"tool": "time.now", "params": {}}'])),
      })),
    );
    const result = await remoteStream(cfg, 'sys', [], { onToken: () => undefined });
    expect(result.intent?.toolId).toBe('time.now');
  });

  it('HTTP 401 lança erro com o status', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({ ok: false, status: 401, body: null })),
    );
    await expect(remoteStream(cfg, 'sys', [], { onToken: () => undefined })).rejects.toThrow(
      'backend respondeu 401',
    );
  });

  it('sem corpo de stream (body null) degrada para resposta única', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({
        ok: true,
        body: null,
        json: async () => ({ choices: [{ message: { content: 'resposta única' } }] }),
      })),
    );
    const tokens: string[] = [];
    const result = await remoteStream(cfg, 'sys', [], { onToken: (t) => tokens.push(t) });
    expect(result.text).toBe('resposta única');
    expect(tokens).toEqual(['resposta única']);
  });

  it('tryParseToolCall continua o contrato (sanidade do módulo)', () => {
    expect(tryParseToolCall('texto {"tool":"apps.open","params":{"app":"camera"}} fim')?.toolId).toBe(
      'apps.open',
    );
    expect(tryParseToolCall('sem json')).toBeNull();
  });
});

describe('chat — streaming remoto na UI', () => {
  let container: HTMLElement;
  let streamStates: boolean[];
  let replies: string[];

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.listeners.clear();
    container = document.createElement('div');
    streamStates = [];
    replies = [];
    window.requestAnimationFrame = ((cb: FrameRequestCallback) => {
      cb(0);
      return 0;
    }) as typeof window.requestAnimationFrame;
    window.cancelAnimationFrame = (() => undefined) as typeof window.cancelAnimationFrame;
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  const makeChat = (): ChatUI =>
    new ChatUI(container, {
      getSettings: makeSettings,
      getRemoteConfig: () => cfg,
      onStatusChange: () => undefined,
      onAssistantReply: (text) => replies.push(text),
      onStreamActive: (active) => streamStates.push(active),
    });

  it('tokens SSE viram a mensagem final e o botão de parar liga/desliga', async () => {
    const chat = makeChat();
    await chat.init();

    vi.stubGlobal(
      'fetch',
      vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
        // Simula o servidor devagar: tokens chegam enquanto a promessa vive.
        void init;
        return {
          ok: true,
          body: new ReadableStream<Uint8Array>({
            start(controller) {
              const encoder = new TextEncoder();
              for (const piece of ['Olá', ', mundo', ' remoto!']) {
                controller.enqueue(
                  encoder.encode(
                    `data: ${JSON.stringify({ choices: [{ delta: { content: piece } }] })}\n\n`,
                  ),
                );
              }
              controller.enqueue(encoder.encode('data: [DONE]\n\n'));
              controller.close();
            },
          }),
        };
      }),
    );

    await chat.send('oi');

    expect(container.querySelector('.msg-streaming')).toBeNull();
    const texts = [...container.querySelectorAll('.msg-assistant .msg-text')].map(
      (el) => el.textContent,
    );
    expect(texts).toContain('Olá, mundo remoto!');
    expect(replies).toContain('Olá, mundo remoto!');
    expect(streamStates[0]).toBe(true);
    expect(streamStates[streamStates.length - 1]).toBe(false);
  });

  it('erro do backend remove a bolha e informa o motivo', async () => {
    const chat = makeChat();
    await chat.init();
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({ ok: false, status: 503, body: null })),
    );

    await chat.send('oi');

    expect(container.querySelector('.msg-streaming')).toBeNull();
    expect(container.textContent).toContain('503');
    expect(streamStates[streamStates.length - 1]).toBe(false);
  });
});
