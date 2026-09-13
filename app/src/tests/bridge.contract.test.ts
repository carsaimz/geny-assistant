/**
 * Contrato da ponte web↔nativo (docs §12.4, TODO android-05).
 *
 * **PT** O nativo resolve `invokeTool` com `{ outcomeJson: string }`. O mock
 * web precisa cumprir o MESMO contrato — este teste varre o catálogo do mock
 * e garante que todo `outcomeJson` volta como string JSON parseável com
 * status válido. Regressão do bug `"undefined" is not valid JSON` (alpha.2),
 * em que o nativo devolvia o objeto cru e TODA ferramenta no Android aparecia
 * como falha.
 * **EN** The native side resolves `invokeTool` with `{ outcomeJson: string }`.
 * The web mock must honor the SAME contract — this test sweeps the mock
 * catalog and guarantees every `outcomeJson` is a parseable JSON string with
 * a valid status. Regression test for the alpha.2 bug.
 */
import { describe, expect, it } from 'vitest';
import { bridge, setConfirmationHandler } from '../core/bridge';

const SAMPLE_PARAMS: Record<string, Record<string, unknown>> = {
  'time.now': {},
  'device.battery': {},
  'apps.list': { query: 'cam' },
  'apps.open': { app: 'calculadora' },
  'notes.create': { title: 'teste', body: 'contrato' },
  'web.search': { query: 'geny assistant' },
};

const VALID_STATUS = new Set(['ok', 'denied', 'failed']);

describe('contrato da ponte — invokeTool', () => {
  it('todo outcomeJson do mock é string JSON parseável com status válido', async () => {
    setConfirmationHandler(async () => true);
    const { tools } = await bridge.listTools();
    expect(tools.length).toBeGreaterThan(0);

    for (const tool of tools) {
      const params = SAMPLE_PARAMS[tool.id] ?? {};
      const { outcomeJson } = await bridge.invokeTool({
        callId: `contract-${tool.id}`,
        toolId: tool.id,
        paramsJson: JSON.stringify(params),
      });
      expect(outcomeJson, `outcomeJson ausente para ${tool.id}`).toBeTypeOf('string');
      const outcome = JSON.parse(outcomeJson) as { status: string; tool_id: string };
      expect(VALID_STATUS.has(outcome.status), `status inválido para ${tool.id}`).toBe(true);
      expect(outcome.tool_id).toBe(tool.id);
    }
    setConfirmationHandler(null);
  });

  it('ferramenta inexistente retorna outcome failed parseável', async () => {
    const { outcomeJson } = await bridge.invokeTool({
      callId: 'contract-none',
      toolId: 'tool.nao.existe',
      paramsJson: '{}',
    });
    const outcome = JSON.parse(outcomeJson) as { status: string };
    expect(outcome.status).toBe('failed');
  });
});
