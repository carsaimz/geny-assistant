/**
 * Memória de longo prazo no chat (Fase 5, TODO core-08 / android-08).
 *
 * **PT** O recall acontece ANTES de responder: `ChatUI` consulta
 * `memorySearch` com a última mensagem do usuário e os fatos relevantes
 * entram como linhas na seção de memória do prompt de sistema — vale para
 * o backend remoto e para o local. Sem ponte ou sem hits, o prompt segue
 * sem fatos (degradação silenciosa).
 * **EN** Recall happens BEFORE answering: `ChatUI` queries `memorySearch`
 * with the user's last message and relevant facts enter the memory section
 * of the system prompt — for both remote and local backends. Without a
 * bridge or without hits, the prompt carries no facts (silent degradation).
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => {
  const fakeBridge = {
    listTools: vi.fn(async (): Promise<{ tools: ToolDefinition[] }> => ({ tools: [] })),
    addListener: vi.fn(async () => ({ remove: (): void => undefined })),
    getDeviceContext: vi.fn(async () => ({
      json: JSON.stringify({ online: true, batteryPct: 80, batterySaver: false, thermalHigh: false }),
    })),
    generateLocal: vi.fn(async (_opts?: unknown) => ({ json: JSON.stringify({ text: 'ok' }) })),
    stopLocalGenerate: vi.fn(async () => undefined),
    requestConfirmation: vi.fn(async () => ({ approved: true })),
    invokeTool: vi.fn(async () => ({ outcomeJson: '{"status":"ok","tool_id":"x"}' })),
    speak: vi.fn(async () => undefined),
    memorySearch: vi.fn(async () => ({
      ok: true,
      hits: [{ key: 'wifi', value: 'senha 12345678', score: 0.42 }],
    })),
  };
  return { fakeBridge };
});

vi.mock('../core/bridge', () => ({
  bridge: mocks.fakeBridge,
  setConfirmationHandler: (): void => undefined,
}));

import { ChatUI } from '../ui/chat';
import { t } from '../i18n';
import type { Settings, ToolDefinition } from '../types';

function makeSettings(): Settings {
  return {
    mode: 'local',
    language: 'pt-BR',
    model: '',
    baseUrl: '',
    apiKeySet: false,
    voiceReplies: false,
    sttEngine: 'system',
    ttsEngine: 'system',
    vadAutoStop: true,
    whisperModel: 'whisper-tiny',
    localModel: 'modelo.gguf',
    localTemperature: 0.7,
    localSeed: -1,
  };
}

function mount(): HTMLElement {
  const container = document.createElement('div');
  document.body.appendChild(container);
  // jsdom sem pretendToBeVisual: executa o rAF imediatamente.
  window.requestAnimationFrame = ((cb: FrameRequestCallback) => {
    cb(0);
    return 0;
  }) as typeof window.requestAnimationFrame;
  window.cancelAnimationFrame = (() => undefined) as typeof window.cancelAnimationFrame;
  return container;
}

describe('recall de memória no prompt (Fase 5)', () => {
  let container: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = '';
    mocks.fakeBridge.memorySearch.mockClear();
    mocks.fakeBridge.generateLocal.mockClear();
    container = mount();
  });

  it('fatos relevantes entram no system do generateLocal', async () => {
    const ui = new ChatUI(container, {
      getSettings: makeSettings,
      getRemoteConfig: () => null,
      onStatusChange: () => undefined,
      onAssistantReply: () => undefined,
      onStreamActive: () => undefined,
    });
    await ui.init();
    await ui.send('qual a senha do wifi?');
    await new Promise((r) => setTimeout(r, 0));

    expect(mocks.fakeBridge.memorySearch).toHaveBeenCalled();
    const call = (mocks.fakeBridge.memorySearch as ReturnType<typeof vi.fn>).mock
      .calls[0]?.[0] as { query: string } | undefined;
    expect(call?.query).toBe('qual a senha do wifi?');

    const opts = mocks.fakeBridge.generateLocal.mock.calls[0]?.[0] as { system: string };
    expect(opts.system).toContain('Fatos relevantes');
    expect(opts.system).toContain('- wifi = senha 12345678');
  });

  it('sem fatos o prompt segue sem a seção de memória', async () => {
    mocks.fakeBridge.memorySearch.mockImplementation(async () => ({ ok: true, hits: [] }));
    const ui = new ChatUI(container, {
      getSettings: makeSettings,
      getRemoteConfig: () => null,
      onStatusChange: () => undefined,
      onAssistantReply: () => undefined,
      onStreamActive: () => undefined,
    });
    await ui.init();
    await ui.send('bom dia!');
    await new Promise((r) => setTimeout(r, 0));
    const opts = mocks.fakeBridge.generateLocal.mock.calls[0]?.[0] as { system: string } | undefined;
    expect(opts).toBeDefined();
    expect(opts!.system).not.toContain('Fatos relevantes');
  });
});

describe('memória na ponte (mock web)', () => {
  it('roundtrip set/list/search/delete/clear via bridge real do mock', async () => {
    // Usa o módulo REAL (não mockado) para exercitar o mock web.
    vi.resetModules();
    vi.doUnmock('../core/bridge');
    const real = await import('../core/bridge');
    localStorage.removeItem('geny.facts');

    await real.bridge.memorySet({ key: 'wifi', value: 'Rede5G' });
    const list = await real.bridge.memoryList();
    expect(list.ok).toBe(true);
    expect(list.facts).toHaveLength(1);
    expect(list.facts[0]?.key).toBe('wifi');

    const search = await real.bridge.memorySearch({ query: 'wifi', limit: 3 });
    expect(search.hits).toHaveLength(1);
    expect(search.hits[0]?.value).toBe('Rede5G');

    const del = await real.bridge.memoryDelete({ key: 'wifi' });
    expect(del.deleted).toBe(true);

    const envelope = await real.bridge.memoryExport();
    const parsed = JSON.parse(envelope.json) as { version: number; facts: unknown[] };
    expect(parsed.version).toBe(1);
    expect(parsed.facts).toHaveLength(0);
    void t;
  });
});
