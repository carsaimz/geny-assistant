/**
 * Suporte multilíngue por design (docs/TECHNICAL_SPEC.md §8).
 * Idiomas principais obrigatórios + pt-PT. Fallback: inglês.
 */
import ptBR from './locales/pt-BR.json';
import ptPT from './locales/pt-PT.json';
import en from './locales/en.json';
import es from './locales/es.json';
import fr from './locales/fr.json';
import de from './locales/de.json';
import it from './locales/it.json';
import ru from './locales/ru.json';
import zhCN from './locales/zh-CN.json';
import ja from './locales/ja.json';
import ar from './locales/ar.json';

export type LocaleCode =
  | 'pt-BR'
  | 'pt-PT'
  | 'en'
  | 'es'
  | 'fr'
  | 'de'
  | 'it'
  | 'ru'
  | 'zh-CN'
  | 'ja'
  | 'ar';

export interface LocaleInfo {
  code: LocaleCode;
  label: string;
  rtl: boolean;
}

export const LOCALES: LocaleInfo[] = [
  { code: 'pt-BR', label: 'Português (Brasil)', rtl: false },
  { code: 'pt-PT', label: 'Português (Portugal)', rtl: false },
  { code: 'en', label: 'English', rtl: false },
  { code: 'es', label: 'Español', rtl: false },
  { code: 'fr', label: 'Français', rtl: false },
  { code: 'de', label: 'Deutsch', rtl: false },
  { code: 'it', label: 'Italiano', rtl: false },
  { code: 'ru', label: 'Русский', rtl: false },
  { code: 'zh-CN', label: '中文 (简体)', rtl: false },
  { code: 'ja', label: '日本語', rtl: false },
  { code: 'ar', label: 'العربية', rtl: true },
];

const DICTIONARIES: Record<LocaleCode, Record<string, string>> = {
  'pt-BR': ptBR,
  'pt-PT': ptPT,
  en,
  es,
  fr,
  de,
  it,
  ru,
  'zh-CN': zhCN,
  ja,
  ar,
};

export function isLocaleCode(value: string): value is LocaleCode {
  return LOCALES.some((l) => l.code === value);
}

export function localeInfo(code: LocaleCode): LocaleInfo {
  const found = LOCALES.find((l) => l.code === code);
  const fallback = LOCALES[0];
  if (found !== undefined) return found;
  if (fallback === undefined) throw new Error('tabela de locales vazia');
  return fallback;
}

let current: LocaleCode = 'pt-BR';

export function getLocale(): LocaleCode {
  return current;
}

export function setLocale(code: string): void {
  current = isLocaleCode(code) ? code : 'en';
  const info = localeInfo(current);
  document.documentElement.lang = current;
  // §8.4 — direção de texto para idiomas RTL.
  document.documentElement.dir = info.rtl ? 'rtl' : 'ltr';
}

/** Traduz uma chave com fallback para inglês e para a própria chave. */
export function t(key: string): string {
  return DICTIONARIES[current][key] ?? DICTIONARIES.en[key] ?? key;
}

/** Aplica traduções a elementos estáticos com data-i18n / data-i18n-placeholder. */
export function applyI18nDom(root: ParentNode = document): void {
  root.querySelectorAll<HTMLElement>('[data-i18n]').forEach((el) => {
    el.textContent = t(el.dataset.i18n ?? '');
  });
  root
    .querySelectorAll<HTMLElement>('[data-i18n-placeholder]')
    .forEach((el) => {
      el.setAttribute('placeholder', t(el.dataset.i18nPlaceholder ?? ''));
    });
}
