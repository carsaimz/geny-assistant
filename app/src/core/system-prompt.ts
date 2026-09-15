/**
 * Prompt de sistema por idioma e cultura — fonte única para os backends
 * remoto e local (TODO Fase 3 "Prompt de sistema por idioma/cultura").
 *
 * **PT** Espelha o design canônico do core Rust (core/src/i18n.rs:
 * `Language::culture_notes` + `system_prompt`) para que remote (OpenAI-compat)
 * e local (llama.cpp via ponte) recebam exatamente as mesmas regras — antes,
 * cada camada tinha um prompt artesanal divergente (o local ainda usava o
 * locale do *dispositivo*, não o idioma escolhido no app).
 * **EN** Mirrors the canonical Rust core design (core/src/i18n.rs:
 * `Language::culture_notes` + `system_prompt`) so that remote (OpenAI-compat)
 * and local (llama.cpp via bridge) get exactly the same rules — previously
 * each layer had a divergent hand-rolled prompt (the local one even used the
 * *device* locale, not the language chosen in the app).
 */
import { PRODUCT_NAME } from './product';

/** Notas de cultura/formalidade por idioma (mesmos textos do core/src/i18n.rs). */
const CULTURE_NOTES: Readonly<Record<string, string>> = {
  'pt-BR': 'Use portugues do Brasil, tom acolhedor e direto.',
  'pt-PT': 'Use portugues de Portugal, pronomes na 2a pessoa do plural quando formal.',
  en: 'Use clear, neutral international English.',
  es: 'Use espanol neutro comprensible en toda Hispanoamérica.',
  fr: 'Utilisez un francais neutre et poli.',
  de: 'Verwenden Sie ein neutrales, hofliches Deutsch.',
  it: 'Usa un italiano neutro e cortese.',
  ru: 'Используйте нейтральный вежливый русский язык.',
  'zh-CN': '使用简体中文，语气礼貌自然。',
  ja: '丁寧で自然な日本語を使用してください。',
  ar: 'استخدم اللغة العربية الفصحى المبسطة بأسلوب مهذب.',
};

export interface LanguageInfo {
  /** Código BCP-47 canônico, ex.: `pt-BR`, `zh-CN`. */
  code: string;
  /** Nota de cultura/formalidade para o prompt. */
  culture: string;
}

/**
 * Resolve idioma a partir de códigos tipo `pt-BR`, `pt_PT`, `zh` — mesma
 * semântica de `Language::from_code` no core Rust (`pt` genérico → Brasil,
 * desconhecido → inglês).
 */
export function resolveLanguage(raw: string): LanguageInfo {
  const c = (raw || '').toLowerCase().replace('_', '-');
  const base = c.split('-')[0] ?? 'en';
  switch (base) {
    case 'pt':
      return c.endsWith('-pt')
        ? { code: 'pt-PT', culture: CULTURE_NOTES['pt-PT']! }
        : { code: 'pt-BR', culture: CULTURE_NOTES['pt-BR']! };
    case 'es':
      return { code: 'es', culture: CULTURE_NOTES.es! };
    case 'fr':
      return { code: 'fr', culture: CULTURE_NOTES.fr! };
    case 'de':
      return { code: 'de', culture: CULTURE_NOTES.de! };
    case 'it':
      return { code: 'it', culture: CULTURE_NOTES.it! };
    case 'ru':
      return { code: 'ru', culture: CULTURE_NOTES.ru! };
    case 'zh':
      return { code: 'zh-CN', culture: CULTURE_NOTES['zh-CN']! };
    case 'ja':
      return { code: 'ja', culture: CULTURE_NOTES.ja! };
    case 'ar':
      return { code: 'ar', culture: CULTURE_NOTES.ar! };
    default:
      return { code: 'en', culture: CULTURE_NOTES.en! };
  }
}

export interface SystemPromptOptions {
  /** Idioma escolhido no app (`Settings.language`), ex.: `pt-BR`. */
  language: string;
  /** JSON do catálogo de ferramentas registradas (opcional). */
  toolCatalogJson?: string;
  /** Embute a regra de privacidade local-first (padrão: true). */
  privacy?: boolean;
}

/**
 * Constrói o prompt de sistema do assistente — mesmas 5 regras (+ privacidade)
 * do `i18n::system_prompt` do core Rust, em português (língua franca do
 * projeto) com a nota de cultura no idioma de destino.
 */
export function buildSystemPrompt(opts: SystemPromptOptions): string {
  const lang = resolveLanguage(opts.language);
  const privacy = opts.privacy ?? true;
  const lines = [
    `Voce e o ${PRODUCT_NAME}, um assistente virtual que roda localmente no dispositivo do usuario.`,
    'Regras fundamentais:',
    '1. Voce NAO executa acoes diretamente. Para agir, selecione UMA ferramenta do catalogo',
    '   abaixo e devolva um JSON: {"tool": "<id>", "params": {...}}.',
    '2. NUNCA invente ferramentas, IDs ou parametros fora do catalogo.',
    '3. Acoes sensiveis serao confirmadas por um humano; informe isso quando relevante.',
    `4. Responda SEMPRE no idioma do usuario (idioma padrao: ${lang.code}). ${lang.culture}`,
    '5. Se faltar informacao, pergunte antes de agir.',
  ];
  if (privacy) {
    lines.push(
      '6. Privacidade: nada sai do dispositivo sem acao explicita do usuario. ' +
        'Nao incentive envio de dados a servicos externos.',
    );
  }
  let prompt = `${lines.join('\n')}\n`;
  if (opts.toolCatalogJson !== undefined) {
    prompt += `\nCatalogo de ferramentas registradas (JSON):\n${opts.toolCatalogJson}\n`;
  }
  return prompt;
}
