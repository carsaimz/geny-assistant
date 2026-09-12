/**
 * Roteador de intenções offline (local-first, Fase 1).
 *
 * Sem nenhum modelo de IA instalado, o assistente já responde a comandos
 * básicos detectando a intenção do texto e selecionando uma ferramenta do
 * catálogo — o modelo de IA (Fase 3/6) usará o mesmo mecanismo de tool calling.
 */
import type { ToolIntent } from '../types';

/** Remove acentos e normaliza para comparação. */
function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

/** Padrões de extração — palavras-chave sem acento para casar com texto normalizado. */
const OPEN_RE =
  /\b(?:abre|abrir|abra|inicie|iniciar|open|launch)\b(?:\s+(?:o|a|o aplicativo|app|the app))?\s+(.+)/;
const SEARCH_RE =
  /\b(?:pesquise|pesquisar|pesquisa|busque|buscar|procur|search|look up)\b(?:\s+(?:na web|na internet|no google|the web|on the web|for))?\s+(.+)/;
const NOTE_RE = /\b(?:crie uma nota|criar nota|anote|anotar|make a note|note down)\b\s*(.*)/;

export function matchIntent(rawText: string): ToolIntent | null {
  const text = normalize(rawText);
  // Texto em minúsculas mas com acentos preservados, para parâmetros legíveis.
  const raw = rawText.toLowerCase().trim();

  // Hora / data
  if (/\b(que horas sao|horas|hora atual|me diga as horas|time|what time|que hora es)\b/.test(text)) {
    return { toolId: 'time.now', params: {} };
  }

  // Bateria
  if (/\b(bateria|battery|carga)\b/.test(text)) {
    return { toolId: 'device.battery', params: {} };
  }

  // Abrir aplicativo
  const openMatch = raw.match(OPEN_RE) ?? text.match(OPEN_RE);
  if (openMatch?.[1] !== undefined) {
    const app = openMatch[1]
      .replace(/\b(app|aplicativo|the app)\b/g, '')
      .replace(/^(o|a|os|as)\s+/, '')
      .trim();
    if (app.length > 0) return { toolId: 'apps.open', params: { app } };
  }

  // Pesquisar na web
  const searchMatch = raw.match(SEARCH_RE) ?? text.match(SEARCH_RE);
  if (searchMatch?.[1] !== undefined && searchMatch[1].trim().length > 0) {
    return { toolId: 'web.search', params: { query: searchMatch[1].trim() } };
  }

  // Criar nota
  const noteMatch = raw.match(NOTE_RE) ?? text.match(NOTE_RE);
  if (noteMatch !== null) {
    const rest = (noteMatch[1] ?? '').trim();
    const [title, ...bodyParts] = rest.split(/[:\-–]\s*/);
    return {
      toolId: 'notes.create',
      params: {
        title: title !== undefined && title.length > 0 ? title : 'Nota',
        body: bodyParts.join(' ') || rest,
      },
    };
  }

  return null;
}
