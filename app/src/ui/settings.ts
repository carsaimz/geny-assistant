/**
 * Painel de configurações: modo de operação, backend remoto/self-hosted,
 * idioma e nota de privacidade. No Android, a chave de API é delegada ao
 * Keystore via ponte nativa; no web fica em localStorage (apenas dev).
 */
import { LOCALES, t } from '../i18n';
import type { Settings } from '../types';

export interface SettingsCallbacks {
  onSave: (s: Settings) => void;
}

export function renderSettingsDrawer(
  drawer: HTMLElement,
  settings: Settings,
  cb: SettingsCallbacks,
): void {
  drawer.innerHTML = `
    <header class="drawer-head">
      <h2>${t('settings.title')}</h2>
      <button type="button" class="icon-btn" id="btn-close-settings" aria-label="${t('settings.title')}">✕</button>
    </header>
    <form id="settings-form" class="drawer-body">
      <label>
        <span>${t('settings.mode')}</span>
        <select id="set-mode">
          <option value="local">${t('settings.mode.local')}</option>
          <option value="remote">${t('settings.mode.remote')}</option>
          <option value="selfhosted">${t('settings.mode.selfhosted')}</option>
        </select>
      </label>
      <label>
        <span>${t('settings.baseUrl')}</span>
        <input id="set-baseurl" type="url" placeholder="http://localhost:11434/v1" />
      </label>
      <label>
        <span>${t('settings.model')}</span>
        <input id="set-model" type="text" placeholder="qwen2.5:1.5b" />
      </label>
      <label>
        <span>${t('settings.apiKey')}</span>
        <input id="set-apikey" type="password" placeholder="sk-…" autocomplete="off" />
        <small>${t('settings.apiKey.desc')}</small>
      </label>
      <label>
        <span>${t('settings.language')}</span>
        <select id="set-lang">
          ${LOCALES.map((l) => `<option value="${l.code}">${l.label}</option>`).join('')}
        </select>
      </label>
      <p class="privacy-note">${t('settings.privacy')}</p>
      <button type="submit" class="btn-primary">${t('settings.save')}</button>
    </form>`;

  const $ = <T extends HTMLElement>(id: string): T => {
    const el = drawer.querySelector(`#${id}`);
    if (el === null) throw new Error(`elemento ausente: ${id}`);
    return el as T;
  };

  const mode = $<HTMLSelectElement>('set-mode');
  const baseUrl = $<HTMLInputElement>('set-baseurl');
  const model = $<HTMLInputElement>('set-model');
  const apiKey = $<HTMLInputElement>('set-apikey');
  const lang = $<HTMLSelectElement>('set-lang');

  mode.value = settings.mode;
  baseUrl.value = settings.baseUrl;
  model.value = settings.model;
  lang.value = settings.language;
  if (settings.apiKeySet) apiKey.placeholder = '••••••••';

  $<HTMLButtonElement>('btn-close-settings').addEventListener('click', () => {
    drawer.hidden = true;
  });

  $<HTMLFormElement>('settings-form').addEventListener('submit', (ev) => {
    ev.preventDefault();
    cb.onSave({
      mode: mode.value as Settings['mode'],
      language: lang.value,
      model: model.value.trim(),
      baseUrl: baseUrl.value.trim(),
      apiKeySet: settings.apiKeySet || apiKey.value.trim().length > 0,
    });
    const key = apiKey.value.trim();
    if (key.length > 0) {
      localStorage.setItem('geny.apikey', key);
    }
    apiKey.value = '';
    window.setTimeout(() => {
      drawer.hidden = true;
    }, 450);
  });
}
