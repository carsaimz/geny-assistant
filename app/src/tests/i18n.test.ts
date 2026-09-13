import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { isLocaleCode, LOCALES, localeInfo, t, setLocale } from '../i18n';
import { tryParseToolCall } from '../core/remote';

const LOCALES_DIR = join(__dirname, '../i18n/locales');

describe('i18n multilíngue por design', () => {
  it('contém os 10 idiomas obrigatórios + pt-PT', () => {
    const codes = LOCALES.map((l) => l.code);
    for (const c of [
      'pt-BR',
      'pt-PT',
      'en',
      'es',
      'fr',
      'de',
      'it',
      'ru',
      'zh-CN',
      'ja',
      'ar',
    ]) {
      expect(codes).toContain(c);
    }
    expect(LOCALES.length).toBeGreaterThanOrEqual(11);
  });

  it('marca árabe como RTL e as demais como LTR', () => {
    expect(localeInfo('ar').rtl).toBe(true);
    expect(localeInfo('pt-BR').rtl).toBe(false);
    expect(localeInfo('ja').rtl).toBe(false);
  });

  it('traduz e faz fallback para inglês', () => {
    setLocale('pt-BR');
    expect(t('settings.save')).toBe('Salvar');
    setLocale('es');
    expect(t('settings.save')).toBe('Guardar');
    setLocale('zz-XY'); // inválido → fallback en
    expect(isLocaleCode('zz-XY')).toBe(false);
    expect(t('settings.save')).toBe('Save');
  });
});

describe('integridade dos locales (regressão)', () => {
  const files = readdirSync(LOCALES_DIR).filter((f) => f.endsWith('.json'));

  it('todos os locales têm exatamente o mesmo conjunto de chaves', () => {
    const keySets = files.map((f) => {
      const json = JSON.parse(readFileSync(join(LOCALES_DIR, f), 'utf8')) as Record<
        string,
        string
      >;
      return { f, keys: Object.keys(json).sort() };
    });
    const reference = keySets[0]!.keys;
    for (const { f, keys } of keySets.slice(1)) {
      expect(keys, `${f} diverge de ${keySets[0]!.f}`).toEqual(reference);
    }
  });

  it('toda chave usada no código existe nos locales (sem chave crua na UI)', () => {
    const localeKeys = new Set(
      Object.keys(JSON.parse(readFileSync(join(LOCALES_DIR, 'pt-BR.json'), 'utf8'))),
    );
    // Chaves t('...') têm sempre o formato segmento.segmento — o filtro evita
    // falsos positivos de literais de teste sem ponto.
    const used = new Set<string>();
    for (const f of ['../main.ts', '../ui/chat.ts', '../ui/settings.ts']) {
      const src = readFileSync(join(__dirname, f), 'utf8');
      for (const m of src.matchAll(/\bt\('([a-z]+[a-zA-Z0-9]*(?:\.[a-zA-Z0-9]+)+)'\)/g)) {
        used.add(m[1]!);
      }
    }
    expect(used.size).toBeGreaterThan(5);
    for (const key of used) {
      expect(localeKeys.has(key), `chave ausente no locale: ${key}`).toBe(true);
    }
  });
});

describe('guarda anti-ecrã-preto (regressão v0.1.0-alpha.2)', () => {
  it('[hidden] vence qualquer display de autor no style.css', () => {
    // Causa raiz do ecrã preto: #settings-drawer { display: flex } sobrepunha
    // o display:none da folha UA para [hidden], tapando o app inteiro.
    const css = readFileSync(join(__dirname, '../../src/style.css'), 'utf8');
    expect(css).toMatch(/\[hidden\]\s*\{[^}]*display:\s*none\s*!important/);
  });
});

describe('parser de tool call do backend remoto', () => {
  it('extrai JSON de tool call dentro de texto', () => {
    const content = 'Claro! {"tool": "apps.open", "params": {"app": "camera"}}';
    const intent = tryParseToolCall(content);
    expect(intent?.toolId).toBe('apps.open');
    expect(intent?.params['app']).toBe('camera');
  });

  it('retorna null para texto puro', () => {
    expect(tryParseToolCall('olá, tudo bem?')).toBeNull();
    expect(tryParseToolCall('{"foo": 1}')).toBeNull();
    expect(tryParseToolCall('')).toBeNull();
  });
});
