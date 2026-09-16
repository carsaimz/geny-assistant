/**
 * Catálogo de ferramentas na UI (Fase 4, TODO app-03 / issue #44).
 *
 * **PT** Contrato do lado web: o drawer de configurações tem a seção do
 * catálogo (nome, descrição, parâmetros) com o selo do nível de confirmação
 * de cada ferramenta; TODOS os locales trazem as chaves; o mock web expõe
 * o catálogo com níveis válidos.
 * **EN** Web side contract: the settings drawer carries the tool catalog
 * section (name, description, parameters) with each tool's confirmation
 * level badge; ALL locales carry the keys; the web mock serves the catalog
 * with valid levels.
 */
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { bridge } from '../core/bridge';
import { confirmationBadge, CONFIRMATION_LEVEL_CLASS } from '../ui/settings';

const LOCALES_DIR = join(__dirname, '../i18n/locales');
const SETTINGS_TS = join(__dirname, '../ui/settings.ts');

const LEVELS = ['none', 'simple', 'explicit', 'authenticated'] as const;
const CATALOG_KEYS = [
  'settings.tools.title',
  'settings.tools.count',
  'settings.tools.level.none',
  'settings.tools.level.simple',
  'settings.tools.level.explicit',
  'settings.tools.level.authenticated',
];

describe('catálogo de ferramentas — contrato web', () => {
  it('mock web expõe catálogo com níveis de confirmação válidos', async () => {
    const { tools } = await bridge.listTools();
    expect(tools.length).toBeGreaterThanOrEqual(5);
    for (const tool of tools) {
      expect(LEVELS).toContain(tool.confirmation);
      expect(tool.name.length).toBeGreaterThan(0);
      expect(tool.description.length).toBeGreaterThan(0);
    }
    // pelo menos um nível simples e um explícito para o selo cobrir variações
    expect(tools.some((tool) => tool.confirmation === 'simple')).toBe(true);
    expect(tools.some((tool) => tool.confirmation === 'explicit')).toBe(true);
  });

  it('drawer tem a seção do catálogo com selos por nível', async () => {
    const source = await readFileSync(SETTINGS_TS, 'utf-8');
    expect(source).toContain('id="tools-catalog"');
    expect(source).toContain('settings.tools.title');
    expect(source).toContain('confirmationBadge(');
    for (const level of LEVELS) {
      expect(source).toContain(`level-${level}`);
    }
  });

  it('todos os locales têm as 6 chaves do catálogo', () => {
    const files = readdirSync(LOCALES_DIR).filter((f) => f.endsWith('.json'));
    expect(files.length).toBeGreaterThanOrEqual(11);
    for (const file of files) {
      const data = JSON.parse(readFileSync(join(LOCALES_DIR, file), 'utf-8')) as Record<string, string>;
      for (const key of CATALOG_KEYS) {
        const value = data[key];
        expect(value, `locale ${file} sem ${key}`).toBeTypeOf('string');
        expect(value as string, `locale ${file} com ${key} vazia`).not.toHaveLength(0);
      }
    }
  });

  it('selo de confirmação mapeia nível → classe e rótulo', () => {
    expect(CONFIRMATION_LEVEL_CLASS.none).toBe('level-none');
    expect(CONFIRMATION_LEVEL_CLASS.simple).toBe('level-simple');
    expect(CONFIRMATION_LEVEL_CLASS.explicit).toBe('level-explicit');
    expect(CONFIRMATION_LEVEL_CLASS.authenticated).toBe('level-authenticated');

    for (const level of LEVELS) {
      const badge = confirmationBadge(level);
      expect(badge).toContain(`tool-badge level-${level}`);
      // rótulo do locale atual (não vazio e não a chave crua)
      const label = badge.replace(/<[^>]+>/g, '');
      expect(label.trim().length).toBeGreaterThan(0);
      expect(label).not.toContain('settings.tools');
    }
  });
});
