/**
 * UI do chat: renderiza mensagens, confirmações de ações sensíveis e o fluxo
 * de tool calling (intenção offline ou LLM remoto/self-hosted).
 */
import { bridge, setConfirmationHandler } from '../core/bridge';
import { matchIntent } from '../core/intent';
import { remoteComplete, remoteConfigured, type RemoteConfig } from '../core/remote';
import { t } from '../i18n';
import type { ChatMessage, Settings, ToolDefinition, ToolOutcome } from '../types';

const WELCOME_KEY = 'chat.welcome';

export interface ChatDeps {
  getSettings: () => Settings;
  getRemoteConfig: () => RemoteConfig | null;
  onStatusChange: (busy: boolean) => void;
  /** Chamada para cada resposta final da Geny (usada pelo TTS — docs §7.4). */
  onAssistantReply?: (text: string) => void;
}

export class ChatUI {
  private readonly container: HTMLElement;
  private readonly deps: ChatDeps;
  private catalog: ToolDefinition[] = [];
  private messages: ChatMessage[] = [];
  private seq = 0;

  constructor(container: HTMLElement, deps: ChatDeps) {
    this.container = container;
    this.deps = deps;
    setConfirmationHandler(this.confirmNativeFlow);
  }

  async init(): Promise<void> {
    try {
      const { tools } = await bridge.listTools();
      this.catalog = tools;
    } catch {
      this.catalog = [];
    }
    this.render();
  }

  private nextId(): string {
    this.seq += 1;
    return `m${Date.now()}-${this.seq}`;
  }

  // ------------------------------------------------------------ rendering --

  render(): void {
    this.container.innerHTML = '';
    if (this.messages.length === 0) {
      const welcome = document.createElement('div');
      welcome.className = 'msg msg-assistant msg-welcome';
      welcome.textContent = t(WELCOME_KEY);
      this.container.appendChild(welcome);
      return;
    }
    for (const m of this.messages) {
      this.container.appendChild(this.renderMessage(m));
    }
    this.container.scrollTop = this.container.scrollHeight;
  }

  private renderMessage(m: ChatMessage): HTMLElement {
    const el = document.createElement('div');
    el.className = `msg msg-${m.role}`;
    if (m.role === 'tool' && m.tool) {
      const statusLabel =
        m.tool.status === 'ok'
          ? t('chat.tool.ok')
          : m.tool.status === 'denied'
            ? t('chat.tool.denied')
            : t('chat.tool.failed');
      el.classList.add(`tool-${m.tool.status}`);
      const head = document.createElement('div');
      head.className = 'tool-head';
      head.textContent = `⚙ ${m.tool.tool_id} — ${statusLabel}`;
      const body = document.createElement('pre');
      body.className = 'tool-body';
      body.textContent = JSON.stringify(m.tool.data ?? m.tool.reason ?? m.tool.error, null, 2);
      el.appendChild(head);
      el.appendChild(body);
      return el;
    }
    const text = document.createElement('span');
    text.className = 'msg-text';
    text.textContent = m.content;
    el.appendChild(text);
    if (m.role === 'assistant' && m.content.trim().length > 0) {
      const replay = document.createElement('button');
      replay.type = 'button';
      replay.className = 'icon-btn msg-replay';
      replay.setAttribute('aria-label', t('voice.speak.replay'));
      replay.title = t('voice.speak.replay');
      replay.textContent = '🔊';
      replay.addEventListener('click', () => {
        void bridge.speak({ text: m.content, language: this.deps.getSettings().language });
      });
      el.appendChild(replay);
    }
    return el;
  }

  private push(m: ChatMessage): void {
    this.messages.push(m);
    if (m.role === 'assistant' && m.content.trim().length > 0) {
      this.deps.onAssistantReply?.(m.content);
    }
    this.render();
  }

  // ------------------------------------------------------- confirmation UI --

  private confirmNativeFlow = async (
    toolId: string,
    level: string,
    summary: string,
  ): Promise<boolean> => {
    if (level === 'none') return true;
    return this.showConfirmDialog(toolId, summary);
  };

  private showConfirmDialog(toolId: string, summary: string): Promise<boolean> {
    const dialog = document.getElementById('confirm-dialog');
    if (!(dialog instanceof HTMLDialogElement)) {
      return Promise.resolve(window.confirm(summary));
    }
    return new Promise((resolve) => {
      dialog.innerHTML = `
        <h2>${t('chat.confirm.title')}</h2>
        <p><strong>${toolId}</strong></p>
        <p>${summary}</p>
        <div class="confirm-actions">
          <button type="button" class="btn-danger" data-act="deny">${t('chat.confirm.deny')}</button>
          <button type="button" class="btn-primary" data-act="allow">${t('chat.confirm.allow')}</button>
        </div>`;
      dialog.showModal();
      dialog.addEventListener(
        'click',
        (ev) => {
          const target = ev.target as HTMLElement;
          const act = target.dataset.act;
          if (act === 'allow' || act === 'deny') {
            dialog.close();
            resolve(act === 'allow');
          }
        },
        { once: true },
      );
    });
  }

