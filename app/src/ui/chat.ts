/**
 * UI do chat: renderiza mensagens, confirmações de ações sensíveis e o fluxo
 * de tool calling (intenção offline ou LLM remoto/self-hosted).
 */
import { bridge, setConfirmationHandler } from '../core/bridge';
import { pickBackend, type BackendContext, type PickedBackend } from '../core/backend-picker';
import { compactOutcomeJson, toolFollowupInstruction } from '../core/followup';
import type { LlmEvent } from '../core/llm-types';
import { matchIntent } from '../core/intent';
import { remoteComplete, remoteStream, remoteConfigured, tryParseToolCall, type RemoteConfig } from '../core/remote';
import { effectiveProvider, suggestModeForProfile } from '../core/providers';
import { buildSystemPrompt } from '../core/system-prompt';
import { t, tf } from '../i18n';
import type { ChatMessage, Settings, ToolDefinition, ToolOutcome } from '../types';

const WELCOME_KEY = 'chat.welcome';

export interface ChatDeps {
  getSettings: () => Settings;
  getRemoteConfig: () => RemoteConfig | null;
  onStatusChange: (busy: boolean) => void;
  /** Chamada para cada resposta final da Geny (usada pelo TTS — docs §7.4). */
  onAssistantReply?: (text: string) => void;
  /**
   * Streaming ativo (LLM local core-05b e remoto SSE app-05): ligado quando
   * a geração em stream começa e desligado quando termina — liga o botão
   * de Parar em ambos os casos.
   */
  onStreamActive?: (active: boolean) => void;
}

export class ChatUI {
  private readonly container: HTMLElement;
  private readonly deps: ChatDeps;
  private catalog: ToolDefinition[] = [];
  private messages: ChatMessage[] = [];
  private seq = 0;

  /** Estado do streaming (LLM local core-05b e remoto SSE app-05). */
  private stream: {
    active: boolean;
    buffer: string;
    el: HTMLElement | null;
    raf: number | null;
  } | null = null;

