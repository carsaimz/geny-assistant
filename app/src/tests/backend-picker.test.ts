/**
 * Seleção automática de backend (TODO Fase 3 — bateria, rede e configuração).
 *
 * **PT** `pickBackend` é puro e decide o backend por turno: no modo `auto`
 * prefere remoto (online + chave + bateria saudável), cai para o modelo
 * local quando offline/bateria baixa e termina nas intenções offline.
 * Bateria desconhecida (<= 0, como o nativo devolve) não bloqueia o remoto.
 * **EN** `pickBackend` is pure and decides the backend per turn: in `auto`
 * mode it prefers remote (online + key + healthy battery), falls back to the
 * local model when offline/low battery and ends at offline intents.
 * Unknown battery (<= 0, as the native side returns) does not block remote.
 */
import { describe, expect, it } from 'vitest';
import { LOW_BATTERY_PCT, pickBackend, remoteAllowedByPower } from '../core/backend-picker';

function base(overrides: Partial<Parameters<typeof pickBackend>[0]> = {}): Parameters<typeof pickBackend>[0] {
  return {
    mode: 'auto',
    remoteReady: true,
    online: true,
    batteryPct: 80,
    batterySaver: false,
    thermalHigh: false,
    localModelFile: 'modelo.gguf',
    ...overrides,
  };
}

describe('remoteAllowedByPower — regra de bateria/rede', () => {
  it('online e bateria saudável → remoto permitido', () => {
    expect(remoteAllowedByPower({ online: true, batteryPct: 80, batterySaver: false, thermalHigh: false })).toBe(true);
  });

  it('offline, poupança de bateria ou térmico alto bloqueiam o remoto', () => {
    expect(remoteAllowedByPower({ online: false, batteryPct: 80, batterySaver: false, thermalHigh: false })).toBe(false);
    expect(remoteAllowedByPower({ online: true, batteryPct: 80, batterySaver: true, thermalHigh: false })).toBe(false);
    expect(remoteAllowedByPower({ online: true, batteryPct: 80, batterySaver: false, thermalHigh: true })).toBe(false);
  });

  it(`bateria <= ${LOW_BATTERY_PCT}% bloqueia; desconhecida (<=0) não bloqueia`, () => {
    expect(remoteAllowedByPower({ online: true, batteryPct: 15, batterySaver: false, thermalHigh: false })).toBe(false);
    expect(remoteAllowedByPower({ online: true, batteryPct: 14, batterySaver: false, thermalHigh: false })).toBe(false);
    expect(remoteAllowedByPower({ online: true, batteryPct: 16, batterySaver: false, thermalHigh: false })).toBe(true);
    // nativo devolve 0 quando não lê a bateria — não deve punir o usuário
    expect(remoteAllowedByPower({ online: true, batteryPct: 0, batterySaver: false, thermalHigh: false })).toBe(true);
    expect(remoteAllowedByPower({ online: true, batteryPct: -1, batterySaver: false, thermalHigh: false })).toBe(true);
  });
});

describe('pickBackend — modo auto', () => {
  it('remoto pronto + online + bateria ok → remote', () => {
    expect(pickBackend(base())).toBe('remote');
  });

  it('sem rede → local (se houver arquivo) e depois offline', () => {
    expect(pickBackend(base({ online: false }))).toBe('local');
    expect(pickBackend(base({ online: false, localModelFile: '' }))).toBe('offline');
  });

  it('bateria baixa / poupança → local, mesmo com rede', () => {
    expect(pickBackend(base({ batteryPct: 10 }))).toBe('local');
    expect(pickBackend(base({ batterySaver: true }))).toBe('local');
  });

  it('bateria desconhecida (0) mantém o remoto', () => {
    expect(pickBackend(base({ batteryPct: 0 }))).toBe('remote');
  });

  it('sem remoto configurado → local/offline', () => {
    expect(pickBackend(base({ remoteReady: false }))).toBe('local');
    expect(pickBackend(base({ remoteReady: false, localModelFile: '' }))).toBe('offline');
  });

  it('térmico alto → local', () => {
    expect(pickBackend(base({ thermalHigh: true }))).toBe('local');
  });
});

describe('pickBackend — modos explícitos preservam o comportamento', () => {
  it('local: usa o modelo local se houver arquivo; offline sem arquivo', () => {
    expect(pickBackend(base({ mode: 'local', online: false, remoteReady: true }))).toBe('local');
    expect(pickBackend(base({ mode: 'local', localModelFile: '' }))).toBe('offline');
    // modo local explícito ignora bateria/rede (decisão do usuário prevalece)
    expect(pickBackend(base({ mode: 'local', batteryPct: 5 }))).toBe('local');
  });

  it('remote/selfhosted: remoto se configurado; offline sem configuração', () => {
    expect(pickBackend(base({ mode: 'remote', online: false }))).toBe('remote');
    expect(pickBackend(base({ mode: 'selfhosted' }))).toBe('remote');
    expect(pickBackend(base({ mode: 'remote', remoteReady: false }))).toBe('offline');
    expect(pickBackend(base({ mode: 'selfhosted', remoteReady: false }))).toBe('offline');
  });
});
