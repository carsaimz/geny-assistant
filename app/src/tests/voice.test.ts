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
  stopSpeaking: vi.fn(async () => undefined),
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

function makeController(
  deps: Record<string, unknown>,
  screenEls?: {
    screen: HTMLElement;
    orb: HTMLElement;
    caption: HTMLElement;
    log: HTMLElement;
    close: HTMLButtonElement;
    bigMic: HTMLButtonElement;
    handsFree: HTMLButtonElement;
    stopAudio: HTMLButtonElement;
  },
) {
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
    screenEls,
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

describe('VoiceController — tela de voz (mãos-livres)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    listeners.clear();
    vi.clearAllMocks();
  });

  function makeScreen(deps: Record<string, unknown>) {
    const screenEls = {
      screen: el('section'),
      orb: el('div'),
      caption: el('p'),
      log: el('ol'),
      close: el('button') as HTMLButtonElement,
      bigMic: el('button') as HTMLButtonElement,
      handsFree: el('button') as HTMLButtonElement,
      stopAudio: el('button') as HTMLButtonElement,
    };
    // espelha o estado inicial do index.html (atributos hidden)
    screenEls.screen.hidden = true;
    screenEls.log.hidden = true;
    screenEls.stopAudio.hidden = true;
    const made = makeController(deps, screenEls);
    return { ...made, ...screenEls };
  }

  const baseDeps = (onSend: ReturnType<typeof vi.fn>, voiceReplies = true) => ({
    getEngine: () => 'system',
    getLanguage: () => 'pt-BR',
    getVadAutoStop: () => true,
    getWhisperModel: () => 'whisper-tiny',
    getVoiceReplies: () => voiceReplies,
    onSend,
  });

  it('toque no microfone abre a tela e começa a ouvir', async () => {
    const { controller, micBtn, screen: screenEl, orb } = makeScreen(baseDeps(vi.fn()));
    await controller.init();
    micBtn.click();
    await vi.advanceTimersByTimeAsync(0);
    expect(screenEl.hidden).toBe(false);
    expect(orb.dataset.state).toBe('listening');
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalled();
  });

  it('resultado na tela: bolha do usuário + estado pensando', async () => {
    const onSend = vi.fn();
    const { controller, orb, log } = makeScreen(baseDeps(onSend));
    await controller.init();
    await controller['openScreen']();
    emit({ type: 'result', final: true, source: 'system', text: 'que horas são?' });
    expect(onSend).toHaveBeenCalledWith('que horas são?');
    expect(orb.dataset.state).toBe('thinking');
    expect(log.hidden).toBe(false);
    expect(log.querySelector('li[data-role="user"]')?.textContent).toBe('que horas são?');
  });

  it('mãos-livres: depois da fala (tts done) volta a ouvir', async () => {
    const { controller, orb } = makeScreen(baseDeps(vi.fn(), true));
    await controller.init();
    await controller['openScreen']();
    emit({ type: 'result', final: true, source: 'system', text: 'oi' });
    controller.notifyAssistantReply('Olá! Como posso ajudar?');
    expect(orb.dataset.state).toBe('thinking');
    emit({ type: 'start' }); // TTS começou
    expect(orb.dataset.state).toBe('speaking');
    emit({ type: 'done' }); // TTS terminou
    await vi.advanceTimersByTimeAsync(0);
    expect(orb.dataset.state).toBe('listening');
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalledTimes(2);
  });

  it('respostas por voz desligadas: volta a ouvir imediatamente', async () => {
    const { controller } = makeScreen(baseDeps(vi.fn(), false));
    await controller.init();
    await controller['openScreen']();
    emit({ type: 'result', final: true, source: 'system', text: 'oi' });
    controller.notifyAssistantReply('Resposta em texto');
    await vi.advanceTimersByTimeAsync(0);
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalledTimes(2);
  });

  it('rede de segurança: TTS que nunca começa volta a ouvir por timeout', async () => {
    const { controller } = makeScreen(baseDeps(vi.fn(), true));
    await controller.init();
    await controller['openScreen']();
    emit({ type: 'result', final: true, source: 'system', text: 'oi' });
    controller.notifyAssistantReply('Resposta');
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(8_100);
    await vi.advanceTimersByTimeAsync(0);
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalledTimes(2);
  });

  it('mãos-livres desligado: tts done não re-ouve', async () => {
    const { controller, handsFree } = makeScreen(baseDeps(vi.fn(), true));
    await controller.init();
    await controller['openScreen']();
    handsFree.click();
    expect(handsFree.getAttribute('aria-pressed')).toBe('false');
    emit({ type: 'result', final: true, source: 'system', text: 'oi' });
    controller.notifyAssistantReply('Resposta');
    emit({ type: 'start' });
    emit({ type: 'done' });
    await vi.advanceTimersByTimeAsync(0);
    expect(bridgeMock.startVoiceCapture).toHaveBeenCalledTimes(1);
  });

  it('fechar a tela cancela a captura', async () => {
    const cancelBridge = bridgeMock.cancelVoiceCapture as ReturnType<typeof vi.fn>;
    const { controller, screen: screenEl } = makeScreen(baseDeps(vi.fn()));
    await controller.init();
    await controller['openScreen']();
    controller['closeScreen']();
    expect(cancelBridge).toHaveBeenCalled();
    expect(screenEl.hidden).toBe(true);
  });

  it('botão grande para o áudio enquanto a Geny fala', async () => {
    const stopSpeaking = bridgeMock.stopSpeaking as ReturnType<typeof vi.fn>;
    const { controller, bigMic } = makeScreen(baseDeps(vi.fn(), true));
    await controller.init();
    await controller['openScreen']();
    controller.notifyAssistantReply('Resposta longa');
    emit({ type: 'start' });
    bigMic.click();
    await vi.advanceTimersByTimeAsync(0);
    expect(stopSpeaking).toHaveBeenCalled();
  });
});
