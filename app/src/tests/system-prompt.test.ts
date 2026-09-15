/**
 * Prompt de sistema por idioma/cultura (TODO Fase 3).
 *
 * **PT** `buildSystemPrompt` espelha o design canônico do core Rust
 * (core/src/i18n.rs — `Language::from_code`, `culture_notes` e
 * `system_prompt`): mesmas 5 regras + privacidade, nota de cultura no
 * idioma de destino e catálogo de ferramentas como JSON. É a fonte única
 * para os backends remoto e local — antes cada camada tinha um prompt
 * artesanal divergente.
 * **EN** `buildSystemPrompt` mirrors the canonical Rust core design
 * (core/src/i18n.rs): same 5 rules + privacy, destination-language culture
 * note and tool catalog as JSON. Single source for remote and local
 * backends — previously each layer had a divergent hand-rolled prompt.
 */
import { describe, expect, it } from 'vitest';
import { buildSystemPrompt, resolveLanguage } from '../core/system-prompt';

describe('resolveLanguage — mesma semântica de Language::from_code (Rust)', () => {
  it('pt genérico → pt-BR; pt-PT → Portugal', () => {
    expect(resolveLanguage('pt').code).toBe('pt-BR');
    expect(resolveLanguage('pt-BR').code).toBe('pt-BR');
    expect(resolveLanguage('pt-PT').code).toBe('pt-PT');
    expect(resolveLanguage('pt_PT').code).toBe('pt-PT');
  });

  it('idiomas principais resolvem para o código canônico', () => {
    expect(resolveLanguage('en').code).toBe('en');
    expect(resolveLanguage('es').code).toBe('es');
    expect(resolveLanguage('fr').code).toBe('fr');
    expect(resolveLanguage('de').code).toBe('de');
    expect(resolveLanguage('it').code).toBe('it');
    expect(resolveLanguage('ru').code).toBe('ru');
    expect(resolveLanguage('zh').code).toBe('zh-CN');
    expect(resolveLanguage('zh-CN').code).toBe('zh-CN');
    expect(resolveLanguage('ja').code).toBe('ja');
    expect(resolveLanguage('ar').code).toBe('ar');
  });

  it('desconhecido/vazio → inglês (fallback como no core)', () => {
    expect(resolveLanguage('klingon').code).toBe('en');
    expect(resolveLanguage('').code).toBe('en');
  });
});

describe('buildSystemPrompt — espelho do i18n::system_prompt', () => {
  it('contém as 5 regras fundamentais + privacidade (padrão ligada)', () => {
    const p = buildSystemPrompt({ language: 'pt-BR' });
    expect(p).toContain('Geny Assistant');
    // regra 1: JSON de tool call
    expect(p).toContain('"tool": "<id>"');
    // regra 2: nunca inventar
    expect(p).toContain('NUNCA invente ferramentas');
    // regra 4: idioma + cultura
    expect(p).toContain('idioma padrao: pt-BR');
    expect(p).toContain('portugues do Brasil, tom acolhedor e direto');
    // regra 5: perguntar antes de agir
    expect(p).toContain('pergunte antes de agir');
    // regra 6: privacidade local-first
    expect(p).toContain('nada sai do dispositivo');
  });

  it('privacy: false omite a regra 6', () => {
    const p = buildSystemPrompt({ language: 'en', privacy: false });
    expect(p).not.toContain('nada sai do dispositivo');
    // nota de cultura em inglês
    expect(p).toContain('neutral international English');
  });

  it('nota de cultura acompanha cada idioma (amostra)', () => {
    expect(buildSystemPrompt({ language: 'ja' })).toContain('丁寧で自然な日本語');
    expect(buildSystemPrompt({ language: 'ar' })).toContain('العربية الفصحى');
    expect(buildSystemPrompt({ language: 'ru' })).toContain('нейтральный вежливый русский');
    expect(buildSystemPrompt({ language: 'zh-CN' })).toContain('简体中文');
  });

  it('catálogo de ferramentas entra como JSON quando fornecido', () => {
    const catalog = JSON.stringify([{ id: 'time.now' }, { id: 'device.battery' }]);
    const p = buildSystemPrompt({ language: 'en', toolCatalogJson: catalog });
    expect(p).toContain('Catalogo de ferramentas registradas (JSON):');
    expect(p).toContain('"time.now"');
    expect(p).toContain('"device.battery"');
  });

  it('sem catálogo não inclui a seção de ferramentas', () => {
    const p = buildSystemPrompt({ language: 'en' });
    expect(p).not.toContain('Catalogo de ferramentas registradas');
  });
});
