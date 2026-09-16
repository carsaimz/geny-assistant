/**
 * Seleção automática de backend (TODO Fase 3 — "local/remoto conforme
 * bateria, rede e tarefa").
 *
 * **PT** Decisão pura e testável: no modo `auto` a Geny prefere o backend
 * remoto quando há rede, chave configurada e bateria saudável; caso
 * contrário cai para o modelo local (se houver arquivo) e por fim para o
 * roteador de intenções offline. `batteryPct <= 0` é tratado como
 * "desconhecido" (o nativo devolve 0 quando não consegue ler) e não bloqueia
 * o remoto — o mesmo vale para `thermalHigh` ainda não instrumentado.
 * **EN** Pure, testable decision: in `auto` mode Geny prefers the remote
 * backend when there is network, a configured key and healthy battery;
 * otherwise it falls back to the local model (when a file is set) and
 * finally to the offline intent router. `batteryPct <= 0` is treated as
 * "unknown" (the native side returns 0 when it cannot read) and does not
 * block the remote path — same for `thermalHigh`, not yet instrumented.
 */
import type { BackendMode } from '../types';

export type PickedBackend = 'remote' | 'local' | 'offline';

/** Bateria considerada baixa — evita inferência pesada/tokens remotos. */
export const LOW_BATTERY_PCT = 15;

export interface BackendContext {
  mode: BackendMode;
  /** Há backend remoto configurado (baseUrl + model)? */
  remoteReady: boolean;
  online: boolean;
  /** 0..100; <= 0 significa desconhecido (não bloqueia). */
  batteryPct: number;
  batterySaver: boolean;
  thermalHigh: boolean;
  /** Arquivo .gguf escolhido nas configurações (settings.localModel). */
  localModelFile: string;
}

/** Bateria/rede permitem o backend remoto? (usado no modo `auto`). */
export function remoteAllowedByPower(ctx: Pick<BackendContext, 'online' | 'batteryPct' | 'batterySaver' | 'thermalHigh'>): boolean {
  if (!ctx.online) return false;
  if (ctx.batterySaver || ctx.thermalHigh) return false;
  const batteryUnknown = ctx.batteryPct <= 0;
  return batteryUnknown || ctx.batteryPct > LOW_BATTERY_PCT;
}

/**
 * Escolhe o backend para este turno do chat — nunca lança; qualquer dúvida
 * degrada para `offline` (intenções locais sempre funcionam).
 */
export function pickBackend(ctx: BackendContext): PickedBackend {
  switch (ctx.mode) {
    case 'remote':
    case 'selfhosted':
      return ctx.remoteReady ? 'remote' : 'offline';
    case 'local':
      return ctx.localModelFile.length > 0 ? 'local' : 'offline';
    case 'auto':
      if (ctx.remoteReady && remoteAllowedByPower(ctx)) return 'remote';
      if (ctx.localModelFile.length > 0) return 'local';
      return 'offline';
  }
}
