/**
 * Contrato do wake word (Fase 3, TODO android-03b).
 *
 * **PT** O mock web precisa cumprir o MESMO contrato do nativo: status
 * honesto ({ enabled: false, ready: false }) com desligado por padrão,
 * `setWakeWordEnabled` recusando com erro claro no navegador e a chave
 * `settings.wake.*` presente nos 11 locales (a UI usa `t()` direto).
 * **EN** The web mock must honor the SAME contract as native: honest status
 * ({ enabled: false, ready: false }) with off-by-default, `setWakeWordEnabled`
 * refusing with a clear error in the browser and the `settings.wake.*` key
 * present in all 11 locales (the UI calls `t()` directly).
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { bridge } from '../core/bridge';
import { LOCALES } from '../i18n';

describe('contrato do wake word — mock web', () => {
  it('status default é desligado e honesto', async () => {
    const { json } = await bridge.getWakeWordStatus();
    const status = JSON.parse(json) as {
      enabled: boolean;
      ready: boolean;
      modelId: string;
      models: unknown[];
    };
    expect(status.enabled).toBe(false);
    expect(status.ready).toBe(false);
    expect(status.modelId.length).toBeGreaterThan(0);
    expect(Array.isArray(status.models)).toBe(true);
  });

  it('ativar no navegador falha com erro claro (nunca silencioso)', async () => {
    const res = await bridge.setWakeWordEnabled({ enabled: true });
    expect(res.ok).toBe(false);
    expect(res.error).toBe('unavailable_on_web');
  });

  it('chave settings.wake.* presente nos 11 locales com paridade', () => {
    const dir = join(__dirname, '../i18n/locales');
    const files = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(files.length).toBe(LOCALES.length);
    const base = JSON.parse(
      readFileSync(join(dir, 'pt-BR.json'), 'utf8'),
    ) as Record<string, string>;
    const wakeKeys = Object.keys(base).filter((k) => k.startsWith('settings.wake.'));
    expect(wakeKeys.length).toBeGreaterThanOrEqual(7);
    for (const f of files) {
      const data = JSON.parse(readFileSync(join(dir, f), 'utf8')) as Record<string, string>;
      for (const k of wakeKeys) {
        expect(data[k]).toBeDefined();
        expect(data[k]?.length ?? 0).toBeGreaterThan(0);
      }
    }
  });
});
