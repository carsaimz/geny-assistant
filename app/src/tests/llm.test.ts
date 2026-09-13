/**
 * Contrato do LLM local na ponte (Fase 3, docs §6, TODO app-02).
 *
 * **PT** O mock web do LLM é honesto: `jniAvailable: false`, geração
 * indisponível (rejeita + evento `llmError`), e o `addListener` entrega os
 * dois domínios de eventos (genyVoice/genyLlm) com `remove()` funcional.
 * **EN** The web LLM mock is honest: `jniAvailable: false`, generation
 * unavailable (rejects + `llmError` event), and `addListener` serves both
 * event domains (genyVoice/genyLlm) with a working `remove()`.
 */
import { describe, expect, it } from 'vitest';
import { bridge } from '../core/bridge';
import type { LlmEvent } from '../core/llm-types';

describe('contrato da ponte — LLM local', () => {
  it('capabilities do mock reportam o motor como indisponível', async () => {
    const { json } = await bridge.getLlmCapabilities();
    const caps = JSON.parse(json) as { jniAvailable: boolean; state: string; models: unknown[] };
    expect(caps.jniAvailable).toBe(false);
    expect(caps.state).toBe('idle');
    expect(Array.isArray(caps.models)).toBe(true);
  });

  it('generateLocal rejeita e emite llmError (unavailable)', async () => {
    const events: LlmEvent[] = [];
    const handle = bridge.addListener('genyLlm', (event) => {
      events.push(event as LlmEvent);
    });

    await expect(bridge.generateLocal({ messages: [{ role: 'user', content: 'oi' }] }))
      .rejects.toThrow();
    // o evento chega assíncrono (setTimeout 0)
    await new Promise((r) => setTimeout(r, 10));
    const err = events.find((e) => e.type === 'llmError');
    expect(err).toBeDefined();
    if (err?.type === 'llmError') expect(err.code).toBe('unavailable');

    handle.remove();
  });

  it('addListener com remove() para de entregar eventos', async () => {
    const events: LlmEvent[] = [];
    const handle = bridge.addListener('genyLlm', (event) => {
      events.push(event as LlmEvent);
    });
    handle.remove();

    await bridge.loadLocalModel({ file: 'qualquer.gguf' }).catch(() => undefined);
    await new Promise((r) => setTimeout(r, 10));
    expect(events.find((e) => e.type === 'llmError')).toBeUndefined();
  });

  it('deleteLlmModel no mock devolve deleted=false', async () => {
    const { deleted } = await bridge.deleteLlmModel({ file: 'x.gguf' });
    expect(deleted).toBe(false);
  });
});
