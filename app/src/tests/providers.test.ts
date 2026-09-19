/**
 * Espelho TS do catálogo de provedores e perfis de operação (Fase 6,
 * TODO core-10 / issue #50).
 *
 * **PT** A fonte da verdade é o Rust (`core/src/providers.rs`, exposto ao
 * Kotlin via UniFFI); estes testes travam a paridade do espelho TS — ids,
 * tiers, URLs base e as regras puras dos perfis.
 * **EN** The source of truth is the Rust core (`core/src/providers.rs`,
 * exposed to Kotlin via UniFFI); these tests lock the TS mirror parity —
 * ids, tiers, base URLs and the pure profile rules.
 */
import { describe, expect, it } from 'vitest';
import {
  CUSTOM_PROVIDER,
  PROVIDER_PRESETS,
  effectiveProvider,
  providerById,
  suggestModeForProfile,
} from '../core/providers';

describe('providers — catálogo (espelho do core Rust)', () => {
  it('ids batem com o catálogo do geny-core (providers.rs)', () => {
    // Mesma ordem da constante PROVIDERS no Rust — mudou lá, muda aqui.
    expect(PROVIDER_PRESETS.map((p) => p.id)).toEqual([
      'openrouter',
      'groq',
      'cerebras',
      'mistral',
      'openai',
      'ollama',
      'lm-studio',
      'vllm',
      'llama-cpp',
    ]);
  });

  it('self-hosted local dispensa chave; nuvem exige', () => {
    for (const p of PROVIDER_PRESETS.filter((x) => x.tier === 'self-hosted')) {
      expect(p.requiresKey, p.id).toBe(false);
      expect(p.baseUrl.startsWith('http://localhost'), p.id).toBe(true);
    }
    for (const p of PROVIDER_PRESETS.filter((x) => x.tier !== 'self-hosted')) {
      expect(p.requiresKey, p.id).toBe(true);
    }
  });

  it('providerById acha presets e o custom; desconhecido vira custom', () => {
    expect(providerById('groq')?.baseUrl).toBe('https://api.groq.com/openai/v1');
    expect(providerById('custom')).toEqual(CUSTOM_PROVIDER);
    expect(providerById('inexistente')).toBeNull();
    expect(effectiveProvider(undefined)).toEqual(CUSTOM_PROVIDER);
    expect(effectiveProvider('quebrado')).toEqual(CUSTOM_PROVIDER);
  });
});

describe('perfis de operação — regras puras (mesma semântica do Rust)', () => {
  const base = {
    online: true,
    localReady: true,
    premiumReady: true,
    selfhostedReady: false,
  };

  it('default devolve null (o chamador usa o pickBackend legado)', () => {
    expect(suggestModeForProfile({ profile: 'default', ...base })).toBeNull();
  });

  it('offline-total nunca fala com a rede', () => {
    expect(suggestModeForProfile({ profile: 'offline-total', ...base })).toBe('local');
    expect(suggestModeForProfile({ profile: 'offline-total', ...base, localReady: false })).toBe('offline');
    expect(
      suggestModeForProfile({ profile: 'offline-total', ...base, selfhostedReady: true }),
    ).toBe('local');
  });

  it('home-server ignora a nuvem premium', () => {
    expect(suggestModeForProfile({ profile: 'home-server', ...base })).toBe('local');
    expect(
      suggestModeForProfile({ profile: 'home-server', ...base, selfhostedReady: true }),
    ).toBe('remote');
    expect(
      suggestModeForProfile({ profile: 'home-server', ...base, localReady: false }),
    ).toBe('offline');
  });

  it('híbrido espelha o auto clássico', () => {
    expect(suggestModeForProfile({ profile: 'hybrid', ...base })).toBe('remote');
    expect(suggestModeForProfile({ profile: 'hybrid', ...base, online: false })).toBe('local');
    expect(
      suggestModeForProfile({ profile: 'hybrid', ...base, localReady: false, premiumReady: false }),
    ).toBe('offline');
  });
});
