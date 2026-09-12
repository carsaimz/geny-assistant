/**
 * Tipos compartilhados entre a camada web, o núcleo Rust (geny-core) e a
 * ponte nativa Kotlin. Mantidos em sincronia manual — ver docs/tool-calling.md.
 */

export type ConfirmationLevel = 'none' | 'simple' | 'explicit' | 'authenticated';

export type ToolContext = 'app' | 'service' | 'root';

export type BackendMode = 'local' | 'remote' | 'selfhosted';

export type ParamTypeName =
  | 'string'
  | 'number'
  | 'integer'
  | 'boolean'
  | 'array'
  | 'object';

export interface ParamSpec {
  name: string;
  type: ParamTypeName;
  required?: boolean;
  description?: string;
  allowed_values?: string[];
}

/** Espelha `core/src/tools/registry.rs::ToolDefinition`. */
export interface ToolDefinition {
  id: string;
  name: string;
  description: string;
  params: ParamSpec[];
  permissions: string[];
  confirmation: ConfirmationLevel;
  context: ToolContext;
  timeout_ms: number;
}

/** Espelha `core/src/orchestrator.rs::ToolOutcome`. */
export interface ToolOutcome {
  status: 'ok' | 'denied' | 'failed';
  tool_id: string;
  data?: unknown;
  reason?: string;
  error?: string;
}

/** Contexto do dispositivo vindo da ponte nativa. */
export interface DeviceContext {
  online: boolean;
  batteryPct: number;
  batterySaver: boolean;
  thermalHigh: boolean;
  rootAvailable: boolean;
  locale: string;
}

/** Configurações do usuário (armazenamento local; chave API em Keystore no nativo). */
export interface Settings {
  mode: BackendMode;
  language: string;
  model: string;
  baseUrl: string;
  apiKeySet: boolean;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'tool';
  content: string;
  at: number;
  tool?: ToolOutcome;
}

/** Intenção detectada offline pelo roteador local (sem LLM). */
export interface ToolIntent {
  toolId: string;
  params: Record<string, unknown>;
}

/** Lista de ferramentas do catálogo web (mock sem root). */
export const WEB_CATALOG_IDS = [
  'time.now',
  'device.battery',
  'apps.list',
  'apps.open',
  'notes.create',
  'reminders.set',
  'web.search',
] as const;
