# Tool calling — como a Geny executa ações

O modelo de IA **nunca executa** nada. Ele apenas seleciona uma ferramenta
registrada e fornece parâmetros; a execução passa por quatro portões obrigatórios
(docs/TECHNICAL_SPEC.md §12):

```
modelo escolhe {"tool": "sms.send", "params": {...}}
   → 1. REGISTRO     ferramenta existe no catálogo?
   → 2. VALIDAÇÃO    esquema: tipos, obrigatórios, allowed_values
   → 3. CONFIRMAÇÃO  humana conforme o nível (fail-safe: negar)
   → 4. EXECUÇÃO     com timeout, auditoria e política de erro
```

## Contrato de uma ferramenta / tool contract

Os três lados compartilham o mesmo contrato (mantido manualmente, ver
`app/src/types.ts`):

| Campo | Rust (`core/src/tools/registry.rs`) | Kotlin (`tools/Tool.kt`) | TS (`app/src/types.ts`) |
|---|---|---|---|
| `id` | `ToolDefinition.id` | `Tool.id` | `ToolDefinition.id` |
| `params` | `Vec<ParamSpec>` | `List<ParamSpec>` | `ParamSpec[]` |
| `confirmation` | `ConfirmationLevel` | `ConfirmationLevel` | `ConfirmationLevel` |
| `context` | `ToolContext` (app/service/root) | idem | idem |
| `timeout_ms` | default 10_000 | default 10_000 | — |

## Níveis de confirmação / confirmation levels

| Nível | Uso | Exemplos no catálogo |
|---|---|---|
| `none` | inofensivas | `time.now`, `apps.list`, `device.battery` |
| `simple` | reversíveis | `notes.create`, `reminders.set`, `location.get` |
| `explicit` | com impacto | `sms.send`, `call.dial` |
| `authenticated` | críticas/root | `examples.system_cleaner` (Lua) |

Regras de implementação (já no código):

1. **Fail-safe**: sem UI disponível, a resposta é *negar* (Kotlin
   `ConfirmationManager.isPreApproved` + diálogo nativo; Rust `AutoPolicy`).
2. **Uso único**: cada aprovação cobre exatamente uma execução.
3. **Defesa em profundidade**: mesmo que a camada web confirme, o lado nativo
   exige aprovação prévia própria antes de executar (`invokeTool`).
4. **Auditoria**: toda aprovação/negação/execução vai para `filesDir/audit/`.

## Catálogo atual (Fase 1, 18 ferramentas Kotlin)

`time.now` · `device.battery` · `device.wifi` · `device.openSettings` ·
`apps.open` · `apps.list` · `web.search` · `call.dial` · `sms.send` ·
`contacts.search` · `notifications.read` · `notifications.dismiss` ·
`notes.create` · `notes.list` · `notes.read` · `share.text` ·
`location.get` · `reminders.set`

O espelho em Rust (`core/src/tools/catalog.rs`) mantém as mesmas definições
para o prompt do modelo; a UI web usa o catálogo recebido da ponte.

## Ferramentas do usuário (Lua)

Formato e sandbox: [`tools/README.md`](../tools/README.md). Resumo:

```lua
--[==[ Geny Tool
id: examples.greet
confirmation: none
params:
  - name: who
    type: string
]==]--
function geny_run(params)
  return { greeting = "Olá, " .. (params.who or "mundo") }
end
```

O sandbox (mlua, Fase 4 — `core-07`) expõe apenas `geny.toast`, `geny.now_ms`,
`geny.storage.get/set`, `geny.device` (leitura) e `geny.root` (opt-in com
`allow_root`, Fase 7). Sem `io`, sem `require`/`load`, sem `os.execute` — com
teto de memória (8 MiB) e orçamento de instruções contra loops infinitos.

## Adicionar uma nova ferramenta — checklist

1. Kotlin: crie a `Tool` (id único `dominio.acao`), registre no `GenyPlugin.load()`.
2. Rust: espelhe a definição em `core/src/tools/catalog.rs`.
3. Confirmação: escolha o nível mais **baixo** aceitável — e documente o motivo.
4. Permissões: declare no `AndroidManifest.xml` (solicitadas em contexto).
5. Auditoria: `host.audit(...)` dentro da execução.
6. Testes: valide o esquema em `ToolValidatorTest` (Kotlin) e `validator.rs` (Rust).
