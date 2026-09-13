/**
 * Controlador de voz da UI (docs §7.4, TODO app-01): botão de microfone no
 * composer, painel de gravação com nível/transcrição ao vivo e integração
 * com o fluxo do chat (transcrição final vira mensagem do usuário).
 *
 * **PT** Além do painel compacto, controla a TELA de conversa por voz em
 * tela cheia (estilo assistente de voz): orb animado por estado
 * (respirando/ouvindo/pensando/falando), legenda ao vivo, histórico da
 * conversa e modo MÃOS-LIVRES — a Geny responde por voz e volta a ouvir
 * sozinha quando termina de falar (eventos `genyTts`).
 * **EN** Beyond the compact panel it drives the full-screen voice
 * conversation screen: state-driven animated orb (idle/listening/thinking/
 * speaking), live caption, conversation log and HANDS-FREE mode — the
 * assistant speaks its reply and starts listening again automatically via
 * `genyTts` events.
 */
import { bridge } from '../core/bridge';
import type { TtsEvent, VoiceEvent } from '../core/voice-types';
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
  /** A Geny responde por voz? (mãos-livres espera o TTS terminar). */
  getVoiceReplies?: () => boolean;
}

export interface VoiceScreenElements {
  screen: HTMLElement;
  orb: HTMLElement;
  caption: HTMLElement;
  log: HTMLElement;
  close: HTMLButtonElement;
  bigMic: HTMLButtonElement;
  handsFree: HTMLButtonElement;
  stopAudio: HTMLButtonElement;
}

type VoiceState = 'idle' | 'listening' | 'transcribing' | 'thinking' | 'speaking';