  // ------------------------------------------------------------- messaging --

  async send(rawText: string): Promise<void> {
    const text = rawText.trim();
    if (text.length === 0) return;

    this.push({ id: this.nextId(), role: 'user', content: text, at: Date.now() });
    this.deps.onStatusChange(true);

    try {
      const cfg = this.deps.getRemoteConfig();
      if (this.deps.getSettings().mode !== 'local' && remoteConfigured(cfg)) {
        await this.sendViaRemote(cfg);
      } else {
        await this.sendOffline(text);
      }
    } catch (err) {
      this.push({
        id: this.nextId(),
        role: 'assistant',
        content: `${t('error.generic')} (${err instanceof Error ? err.message : 'erro'})`,
        at: Date.now(),
      });
    } finally {
      this.deps.onStatusChange(false);
    }
  }

  private async sendOffline(text: string): Promise<void> {
    const intent = matchIntent(text);
    if (intent === null) {
      this.push({
        id: this.nextId(),
        role: 'assistant',
        content: t('chat.welcome'),
        at: Date.now(),
      });
      return;
    }
    const outcome = await this.runTool(intent.toolId, intent.params);
    this.push({
      id: this.nextId(),
      role: 'tool',
      content: '',
      at: Date.now(),
      tool: outcome,
    });
  }

  /** A mensagem do usuário já está no histórico quando este método roda. */
  private async sendViaRemote(cfg: RemoteConfig): Promise<void> {
    const history = this.messages
      .filter((m) => m.role !== 'tool')
      .slice(-12)
      .map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content }));
    const system = this.systemPrompt();
    const result = await remoteComplete(cfg, system, history);
    if (result.intent !== null) {
      const outcome = await this.runTool(result.intent.toolId, result.intent.params);
      this.push({
        id: this.nextId(),
        role: 'tool',
        content: '',
        at: Date.now(),
        tool: outcome,
      });
      if (outcome.status === 'ok') {
        this.push({
          id: this.nextId(),
          role: 'assistant',
          content: t('chat.tool.ok'),
          at: Date.now(),
        });
      }
      return;
    }
    this.push({
      id: this.nextId(),
      role: 'assistant',
      content: result.text,
      at: Date.now(),
    });
  }

  private systemPrompt(): string {
    const lang = this.deps.getSettings().language;
    return [
      `Voce e o Geny Assistant, assistente local-first. Idioma do usuario: ${lang}.`,
      'Para agir, devolva APENAS um JSON: {"tool": "<id>", "params": {...}} usando o catalogo abaixo. Nao invente ferramentas.',
      `Catalogo: ${JSON.stringify(this.catalog)}`,
    ].join('\n');
  }

  // -------------------------------------------------------------- tool run --

  private async runTool(
    toolId: string,
    params: Record<string, unknown>,
  ): Promise<ToolOutcome> {
    const def = this.catalog.find((d) => d.id === toolId);
    if (!def) {
      return { status: 'failed', tool_id: toolId, error: 'ferramenta nao registrada' };
    }
    if (def.confirmation !== 'none') {
      const approved = await bridge.requestConfirmation({
        toolId,
        level: def.confirmation,
        summary: `${def.name}: ${JSON.stringify(params)}`,
      });
      if (!approved) {
        return { status: 'denied', tool_id: toolId, reason: t('chat.tool.denied') };
      }
    }
    try {
      const { outcomeJson } = await bridge.invokeTool({
        callId: this.nextId(),
        toolId,
        paramsJson: JSON.stringify(params),
      });
      // Contrato da ponte (docs §12.4): o nativo resolve SEMPRE com
      // outcomeJson serializado. A ausência do campo significa quebra de
      // contrato — mensagem explícita em vez de "undefined" is not valid JSON.
      if (typeof outcomeJson !== 'string') {
        return { status: 'failed', tool_id: toolId, error: t('error.bridge.contract') };
      }
      return JSON.parse(outcomeJson) as ToolOutcome;
    } catch (err) {
      return {
        status: 'failed',
        tool_id: toolId,
        error: err instanceof Error ? err.message : 'erro desconhecido',
      };
    }
  }
}
