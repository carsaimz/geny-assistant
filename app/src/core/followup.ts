/**
 * Follow-up de 2ª passagem (TODO core-06, Fase 4).
 *
 * **PT** Depois de uma ferramenta executada com sucesso, o resultado volta
 * ao modelo para virar resposta em linguagem natural — em vez do genérico
 * "Pronto!". A instrução viaja como mensagem do usuário (os engines locais
 * só aceitam user/assistant) com o JSON do outcome embutido; a resposta da
 * 2ª passagem nunca é reinterpreta­da como tool call (sem loops).
 * **EN** After a tool executes successfully, the result goes back to the
 * model to become a natural-language reply — instead of a generic "Done!".
 * The instruction travels as a user message (local engines only accept
 * user/assistant) embedding the outcome JSON; the 2nd-pass reply is never
 * re-interpreted as a tool call (no loops).
 */

/** Instrução de 2ª passagem, em PT (língua franca dos prompts do projeto). */
export function toolFollowupInstruction(toolId: string, outcomeJson: string): string {
  return [
    '[resultado da ferramenta / tool result]',
    `Ferramenta "${toolId}" executou com sucesso e devolveu: ${outcomeJson}`,
    'Responda ao pedido anterior do usuario em linguagem natural, curta e util,',
    'usando esse resultado. NAO devolva JSON e nao chame outra ferramenta.',
  ].join('\n');
}

/** Outcome virado resumo compacto (evita estourar o contexto do modelo). */
export function compactOutcomeJson(outcome: Record<string, unknown>): string {
  try {
    const json = JSON.stringify(outcome);
    return json.length > 700 ? `${json.slice(0, 697)}...` : json;
  } catch {
    return '{}';
  }
}
