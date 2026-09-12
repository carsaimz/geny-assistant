/**
 * Ponte com a camada nativa (Capacitor plugin `GenyBridge`).
 *
 * No Android, os métodos são implementados por
 * android/.../bridge/GenyPlugin.kt. No navegador (dev/web), um mock local
 * executa ferramentas simuladas — mantendo o app utilizável sem dispositivo,
 * sempre local-first.
 */
import { Capacitor, registerPlugin } from '@capacitor/core';
import type { ConfirmationLevel, DeviceContext, ToolDefinition, ToolOutcome } from '../types';

export interface GenyBridge {
  listTools(): Promise<{ tools: ToolDefinition[] }>;
  invokeTool(options: {
    callId: string;
    toolId: string;
    paramsJson: string;
  }): Promise<{ outcomeJson: string }>;
  requestConfirmation(options: {
    toolId: string;
    level: ConfirmationLevel;
    summary: string;
  }): Promise<{ approved: boolean }>;
  getDeviceContext(): Promise<{ json: string }>;
}

/** Handler de confirmação registrado pela UI (modal). */
export type ConfirmationHandler = (
  toolId: string,
  level: ConfirmationLevel,
  summary: string,
) => Promise<boolean>;

let confirmationHandler: ConfirmationHandler | null = null;

/** Registra o modal de confirmação usado pelo mock web. */
export function setConfirmationHandler(handler: ConfirmationHandler | null): void {
  confirmationHandler = handler;
}

// ---------------------------------------------------------------- mock web --

function webCatalog(): ToolDefinition[] {
  const def = (
    id: string,
    name: string,
    description: string,
    params: ToolDefinition['params'],
    confirmation: ConfirmationLevel,
  ): ToolDefinition => ({
    id,
    name,
    description,
    params,
    permissions: [],
    confirmation,
    context: 'app',
    timeout_ms: 10_000,
  });
  const str = (name: string, required: boolean): ToolDefinition['params'][number] => ({
    name,
    type: 'string',
    required,
  });

  return [
    def('time.now', 'Hora atual', 'Data e hora do dispositivo.', [], 'none'),
    def('device.battery', 'Bateria', 'Nível e estado da bateria.', [], 'none'),
    def(
      'apps.list',
      'Listar apps',
      'Lista aplicativos (mock web: lista fixa).',
      [str('query', false)],
      'none',
    ),
    def('apps.open', 'Abrir app', 'Abre um aplicativo pelo nome.', [str('app', true)], 'none'),
    def(
      'notes.create',
      'Criar nota',
      'Cria uma nota local (localStorage no web).',
      [str('title', true), str('body', true)],
      'simple',
    ),
    def(
      'web.search',
      'Pesquisar web',
      'Abre o navegador com a pesquisa.',
      [str('query', true)],
      'none',
    ),
  ];
}

function mockInvoke(toolId: string, params: Record<string, unknown>): ToolOutcome {
  const ok = (data: unknown): ToolOutcome => ({ status: 'ok', tool_id: toolId, data });
  switch (toolId) {
    case 'time.now':
      return ok({ iso: new Date().toISOString(), tz: Intl.DateTimeFormat().resolvedOptions().timeZone });
    case 'device.battery':
      return ok({ levelPct: 80, charging: false, saver: false, simulated: true });
    case 'apps.list':
      return ok({
        apps: ['Geny Assistant', 'Câmera', 'Navegador', 'Calculadora'],
        query: params['query'] ?? null,
        simulated: true,
      });
    case 'apps.open':
      return ok({ opened: params['app'] ?? null, simulated: true });
    case 'notes.create': {
      const notes = JSON.parse(localStorage.getItem('geny.notes') ?? '[]') as unknown[];
      notes.push({ title: params['title'], body: params['body'], at: Date.now() });
      localStorage.setItem('geny.notes', JSON.stringify(notes));
      return ok({ created: true, total: notes.length });
    }
    case 'web.search':
      window.open(
        `https://duckduckgo.com/?q=${encodeURIComponent(String(params['query'] ?? ''))}`,
        '_blank',
        'noopener',
      );
      return ok({ opened: 'browser' });
    default:
      return { status: 'failed', tool_id: toolId, error: 'mock web: ferramenta indisponível' };
  }
}

function createWebMockBridge(): GenyBridge {
  return {
    async listTools() {
      return { tools: webCatalog() };
    },
    async invokeTool({ toolId, paramsJson }) {
      const params = JSON.parse(paramsJson) as Record<string, unknown>;
      return { outcomeJson: JSON.stringify(mockInvoke(toolId, params)) };
    },
    async requestConfirmation({ toolId, level, summary }) {
      if (confirmationHandler) {
        return { approved: await confirmationHandler(toolId, level, summary) };
      }
      return { approved: window.confirm(summary) };
    },
    async getDeviceContext() {
      const ctx: DeviceContext = {
        online: navigator.onLine,
        batteryPct: 80,
        batterySaver: false,
        thermalHigh: false,
        rootAvailable: false,
        locale: navigator.language,
      };
      return { json: JSON.stringify(ctx) };
    },
  };
}

// ------------------------------------------------------------------ export --

const nativeBridge = registerPlugin<GenyBridge>('GenyBridge');

/** Ponte ativa: nativa no Android, mock no navegador. */
export const bridge: GenyBridge = Capacitor.isNativePlatform()
  ? nativeBridge
  : createWebMockBridge();
