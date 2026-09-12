# Arquitetura — Geny Assistant

Resumo executivo do §3 da [especificação técnica](TECHNICAL_SPEC.md), com o mapa
para o código real do repositório.

## Sete camadas / Seven layers

| Camada | Responsabilidade | Código |
|---|---|---|
| **1. Apresentação** | Chat, i18n, HUD, notificações, onboarding | `app/src/ui/`, `app/src/main.ts`, `android/.../overlay/`, `service/` |
| **2. Orquestração** | Sessão, roteamento, validação, confirmação, fila | `core/src/orchestrator.rs`, `session.rs`, `confirmation.rs` + `app/src/ui/chat.ts` (v0) |
| **3. Modelos de IA** | LLM local/remoto/self-hosted, STT, TTS, embeddings, wake word | `core/src/backend.rs`, `android/.../ai/` (F2–F3 completam) |
| **4. Ferramentas** | Unidades executáveis com esquema e confirmação | `core/src/tools/`, `android/.../tools/`, `tools/` (Lua) |
| **5. Acesso ao sistema** | Intents, serviços, SAF, listener, root | `android/.../bridge/`, `listener/`, `service/` |
| **6. Persistência** | Relacional, vetorial (F5), segredos, cache | `android/.../data/`, `security/`, `models/` |
| **7. Infraestrutura** | CI/CD, downloads, logs, atualizações | `.github/workflows/`, `scripts/` |

## Fluxo de uma interação / Interaction flow (v0)

```
usuário → app (chat.ts)
  ├─ modo local:  intent.ts detecta intenção → tool call direto
  └─ modo remoto: remote.ts → API OpenAI-compat (catálogo no system prompt)
        ↓ resposta contém {"tool": id, "params"}?
  ├─ sim → runTool(): confirmação (se nível > none) → bridge.invokeTool()
  │         → Kotlin: validação → aprovação prévia → executor → auditoria
  │         → resultado vira bolha "tool" na UI (+ follow-up do modelo)
  └─ não → texto puro renderizado
```

Na Fase 3, a seta do modelo passa a atravessar o núcleo Rust (UniFFI) para os
modos locais — as interfaces (`LlmBackend`, `ToolExecutor`, `ConfirmationGate`)
já existem em `core/src/` para essa migração.

## Decisões-chave / Key decisions (ADR-resumido)

1. **Tool calling fechado** — o modelo escolhe entre ferramentas registradas;
   nunca inventa comandos (§2.5). Vale para Rust, Kotlin e Lua.
2. **Confirmação fail-safe** — sem Activity viva, a decisão é negar; aprovações
   são de uso único e ficam no lado nativo (defesa em profundidade mesmo que a
   web confirme antes).
3. **Monorepo** — contra o custo de sincronizar 4 toolchains, otimiza a
   consistência dos tipos compartilhados (`ToolDefinition`, `ConfirmationLevel`).
4. **SQLiteOpenHelper na Fase 1** — Room+KSP chega na Fase 3 (`android-04`);
   o contrato de dados já está definido em `GenyDb`.
5. **Apache-2.0** — compatível com as dependências MIT e com concessão de patentes.

## Caminhos de evolução / Evolution paths

- Rust → Android via UniFFI (`core-04`).
- WebView → telas nativas Compose para overlay e telas críticas (Fase 4+).
- SQLite → Room + sqlite-vec para memória semântica (Fase 5).
- Um único `GenyPlugin` → plugins separados por domínio quando passar de ~25 métodos.
