/**
 * Testes do controlador de voz (TODO app-01): fluxo iniciar→parcial→
 * resultado→envio, erros de permissão/motor indisponível e cancelamento.
 * A ponte é simulada (vi.mock) para exercitar apenas a lógica da UI.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

type Listener = (event: unknown) => void;
const listeners = new Set<Listener>();
const emit = (event: unknown): void => {
  listeners.forEach((fn) => fn(event));
};

const bridgeMock = {
  addListener: vi.fn((_name: string, cb: Listener) => {
    listeners.add(cb);
    return { remove: () => listeners.delete(cb) };
  }),
  startVoiceCapture: vi.fn(async () => ({ started: true })),
  stopVoiceCapture: vi.fn(async () => undefined),
  cancelVoiceCapture: vi.fn(async () => undefined),
  speak: vi.fn(async () => undefined),
  getVoiceCapabilities: vi.fn(async () => ({
    json: JSON.stringify({
      mic: true,
      systemStt: true,
      whisperNative: false,
      vadSilero: false,
      vadEngine: 'energy',
      tts: true,
      whisperModels: [],
    }),
  })),
};

vi.mock('../core/bridge', () => ({ bridge: bridgeMock }));

const { VoiceController } = await import('../ui/voice');
const { t } = await import('../i18n');

function el(tag: string, cls = ''): HTMLElement {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  document.body.appendChild(e);
  return e;
}

function makeController(deps: Record<string, unknown>) {
  const micBtn = el('button') as HTMLButtonElement;
  const panel = el('section');
  const dot = el('span');
  const statusText = el('span');
  const levelBar = el('span');
  const transcript = el('p');
  const stop = el('button') as HTMLButtonElement;
  const cancel = el('button') as HTMLButtonElement;
  const controller = new VoiceController(
    { micBtn, panel, dot, statusText, levelBar, transcript, stop, cancel },
    deps as never,
  );
  return { controller, micBtn, panel, statusText, transcript };
}

describe('VoiceController', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    listeners.clear();
    vi.clearAllMocks();
  });

  it('resultado final envia a transcrição e fecha o painel', async () => {
    const onSend = vi.fn();
    const { controller, panel } = makeController({
      getEngine: () => 'system',
      getLanguage: () => 'pt-BR',
      getVadAutoStop: () => true,
      getWhisperModel: () => 'whisper-tiny',
      onSend,
    });
    await controller.init();
    await controller['startCapture']();
    expect(panel.hidden).toBe(false);
    emit({ type: 'result', final: true, source: 'system', text: 'abre a calculadora' });
    expect(onSend).toHaveBeenCalledWith('abre a calculadora');
    expect(panel.hidden).toBe(true);
  });

  it('transcrição parcial aparece no painel', async () => {
    const { controller, transcript } = makeController({
      getEngine: () => 'system',
      getLanguage: () => 'pt-BR',
      getVadAutoStop: () => true,
      getWhisperModel: () => 'whisper-tiny',
      onSend: vi.fn(),
    });
    await controller.init();
    await controller['startCapture']();
    emit({ type: 'partial', text: 'que horas' });
    expect(transcript.textContent).toBe('que horas');
    emit({ type: 'partial', text: 'que horas são' });
    expect(transcript.textContent).toBe('que horas são');
  });

  it('erro de permissão mostra mensagem traduzida e repousa', async () => {
    const onSend = vi.fn();
    const { controller, statusText, panel } = makeController({
      getEngine: () => 'system',
      getLanguage: () => 'pt-BR',
      getVadAutoStop: () => true,
      getWhisperModel: () => 'whisper-tiny',
      onSend,
    });
    await controller.init();
    await controller['startCapture']();
    emit({ type: 'error', code: 'denied' });
    expect(statusText.textContent).toBe(t('voice.err.denied'));
    vi.advanceTimersByTime(2700);
    expect(panel.hidden).toBe(true);
  });

  it('cancelamento esconde o painel imediatamente', async () => {
    const cancelBridge = bridgeMock.cancelVoiceCapture as ReturnType<typeof vi.fn>;
    const { controller, panel } = makeController({
      getEngine: () => 'system',
      getLanguage: () => 'pt-BR',
      getVadAutoStop: () => true,
      getWhisperModel: () => 'whisper-tiny',
      onSend: vi.fn(),
    });
    await controller.init();
    await controller['startCapture']();
    await controller['cancel']();
    expect(cancelBridge).toHaveBeenCalled();
    expect(panel.hidden).toBe(true);
  });

  it('motor whisper indisponível sinaliza erro e não envia nada', async () => {
    const onSend = vi.fn();
    (bridgeMock.startVoiceCapture as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      started: false,
    });
    const { controller } = makeController({
      getEngine: () => 'whisper',
      getLanguage: () => 'pt-BR',
      getVadAutoStop: () => true,
      getWhisperModel: () => 'whisper-tiny',
      onSend,
    });
    await controller.init();
    await controller['startCapture']();
    expect(onSend).not.toHaveBeenCalled();
  });
});
