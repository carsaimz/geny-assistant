import { describe, expect, it } from 'vitest';
import { matchIntent } from '../core/intent';

describe('roteador de intenções offline', () => {
  it('detecta pedido de horas (pt)', () => {
    const intent = matchIntent('que horas são?');
    expect(intent).not.toBeNull();
    expect(intent?.toolId).toBe('time.now');
  });

  it('detecta pedido de horas (en)', () => {
    const intent = matchIntent('what time is it');
    expect(intent?.toolId).toBe('time.now');
  });

  it('detecta bateria', () => {
    expect(matchIntent('como está a bateria?')?.toolId).toBe('device.battery');
    expect(matchIntent('battery level')?.toolId).toBe('device.battery');
  });

  it('detecta abrir aplicativo (pt/en)', () => {
    const intent = matchIntent('abre a calculadora');
    expect(intent?.toolId).toBe('apps.open');
    expect(intent?.params['app']).toBe('calculadora');
    expect(matchIntent('open camera')?.toolId).toBe('apps.open');
  });

  it('detecta pesquisa web preservando acentos', () => {
    const intent = matchIntent('pesquisa notícias de Moçambique');
    expect(intent?.toolId).toBe('web.search');
    expect(intent?.params['query']).toBe('notícias de moçambique');
  });

  it('detecta criação de nota', () => {
    const intent = matchIntent('crie uma nota: comprar café');
    expect(intent?.toolId).toBe('notes.create');
    expect(intent?.params['body']).toContain('comprar café');
  });

  it('retorna null para conversa livre', () => {
    expect(matchIntent('conte-me uma história')).toBeNull();
    expect(matchIntent('')).toBeNull();
  });
});
