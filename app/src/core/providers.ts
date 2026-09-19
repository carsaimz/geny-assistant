/**
 * Espelho TS do catálogo de provedores e perfis de operação (Fase 6,
 * TODO core-10) — fonte da verdade: `core/src/providers.rs` no geny-core
 * (mesma lista, mesmos códigos, mesmas regras via UniFFI).
 *
 * **PT** A UI usa os presets para preencher a base URL e mostrar o nível
 * (gratuito/free-tier/premium/self-hosted); o chat usa os perfis para
 * restringir o modo `auto`. A chave de API por provedor vive no Keystore
 * via ponte (TODO android-09) — nunca neste módulo.
 * **EN** The UI uses presets to fill the base URL and show the tier
 * (free/free-tier/premium/self-hosted); the chat uses profiles to constrain
 * the `auto` mode. The per-provider API key lives in the Keystore via the
 * bridge (TODO android-09) — never in this module.
 */

export type ProviderTier = 'free' | 'free-tier' | 'premium' | 'self-hosted';

export interface ProviderPreset {
  id: string;
  label: string;
  tier: ProviderTier;
  baseUrl: string;
  requiresKey: boolean;
}

/** Mesma lista de `PROVIDERS` no Rust (providers.rs) — paridade testada. */
export const PROVIDER_PRESETS: ProviderPreset[] = [
  { id: 'openrouter', label: 'OpenRouter', tier: 'free-tier', baseUrl: 'https://openrouter.ai/api/v1', requiresKey: true },
  { id: 'groq', label: 'Groq', tier: 'free-tier', baseUrl: 'https://api.groq.com/openai/v1', requiresKey: true },
  { id: 'cerebras', label: 'Cerebras', tier: 'free-tier', baseUrl: 'https://api.cerebras.ai/v1', requiresKey: true },
  { id: 'mistral', label: 'Mistral AI', tier: 'free-tier', baseUrl: 'https://api.mistral.ai/v1', requiresKey: true },
  { id: 'openai', label: 'OpenAI', tier: 'premium', baseUrl: 'https://api.openai.com/v1', requiresKey: true },
  { id: 'ollama', label: 'Ollama', tier: 'self-hosted', baseUrl: 'http://localhost:11434/v1', requiresKey: false },
  { id: 'lm-studio', label: 'LM Studio', tier: 'self-hosted', baseUrl: 'http://localhost:1234/v1', requiresKey: false },
  { id: 'vllm', label: 'vLLM', tier: 'self-hosted', baseUrl: 'http://localhost:8000/v1', requiresKey: false },
  { id: 'llama-cpp', label: 'llama.cpp server', tier: 'self-hosted', baseUrl: 'http://localhost:8080/v1', requiresKey: false },
];

/** Entrada "custom": base URL e modelo manuais, fora do catálogo. */
export const CUSTOM_PROVIDER: ProviderPreset = {
  id: 'custom',
  label: 'Custom',
  tier: 'premium',
  baseUrl: '',
  requiresKey: true,
};

export function providerById(id: string): ProviderPreset | null {
  if (id === CUSTOM_PROVIDER.id) return CUSTOM_PROVIDER;
  return PROVIDER_PRESETS.find((p) => p.id === id) ?? null;
}

/** Resolves o preset efetivo das configurações (default: custom). */
export function effectiveProvider(providerId: string | undefined): ProviderPreset {
  return providerById(providerId ?? 'custom') ?? CUSTOM_PROVIDER;
}

// ---------------------------------------------------------- perfis (Fase 6) --

/**
 * Perfis de operação (docs §7.6). `default` é o comportamento legado do
 * `auto` (pickBackend com bateria/rede); os outros 3 espelham o Rust.
 */
export type OperationProfileCode = 'default' | 'offline-total' | 'hybrid' | 'home-server';

export const OPERATION_PROFILES: OperationProfileCode[] = [
  'default',
  'offline-total',
  'hybrid',
  'home-server',
];

export interface ProfileDecisionInput {
  profile: OperationProfileCode;
  online: boolean;
  /** Modelo .gguf escolhido (settings.localModel). */
  localReady: boolean;
  /** Remoto configurado e NÃO self-hosted (nuvem de terceiros). */
  premiumReady: boolean;
  /** Remoto configurado e self-hosted (servidor do usuário). */
  selfhostedReady: boolean;
}

export type SuggestedMode = 'remote' | 'local' | 'offline';

/**
 * Regras puras por perfil — MESMA semântica de `suggest_mode` no Rust
 * (providers.rs). `default` devolve `null`: o chamador usa o `pickBackend`
 * legado (com bateria). Bateria/economia/thermal ficam no chamador.
 */
export function suggestModeForProfile(input: ProfileDecisionInput): SuggestedMode | null {
  if (input.profile === 'default') return null;
  switch (input.profile) {
    case 'offline-total':
      // Nunca fala com a rede — nem com o servidor de casa remoto.
      return input.localReady ? 'local' : 'offline';
    case 'home-server':
      // Só o servidor do próprio usuário; nuvem premium NUNCA.
      if (input.selfhostedReady) return 'remote';
      return input.localReady ? 'local' : 'offline';
    case 'hybrid':
      if (input.online && (input.premiumReady || input.selfhostedReady)) return 'remote';
      return input.localReady ? 'local' : 'offline';
  }
}
