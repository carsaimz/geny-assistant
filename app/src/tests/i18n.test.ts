import { describe, expect, it } from 'vitest';
import { isLocaleCode, LOCALES, localeInfo, t, setLocale } from '../i18n';
import { tryParseToolCall } from '../core/remote';

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