/** Espera máxima pela fala antes de voltar a ouvir (TTS pode falhar calado). */
const SPEAK_WAIT_TIMEOUT_MS = 8_000;

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
  private readonly screen: VoiceScreenElements | null;

  private state: VoiceState = 'idle';
  private removeListener: (() => void) | null = null;
  private removeTtsListener: (() => void) | null = null;
  private partial = '';
  private handsFree = true;
  private speakWaitTimer: number | null = null;

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
    screen?: VoiceScreenElements,
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
    this.screen = screen ?? null;

    this.micBtn.addEventListener('click', () => {
      if (this.screen) {
        this.openScreen();
      } else {
        void this.toggle();
      }
    });
    this.stopBtn.addEventListener('click', () => void this.stopCapture());
    this.cancelBtn.addEventListener('click', () => void this.cancel());

    if (this.screen) {
      this.screen.close.addEventListener('click', () => this.closeScreen());
      this.screen.bigMic.addEventListener('click', () => void this.onBigMic());
      this.screen.handsFree.addEventListener('click', () => {
        this.handsFree = !this.handsFree;
        this.screen!.handsFree.setAttribute('aria-pressed', String(this.handsFree));
        if (this.handsFree && this.state === 'idle') void this.startCapture();
      });
      this.screen.stopAudio.addEventListener('click', () => {
        void bridge.stopSpeaking();
      });
      window.addEventListener('keydown', (ev) => {
        if (ev.key === 'Escape' && this.screenOpen) this.closeScreen();
      });
    }
  }

  /** Assina os canais de eventos da ponte (genyVoice + genyTts). */
  async init(): Promise<void> {
    const handle = bridge.addListener('genyVoice', (event) => {
      this.onEvent(event as VoiceEvent);
    });
    this.removeListener = () => handle.remove();
    const ttsHandle = bridge.addListener('genyTts', (event) => {
      this.onTtsEvent(event as TtsEvent);
    });
    this.removeTtsListener = () => ttsHandle.remove();
  }

  destroy(): void {
    this.removeListener?.();
    this.removeListener = null;
    this.removeTtsListener?.();
    this.removeTtsListener = null;
    this.clearSpeakWait();
  }

  isActive(): boolean {
    return this.state !== 'idle';
  }

  get screenOpen(): boolean {
    return this.screen !== null && !this.screen.screen.hidden;
  }

  // ------------------------------------------------------- tela de voz --

  private openScreen(): void {
    if (!this.screen || this.screenOpen) return;
    this.screen.screen.hidden = false;
    this.screen.close.setAttribute('aria-label', t('voice.screen.close'));
    this.screen.handsFree.setAttribute('aria-pressed', String(this.handsFree));
    this.setCaption(t('voice.listening'));
    this.setState('listening');
    void this.startCapture();
    this.screen.close.focus();
  }

  private closeScreen(): void {
    if (!this.screen || !this.screenOpen) return;
    this.screen.screen.hidden = true;
    this.clearSpeakWait();
    this.setCaption('');
    this.stopAudioChip(false);
    void this.cancel();
  }

  private async onBigMic(): Promise<void> {
    if (!this.screen) return;
    if (this.state === 'listening') {
      await this.stopCapture();
    } else if (this.state === 'speaking') {
      await bridge.stopSpeaking();
    } else if (this.state === 'idle') {
      await this.startCapture();
    }
  }

  private setCaption(text: string): void {
    if (this.screen) this.screen.caption.textContent = text;
  }

  private addLogEntry(role: 'user' | 'assistant', text: string): void {
    if (!this.screen || text.length === 0) return;
    const li = document.createElement('li');
    li.dataset.role = role;
    li.textContent = text;
    this.screen.log.appendChild(li);
    this.screen.log.hidden = false;
    this.screen.log.scrollTop = this.screen.log.scrollHeight;
  }

  private stopAudioChip(show: boolean): void {
    if (this.screen) this.screen.stopAudio.hidden = !show;
  }

  /**
   * A Geny respondeu (chamado pelo main.ts quando a resposta chega ao chat).
   * Na tela: registra a fala e, no modo mãos-livres, volta a ouvir depois
   * que a fala terminar (ou imediatamente se a resposta por voz está off).
   */
  notifyAssistantReply(text: string): void {
    if (!this.screenOpen) return;
    this.addLogEntry('assistant', text);
    if (this.state === 'transcribing' || this.state === 'listening') return;
    const speaks = this.deps.getVoiceReplies?.() ?? false;
    if (speaks) {
      // espera o evento genyTts start→done; rede de segurança por timeout.
      this.setState('thinking');
      this.setCaption(t('voice.state.thinking'));
      this.clearSpeakWait();
      this.speakWaitTimer = window.setTimeout(() => this.resumeListening(), SPEAK_WAIT_TIMEOUT_MS);
    } else {
      this.resumeListening();
    }
  }

  private resumeListening(): void {
    this.clearSpeakWait();
    if (!this.screenOpen || !this.handsFree) {
      if (this.screenOpen) this.setState('idle');
      return;
    }
    this.setState('listening');
    this.setCaption(t('voice.listening'));
    void this.startCapture();
  }

  private clearSpeakWait(): void {
    if (this.speakWaitTimer !== null) {
      window.clearTimeout(this.speakWaitTimer);
      this.speakWaitTimer = null;
    }
  }

  private onTtsEvent(event: TtsEvent): void {
    if (event.type === 'start') {
      this.clearSpeakWait();
      this.setState('speaking');
      this.setCaption(t('voice.state.speaking'));
      this.stopAudioChip(true);
      return;
    }
    // done | error
    this.stopAudioChip(false);
    if (this.state === 'speaking') {
      this.setCaption('');
      this.resumeListening();
    }
  }

  // ------------------------------------------------- captura (legado) --

  private async toggle(): Promise<void> {
    if (this.state === 'idle') {
      await this.startCapture();
    } else if (this.state === 'listening') {
      await this.stopCapture();
    }
  }

  private async startCapture(): Promise<void> {
    if (this.state !== 'idle' && this.state !== 'listening') return;
    this.partial = '';
    this.transcriptEl.textContent = '';
    this.setLevel(0);
    this.statusText.textContent = t('voice.listening');
    if (!this.screen) {
      this.panel.hidden = false;
    } else {
      this.setCaption(t('voice.listening'));
    }
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
        if (!this.screen) this.panel.hidden = true;
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
    if (!this.screen) this.panel.hidden = true;
  }

  private onEvent = (event: VoiceEvent): void => {
    switch (event.type) {
      case 'level':
        this.setLevel(event.level);
        break;
      case 'partial':
        this.partial = event.text;
        this.transcriptEl.textContent = this.partial;
        this.setCaption(this.partial);
        break;
      case 'transcribing':
        this.setState('transcribing');
        this.statusText.textContent = t('voice.transcribing');
        this.setCaption(t('voice.transcribing'));
        break;
      case 'result':
        if (event.final) {
          const text = event.text.trim();
          if (text.length > 0) {
            this.addLogEntry('user', text);
            this.deps.onSend(text);
          }
          if (this.screenOpen) {
            // mãos-livres: aguarda a resposta da Geny (notifyAssistantReply).
            this.setState('thinking');
            this.setCaption('');
          } else {
            this.setState('idle');
            this.panel.hidden = true;
          }
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
          if (!this.screen) this.panel.hidden = true;
          this.setCaption('');
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
    const message = translated === key ? t('voice.err.speech_error') : translated;
    this.statusText.textContent = message;
    this.transcriptEl.textContent = '';
    this.setLevel(0);
    if (this.screen) {
      this.setCaption(message);
      this.clearSpeakWait();
    } else {
      this.panel.hidden = false;
      window.setTimeout(() => {
        if (this.state === 'idle') this.panel.hidden = true;
      }, 2600);
    }
  }

  private setLevel(level: number): void {
    const clamped = Math.max(0, Math.min(1, level));
    const pct = clamped * 100;
    this.levelBar.style.width = `${pct.toFixed(0)}%`;
    if (this.screen) {
      this.screen.orb.style.setProperty('--level', clamped.toFixed(2));
    }
  }

  private setState(state: VoiceState): void {
    this.state = state;
    this.micBtn.classList.toggle('recording', state === 'listening');
    this.dot.classList.toggle('pulse', state === 'listening');
    this.stopBtn.disabled = state !== 'listening';
    this.cancelBtn.disabled = state === 'idle';
    if (this.screen) {
      this.screen.orb.dataset.state = state;
      this.screen.bigMic.classList.toggle('recording', state === 'listening');
      this.screen.bigMic.setAttribute(
        'aria-label',
        state === 'listening' ? t('voice.stop') : t('voice.mic'),
      );
    }
    this.micBtn.setAttribute(
      'aria-label',
      state === 'listening' ? t('voice.stop') : t('voice.mic'),
    );
  }
}