  /** Abort do SSE remoto em voo (botão Parar). */
  private remoteAbort: AbortController | null = null;

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
    try {
      await bridge.addListener('genyLlm', (event) => this.onLlmEvent(event as LlmEvent));
    } catch {
      // ponte sem canal de eventos (testes/web): streaming fica inativo
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
        void bridge.speak({
          text: m.content,
          language: this.deps.getSettings().language,
          engine: this.deps.getSettings().ttsEngine ?? 'system',
        });
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

  // --------------------------------------------------- streaming (core-05b) --

  private onLlmEvent(event: LlmEvent): void {
    if (event.type !== 'llmToken') return;
    const s = this.stream;
    if (s === null || !s.active) return; // token fora de streaming: ignora
    this.appendStreamToken(event.text);
  }

  /** Acumula um token na bolha provisória (rAF batching, local e remoto). */
  private appendStreamToken(piece: string): void {
    const s = this.stream;
    if (s === null) return;
    s.buffer += piece;
    if (s.raf === null) {
      s.raf = window.requestAnimationFrame(() => {
        if (s === null) return;
        s.raf = null;
        if (s.el !== null) {
          const textEl = s.el.querySelector('.msg-text');
          if (textEl !== null) textEl.textContent = s.buffer;
          this.container.scrollTop = this.container.scrollHeight;
        }
      });
    }
  }

  /** Cria a bolha provisória que recebe os tokens do streaming. */
  private beginStreaming(): void {
    this.endStreaming();
    const el = document.createElement('div');
    el.className = 'msg msg-assistant msg-streaming';
    const text = document.createElement('span');
    text.className = 'msg-text';
    const cursor = document.createElement('span');
    cursor.className = 'stream-cursor';
    cursor.setAttribute('aria-hidden', 'true');
    el.appendChild(text);
    el.appendChild(cursor);
    this.container.appendChild(el);
    this.container.scrollTop = this.container.scrollHeight;
    this.stream = { active: true, buffer: '', el, raf: null };
    this.deps.onStreamActive?.(true);
  }

  /** Remove a bolha provisória (a mensagem final entra por `push`). */
  private endStreaming(): void {
    const s = this.stream;
    if (s === null) return;
    s.active = false;
    if (s.raf !== null) window.cancelAnimationFrame(s.raf);
    s.el?.remove();
    this.stream = null;
    this.deps.onStreamActive?.(false);
  }

  /**
   * Parada pedida pela UI (botão Parar, TODO app-05): aborta o SSE remoto
   * em voo — a promessa rejeita com AbortError e o turno termina limpo.
   * O streaming local é parado pelo nativo (stopLocalGenerate).
   */
  abortRemoteStream(): void {
    this.remoteAbort?.abort();
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
      const settings = this.deps.getSettings();
      const backend = await this.pickBackendForTurn(settings, cfg);
      if (backend === 'remote' && remoteConfigured(cfg)) {
        await this.sendViaRemote(cfg);
      } else if (backend === 'local') {
        // Fase 3 (TODO app-02): backend local GGUF. No modo explícito `local`,
        // erro do motor aparece como mensagem; no `auto`, degrada para o
        // roteador de intenções offline (seleção automática, Fase 3).
        const viaLocal = await this.sendViaLocalLlm(settings.mode === 'auto');
        if (!viaLocal) await this.sendOffline(text);
      } else {
        await this.sendOffline(text);
      }
    } catch (err) {
      this.endStreaming();
      this.remoteAbort = null;
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

  /**
   * Seleção de backend para este turno (TODO Fase 3 — bateria, rede e
   * configuração): lê o DeviceContext da ponte (bateria/rede) com valores
   * conservadores quando indisponível e delega ao `pickBackend` puro.
   *
   * Fase 6 (TODO core-10): quando um perfil de operação está ativo e o modo
   * é `auto`, as regras do perfil (espelho do Rust `suggest_mode`) restringem
   * a escolha — offline-total nunca fala com a rede; servidor de casa só
   * usa o endpoint self-hosted; híbrido é o auto clássico. Modos explícitos
   * (remote/local) continuam mandando — o usuário pediu, o perfil respeita.
   */
  private async pickBackendForTurn(settings: Settings, cfg: RemoteConfig | null): Promise<PickedBackend> {
    const remoteReady = remoteConfigured(cfg);
    const ctx: BackendContext = {
      mode: settings.mode,
      remoteReady,
      online: true,
      batteryPct: -1,
      batterySaver: false,
      thermalHigh: false,
      localModelFile: settings.localModel,
    };
    let online = true;
    if (settings.mode !== 'auto') return pickBackend(ctx);
    try {
      const { json } = await bridge.getDeviceContext();
      const device = JSON.parse(json) as { online?: boolean; batteryPct?: number; batterySaver?: boolean; thermalHigh?: boolean };
      ctx.online = device.online ?? true;
      ctx.batteryPct = device.batteryPct ?? -1;
      ctx.batterySaver = device.batterySaver ?? false;
      ctx.thermalHigh = device.thermalHigh ?? false;
      online = ctx.online;
    } catch {
      // sem contexto do dispositivo: segue com os defaults conservadores
      // (assumir online só é usado quando há remoto configurado)
    }
    const profile = settings.profile ?? 'default';
    if (profile !== 'default') {
      const preset = effectiveProvider(settings.provider);
      const selfhosted = preset.tier === 'self-hosted';
      const suggested = suggestModeForProfile({
        profile,
        online,
        localReady: settings.localModel.length > 0,
        // endpoint "custom" é tratado como nuvem (não dá para saber sozinho)
        premiumReady: remoteReady && (preset.id === 'custom' || !selfhosted),
        selfhostedReady: remoteReady && preset.id !== 'custom' && selfhosted,
      });
      if (suggested !== null) return suggested;
    }
    return pickBackend(ctx);
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
    const system = await this.systemPrompt();
    // TODO app-05 (Fase 6): streaming SSE — paridade com o LLM local. A
    // bolha provisória recebe os tokens; falha/abort limpa a bolha e o
    // fluxo de erro do `send` informa o motivo.
    this.beginStreaming();
    this.remoteAbort = new AbortController();
    let result;
    try {
      result = await remoteStream(cfg, system, history, {
        onToken: (piece) => this.appendStreamToken(piece),
        signal: this.remoteAbort.signal,
      });
    } finally {
      this.remoteAbort = null;
      this.endStreaming();
    }
    if (result.intent !== null) {
      const outcome = await this.runTool(result.intent.toolId, result.intent.params);
      this.push({
        id: this.nextId(),
        role: 'tool',
        content: '',
        at: Date.now(),
        tool: outcome,
      });
      if (outcome.status !== 'ok') return;
      // core-06 (2ª passagem): o resultado da ferramenta volta ao modelo
      // e vira resposta natural — em vez do genérico "Pronto!".
      const reply = await this.followupViaRemote(cfg, result.intent.toolId, outcome);
      this.push({
        id: this.nextId(),
        role: 'assistant',
        content: reply ?? t('chat.tool.ok'),
        at: Date.now(),
      });
      return;
    }
    this.push({
      id: this.nextId(),
      role: 'assistant',
      content: result.text,
      at: Date.now(),
    });
  }

  /**
   * core-06 (2ª passagem remota): o resultado JSON da ferramenta volta ao
   * modelo com instrução de responder em linguagem natural. A resposta NUNCA
   * é reinterpreta­da como tool call (sem loops); falha devolve `null` e a
   * UI mostra a mensagem genérica de sucesso.
   */
  private async followupViaRemote(
    cfg: RemoteConfig,
    toolId: string,
    outcome: ToolOutcome,
  ): Promise<string | null> {
    const history = this.messages
      .filter((m) => m.role !== 'tool')
      .slice(-12)
      .map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content }));
    history.push({
      role: 'user',
      content: toolFollowupInstruction(toolId, compactOutcomeJson(outcome as unknown as Record<string, unknown>)),
    });
    try {
      const result = await remoteComplete(cfg, await this.systemPrompt(), history);
      const text = result.text.trim();
      return text.length > 0 ? text : null;
    } catch {
      return null;
    }
  }

  /**
   * Gera a resposta com o LLM local (llama.cpp via ponte) com streaming
   * (TODO core-05b): os tokens chegam pelo canal `genyLlm` e são desenhados
   * progressivamente enquanto a promessa não resolve. Devolve `false`
   * quando o motor não está disponível — o fluxo cai para intenções offline.
   */
  private async sendViaLocalLlm(allowEngineFallback = false): Promise<boolean> {
    const history = this.messages
      .filter((m) => m.role !== 'tool')
      .slice(-10)
      .map((m) => ({ role: m.role === 'assistant' ? 'assistant' as const : 'user' as const, content: m.content }));
    const settings = this.deps.getSettings();
    this.beginStreaming();
    try {
      const { json } = await bridge.generateLocal({
        // Contrato da ponte (corrigido): histórico serializado em
        // `messagesJson` + prompt de sistema por idioma/cultura em `system`.
        // Antes enviávamos `messages` (array) e o plugin lia `messagesJson`
        // — todo pedido caía em `sem_mensagens`.
        messagesJson: JSON.stringify(history),
        system: await this.systemPrompt(),
        maxTokens: 256,
        temperature: settings.localTemperature ?? 0.7,
        topP: 0.9,
        seed: settings.localSeed ?? -1,
        stream: true,
      });
      const result = JSON.parse(json) as { text?: string; error?: string };
      this.endStreaming();
      if (result.error !== undefined || typeof result.text !== 'string') {
        // Motor indisponível (ex.: modelo_nao_carregado): no modo `auto`
        // (seleção automática) degrada para intenções offline; no modo
        // `local` explícito informa o erro e não cai no fluxo offline.
        if (allowEngineFallback) return false;
        this.push({
          id: this.nextId(),
          role: 'assistant',
          content: tf('chat.local.error', { code: result.error ?? 'unknown' }),
          at: Date.now(),
        });
        return true;
      }
      const intent = tryParseToolCall(result.text);
      if (intent !== null) {
        const outcome = await this.runTool(intent.toolId, intent.params);
        this.push({
          id: this.nextId(),
          role: 'tool',
          content: '',
          at: Date.now(),
          tool: outcome,
        });
        if (outcome.status !== 'ok') return true;
        // core-06 (2ª passagem local): resultado volta ao modelo, mesmo
        // contrato da 1ª passagem (messagesJson + system), sem streaming.
        const reply = await this.followupViaLocal(intent.toolId, outcome);
        this.push({
          id: this.nextId(),
          role: 'assistant',
          content: reply ?? t('chat.tool.ok'),
          at: Date.now(),
        });
        return true;
      }
      this.push({
        id: this.nextId(),
        role: 'assistant',
        content: result.text.trim().length > 0 ? result.text : t('chat.welcome'),
        at: Date.now(),
      });
      return true;
    } catch {
      // mock web/erro de ponte: segue no fluxo offline
      this.endStreaming();
      return false;
    }
  }

  /**
   * core-06 (2ª passagem local): mesmo contrato da 1ª (`messagesJson` +
   * `system`), sem streaming; resposta nunca reinterpreta­da como tool call;
   * falha devolve `null` (mensagem genérica de sucesso).
   */
  private async followupViaLocal(toolId: string, outcome: ToolOutcome): Promise<string | null> {
    const history = this.messages
      .filter((m) => m.role !== 'tool')
      .slice(-10)
      .map((m) => ({ role: m.role === 'assistant' ? 'assistant' as const : 'user' as const, content: m.content }));
    history.push({
      role: 'user',
      content: toolFollowupInstruction(toolId, compactOutcomeJson(outcome as unknown as Record<string, unknown>)),
    });
    try {
      const settings = this.deps.getSettings();
      const { json } = await bridge.generateLocal({
        messagesJson: JSON.stringify(history),
        system: await this.systemPrompt(),
        maxTokens: 192,
        temperature: settings.localTemperature ?? 0.7,
        topP: 0.9,
        seed: settings.localSeed ?? -1,
        stream: false,
      });
      const result = JSON.parse(json) as { text?: string; error?: string };
      const text = (result.text ?? '').trim();
      return result.error === undefined && text.length > 0 ? text : null;
    } catch {
      return null;
    }
  }

  /**
   * Prompt de sistema por idioma/cultura (TODO Fase 3) — fonte única
   * (`buildSystemPrompt`, espelho do `i18n.rs` do core) para os backends
   * remoto e local; o catálogo entra como JSON para o modelo só selecionar
   * ferramentas registradas. Fase 5 (core-08): inclui o recall de memória
   * ANTES de responder — fatos relevantes entram como linhas no prompt.
   */
  private async systemPrompt(): Promise<string> {
    const lang = this.deps.getSettings().language;
    const memoryLines = await this.recallMemoryLines();
    return buildSystemPrompt({
      language: lang,
      toolCatalogJson: JSON.stringify(this.catalog),
      memoryLines,
    });
  }

  /**
   * Recall de memória (Fase 5, core-08/core-09): busca top-5 por similaridade
   * da última mensagem do usuário — semântica no núcleo (score de cosseno)
   * ou substring na ponte; qualquer falha degrada para prompt sem fatos.
   */
  private async recallMemoryLines(): Promise<string[]> {
    const lastUser = [...this.messages].reverse().find((m) => m.role === 'user');
    if (lastUser === undefined || lastUser.content.trim().length === 0) return [];
    try {
      const { hits } = await bridge.memorySearch({ query: lastUser.content, limit: 5 });
      return hits.slice(0, 5).map((h) => `${h.key} = ${h.value}`);
    } catch {
      return [];
    }
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
