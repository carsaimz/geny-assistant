/**
 * Streaming do LLM local no chat (TODO core-05b).
 *
 * **PT** Os tokens chegam pelo canal `genyLlm` (evento `llmToken`) enquanto
 * `generateLocal(stream:true)` está em voo: a bolha provisória acumula o
 * texto, o botão de parar é ligado/desligado e, no fim, a mensagem final
 * substitui a bolha. Tokens fora de streaming são ignorados; erro de ponte
 * remove a bolha e cai no fluxo offline.
 * **EN** Tokens arrive on the `genyLlm` channel (`llmToken` events) while
 * `generateLocal(stream:true)` is in flight: the provisional bubble
 * accumulates text, the stop button toggles and, at the end, the final
 * message replaces the bubble. Tokens outside streaming are ignored; a
 * bridge error removes the bubble and falls back to the offline flow.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => {
  const listeners = new Map<string, Set<(event: unknown) => void>>();
  const fakeBridge = {
    listTools: vi.fn(async () => ({ tools: [] })),
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
    generateLocal: vi.fn(async (_opts?: unknown) => ({ json: JSON.stringify({ text: 'ok' }) })),
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
import type { Settings } from '../types';

function makeSettings(): Settings {
  return {
    mode: 'local',
    language: 'pt-BR',
    model: '',
    baseUrl: '',
    apiKeySet: false,
    voiceReplies: false,
    sttEngine: 'system',
    vadAutoStop: true,
    whisperModel: 'whisper-tiny',
    localModel: 'modelo.gguf',
    localTemperature: 0.7,
    localSeed: -1,
    ttsEngine: 'system',
  };
}

function llmListener(): (event: unknown) => void {
  const set = mocks.listeners.get('genyLlm');
  if (!set || set.size === 0) throw new Error('sem listener genyLlm');
  return [...set][set.size - 1]!;
}

describe('chat — streaming do LLM local (core-05b)', () => {
  let container: HTMLElement;
  let streamStates: boolean[];
  let replies: string[];

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.listeners.clear();
    container = document.createElement('div');
    streamStates = [];
    replies = [];
    // jsdom sem pretendToBeVisual: executa o rAF imediatamente.
    window.requestAnimationFrame = ((cb: FrameRequestCallback) => {
      cb(0);
      return 0;
    }) as typeof window.requestAnimationFrame;
    window.cancelAnimationFrame = (() => undefined) as typeof window.cancelAnimationFrame;
  });

  const makeChat = (): ChatUI =>
    new ChatUI(container, {
      getSettings: makeSettings,
      getRemoteConfig: () => null,
      onStatusChange: () => undefined,
      onAssistantReply: (text) => replies.push(text),
      onLocalStream: (active) => streamStates.push(active),
    });

  it('tokens do streaming viram a mensagem final e a bolha sai', async () => {
    const chat = makeChat();
    await chat.init();
    const listener = llmListener();

    mocks.fakeBridge.generateLocal.mockImplementation(async () => {
      listener({ type: 'llmToken', text: 'Olá' });
      listener({ type: 'llmToken', text: ', mundo!' });
      return { json: JSON.stringify({ text: 'Olá, mundo!', tokens: 4, ms: 12 }) };
    });

    await chat.send('oi');

    expect(container.querySelector('.msg-streaming')).toBeNull();
    const texts = [...container.querySelectorAll('.msg-assistant .msg-text')].map(
      (el) => el.textContent,
    );
    expect(texts).toContain('Olá, mundo!');
    expect(replies).toContain('Olá, mundo!');
    // botão de parar: liga no começo, desliga no fim
    expect(streamStates[0]).toBe(true);
    expect(streamStates[streamStates.length - 1]).toBe(false);
  });

  it('generateLocal recebe stream:true e as configurações de amostragem', async () => {
    const chat = makeChat();
    await chat.init();

    await chat.send('quantas horas são');

    const call = mocks.fakeBridge.generateLocal.mock.calls[0]?.[0] as
      | Record<string, unknown>
      | undefined;
    expect(call?.['stream']).toBe(true);
    expect(call?.['temperature']).toBe(0.7);
    expect(call?.['seed']).toBe(-1);
  });

  it('generateLocal recebe o contrato corrigido: messagesJson (string) + system (idioma/cultura)', async () => {
    // **PT** Regressão do contrato da ponte: antes o app enviava `messages`
    // (array) e o plugin lia `messagesJson` — todo pedido do LLM local
    // falhava com `sem_mensagens`. O histórico agora chega serializado e o
    // prompt de sistema por idioma/cultura acompanha o pedido.
    // **EN** Bridge contract regression: the app used to send `messages`
    // (array) while the plugin read `messagesJson` — every local LLM request
    // failed with `sem_mensagens`. History is now serialized and the
    // language/culture system prompt travels with the request.
    const chat = makeChat();
    await chat.init();

    await chat.send('ola');

    const call = mocks.fakeBridge.generateLocal.mock.calls[0]?.[0] as
      | Record<string, unknown>
      | undefined;
    expect(typeof call?.['messagesJson']).toBe('string');
    const history = JSON.parse(call?.['messagesJson'] as string) as Array<{ role: string; content: string }>;
    expect(history.at(-1)).toMatchObject({ role: 'user', content: 'ola' });

    const system = call?.['system'] as string;
    expect(system).toContain('Geny Assistant');
    // prompt por idioma/cultura (pt-BR nas configurações de teste)
    expect(system).toContain('idioma padrao: pt-BR');
    expect(system).toContain('portugues do Brasil');
    // regra de privacidade local-first
    expect(system).toContain('nada sai do dispositivo');
  });

  it('token fora de streaming é ignorado (não cria bolha)', async () => {
    const chat = makeChat();
    await chat.init();
    const listener = llmListener();

    listener({ type: 'llmToken', text: 'órfão' });
    expect(container.querySelector('.msg-streaming')).toBeNull();

    await chat.send('oi');
    expect(container.querySelector('.msg-streaming')).toBeNull();
  });

  it('erro da ponte remove a bolha e cai no fluxo offline', async () => {
    const chat = makeChat();
    await chat.init();

    mocks.fakeBridge.generateLocal.mockImplementation(async () => {
      throw new Error('llm_unavailable');
    });

    await chat.send('oi');

    expect(container.querySelector('.msg-streaming')).toBeNull();
    // offline: mensagem final (welcome/intenção) presente
    expect(container.querySelectorAll('.msg').length).toBeGreaterThan(1);
    expect(streamStates[streamStates.length - 1]).toBe(false);
  });

  it('erro explícito do motor informa o código e encerra o streaming', async () => {
    const chat = makeChat();
    await chat.init();

    mocks.fakeBridge.generateLocal.mockImplementation(async () => ({
      json: JSON.stringify({ error: 'modelo_nao_carregado' }),
    }));

    await chat.send('oi');

    expect(container.querySelector('.msg-streaming')).toBeNull();
    expect(container.textContent).toContain('modelo_nao_carregado');
    expect(streamStates[streamStates.length - 1]).toBe(false);
  });
});
