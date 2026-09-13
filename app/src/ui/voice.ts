/**
 * Controlador de voz da UI (docs §7.4, TODO app-01): botão de microfone no
 * composer, painel de gravação com nível/transcrição ao vivo e integração
 * com o fluxo do chat (transcrição final vira mensagem do usuário).
 */
import { bridge } from '../core/bridge';
import type { VoiceEvent } from '../core/voice-types';
import { t } from '../i18n';

export interface VoiceDeps {
  getEngine: () => 'system' | 'whisper';
  getLanguage: () => string;
  getVadAutoStop: () => boolean;
  getWhisperModel: () => string;
  /** Envia a transcrição final como mensagem do usuário. */
  onSend: (text: string) => void;
  /** Notifica a aba de configurações sobre downloads de modelo. */
  onModelEvent?: (event: VoiceEvent) => void;
}

type VoiceState = 'idle' | 'listening' | 'transcribing';

export class VoiceController {
  private readonly deps: VoiceDeps;
  private readonly micBtn: HTMLButtonElement;
  private readonly panel: HTMLElement;
  private readonly statusText: HTMLElement;
  private readonly levelBar: HTMLElement;
  private readonly transcriptEl: HTMLElement;
  private readonly stopBtn: HTMLButtonElement;
  private readonly cancelBtn: HTMLButtonElement;
  private readonly dot: HTMLElement;

  private state: VoiceState = 'idle';
  private removeListener: (() => void) | null = null;
  private partial = '';

  constructor(
    elements: {
      micBtn: HTMLButtonElement;
      panel: HTMLElement;
      dot: HTMLElement;
      statusText: HTMLElement;
      levelBar: HTMLElement;
      transcript: HTMLElement;
      stop: HTMLButtonElement;
      cancel: HTMLButtonElement;
    },
    deps: VoiceDeps,
  ) {
    this.deps = deps;
    this.micBtn = elements.micBtn;
    this.panel = elements.panel;
    this.statusText = elements.statusText;
    this.levelBar = elements.levelBar;
    this.transcriptEl = elements.transcript;
    this.stopBtn = elements.stop;
    this.cancelBtn = elements.cancel;
    this.dot = elements.dot;

    this.micBtn.addEventListener('click', () => void this.toggle());
    this.stopBtn.addEventListener('click', () => void this.stopCapture());
    this.cancelBtn.addEventListener('click', () => void this.cancel());
  }

  /** Assina o canal de eventos da ponte (genyVoice). */
  async init(): Promise<void> {
    const handle = bridge.addListener('genyVoice', (event) => {
      this.onEvent(event as VoiceEvent);
    });
    this.removeListener = () => handle.remove();
  }

  destroy(): void {
    this.removeListener?.();
    this.removeListener = null;
  }

  isActive(): boolean {
    return this.state !== 'idle';
  }

  private async toggle(): Promise<void> {
    if (this.state === 'idle') {
      await this.startCapture();
    } else if (this.state === 'listening') {
      await this.stopCapture();
    }
  }

  private async startCapture(): Promise<void> {
    if (this.state !== 'idle') return;
    this.partial = '';
    this.transcriptEl.textContent = '';
    this.setLevel(0);
    this.statusText.textContent = t('voice.listening');
    this.transcriptEl.textContent = '';
    this.panel.hidden = false;
    this.setState('listening');
    try {
      const { started } = await bridge.startVoiceCapture({
        engine: this.deps.getEngine(),
        language: this.deps.getLanguage(),
        vadAutoStop: this.deps.getVadAutoStop(),
        modelId: this.deps.getWhisperModel(),
      });
      if (started === false) {
        // Falha imediata (ex.: motor indisponível): o evento de erro chega
        // pelo canal genyVoice e cuida da UI.
        this.setState('idle');
        this.panel.hidden = true;
      }
    } catch {
      this.showError('capture');
    }
  }

  private async stopCapture(): Promise<void> {
    if (this.state !== 'listening') return;
    try {
      await bridge.stopVoiceCapture();
    } catch {
      // provider sistema já respondeu sozinho; nada a fazer
    }
  }

  private async cancel(): Promise<void> {
    if (this.state === 'idle') return;
    try {
      await bridge.cancelVoiceCapture();
    } catch {
      // melhor esforço
    }
    this.setState('idle');
    this.panel.hidden = true;
  }

  private onEvent = (event: VoiceEvent): void => {
    switch (event.type) {
      case 'level':
        this.setLevel(event.level);
        break;
      case 'partial':
        this.partial = event.text;
        this.transcriptEl.textContent = this.partial;
        break;
      case 'transcribing':
        this.setState('transcribing');
        this.statusText.textContent = t('voice.transcribing');
        break;
      case 'result':
        if (event.final) {
          this.setState('idle');
          this.panel.hidden = true;
          const text = event.text.trim();
          if (text.length > 0) this.deps.onSend(text);
        }
        break;
      case 'error':
        this.showError(event.code);
        if (this.deps.onModelEvent) this.deps.onModelEvent(event);
        break;
      case 'stopped':
        // vad/maxDuration: a transcrição vem a seguir (transcribing/result).
        if (event.reason === 'cancelled') {
          this.setState('idle');
          this.panel.hidden = true;
        }
        break;
      default:
        if (this.deps.onModelEvent) this.deps.onModelEvent(event);
        break;
    }
  };

  private showError(code: string): void {
    this.setState('idle');
    const key = `voice.err.${code}`;
    const translated = t(key);
    // Chave sem tradução devolve a própria chave — usa fallback genérico.
    this.statusText.textContent =
      translated === key ? t('voice.err.speech_error') : translated;
    this.transcriptEl.textContent = '';
    this.setLevel(0);
    this.panel.hidden = false;
    window.setTimeout(() => {
      if (this.state === 'idle') this.panel.hidden = true;
    }, 2600);
  }

  private setLevel(level: number): void {
    const pct = Math.max(0, Math.min(1, level)) * 100;
    this.levelBar.style.width = `${pct.toFixed(0)}%`;
  }

  private setState(state: VoiceState): void {
    this.state = state;
    this.micBtn.classList.toggle('recording', state === 'listening');
    this.dot.classList.toggle('pulse', state === 'listening');
    this.stopBtn.disabled = state !== 'listening';
    this.cancelBtn.disabled = state === 'idle';
    this.micBtn.setAttribute(
      'aria-label',
      state === 'listening' ? t('voice.stop') : t('voice.mic'),
    );
  }
}
