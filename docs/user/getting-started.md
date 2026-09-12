# Primeiros passos com a Geny (usuário)

## O que é a Geny?

A Geny é uma assistente que **roda no seu Android**. Ela conversa com você,
executa ações no dispositivo (abrir apps, criar notas, lembretes, ler
notificações) e — nas próximas fases — fala e ouve, tudo local-first: **nenhum
dado sai do seu telefone sem você mandar**.

## Instalar (alpha)

1. Baixe o APK mais recente em [Releases](https://github.com/carsaimz/geny-assistant/releases)
   (`geny-assistant-vX.Y.Z-release.apk` ou `-debug.apk`).
2. Android pode pedir permissão para "instalar apps desconhecidos" — normal
   para APKs fora da Play Store.
3. Abra a Geny e conceda permissões **conforme elas forem pedidas** — cada
   permissão aparece no momento em que é usada, com explicação.

> A Geny está em **alpha** (Fase 1). Recursos de voz e LLM local chegam nas
> Fases 2 e 3 (ver [ROADMAP](../../ROADMAP.md)).

## O que ela já sabe fazer (Fase 1)

Experimente no chat:

- "que horas são?"
- "como está a bateria?"
- "abre a calculadora"
- "pesquisa notícias de Moçambique"
- "crie uma nota: comprar café amanhã"

## Ações sensíveis e confirmação

Quando uma ação tem impacto (ex.: enviar SMS), a Geny **sempre pede
confirmação** com um resumo do que vai fazer:

- **Negar** — nada acontece e o pedido é registrado no log local.
- **Permitir uma vez** — vale só para aquela execução.

Níveis: `nenhuma` (inofensivas) → `simples` (reversíveis) → `explícita`
(SMS, chamadas) → `autenticada` (root — precisa também desbloquear o aparelho).

## Usar um modelo de IA (opcional, Fase 1 parcial)

Em **Configurações → Modo de operação**:

- **Local (offline)** — padrão. Roteador de intenções local, sem rede.
- **Remoto (API)** — informe a URL de um serviço compatível com OpenAI, o
  modelo e a sua chave (fica só no seu dispositivo).
- **Próprio (self-hosted)** — aponte para Ollama, LM Studio ou vLLM na sua
  rede, ex.: `http://192.168.1.10:11434/v1`.

## Idiomas

A interface já vem em 11 idiomas (Configurações → Idioma), incluindo
português do Brasil e de Portugal. Árabe ativa a direção direita→esquerda
automaticamente.

## Problemas comuns

| Problema | O que fazer |
|---|---|
| A Geny não abre um app | verifique se o nome existe; tente "apps.list" primeiro |
| Lembretes não tocam | desative a otimização de bateria para a Geny (Configurações do Android) |
| Notificações não aparecem | conceda "acesso a notificações" nas configurações especiais do Android |
| Modo remoto dá erro | confira a URL (`/v1` no final) e se o servidor está na mesma rede |

Mais detalhes técnicos: [docs/](../).
