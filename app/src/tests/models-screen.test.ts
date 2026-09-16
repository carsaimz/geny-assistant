/**
 * Tela nativa de Modelos (Fase 3, TODO android-03 / issue #35).
 *
 * **PT** Contrato do lado web: o botão "Abrir tela nativa de modelos" existe
 * no drawer de configurações, a ponte expõe `openModelsScreen` (mock web
 * resolve sem fazer nada) e TODOS os locales têm a chave da UI — regressão
 * contra chave ausente em algum dos 11 idiomas.
 * **EN** Web side contract: the "Open native models screen" button exists in
 * the settings drawer, the bridge exposes `openModelsScreen` (web mock
 * resolves as a no-op) and ALL locales carry the UI key — regression guard
 * against a missing key in any of the 11 languages.
 */
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { bridge } from '../core/bridge';

const LOCALES_DIR = join(__dirname, '../i18n/locales');
const SETTINGS_TS = join(__dirname, '../ui/settings.ts');

describe('tela nativa de modelos — contrato web', () => {
  it('mock web resolve openModelsScreen (no-op honesto)', async () => {
    await expect(bridge.openModelsScreen()).resolves.toBeUndefined();
  });

  it('drawer de configurações tem o botão escondido por padrão', async () => {
    const source = await readFileSync(SETTINGS_TS, 'utf-8');
    expect(source).toContain('id="open-models-screen"');
    expect(source).toContain('settings.model.nativeScreen');
    // O botão só aparece na plataforma nativa.
    expect(source).toContain('Capacitor.isNativePlatform()');
  });

  it('todos os locales têm settings.model.nativeScreen', () => {
    const files = readdirSync(LOCALES_DIR).filter((f) => f.endsWith('.json'));
    expect(files.length).toBeGreaterThanOrEqual(11);
    for (const file of files) {
      const data = JSON.parse(readFileSync(join(LOCALES_DIR, file), 'utf-8')) as Record<string, string>;
      const value = data['settings.model.nativeScreen'];
      expect(value, `locale ${file} sem settings.model.nativeScreen`).toBeTypeOf('string');
      expect(value as string, `locale ${file} com chave vazia`).not.toHaveLength(0);
    }
  });
});
