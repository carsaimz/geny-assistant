# Ferramentas do usuário (Lua) — docs/TECHNICAL_SPEC.md §6.4, §12.4

Ferramentas escritas em Lua são registradas em tempo de execução pelo núcleo
Rust (via `mlua`, sandbox). Nenhuma recompilação do app é necessária.

## Formato de uma ferramenta

Cada arquivo `.lua` começa com um bloco de manifesto em comentário:

```lua
--[==[ Geny Tool
id: examples.greet          -- identificador único (dominio.acao)
name: Cumprimentar           -- nome legível
description: Devolve uma saudação personalizada
version: 0.1.0
confirmation: none           -- none | simple | explicit | authenticated
permissions: []              -- permissões Android exigidas
params:
  - name: who                -- esquema de parâmetros (YAML simples)
    type: string
    required: false
]==]--

--- Execução. Recebe `params` (tabela) e retorna uma tabela (vira JSON).
function geny_run(params)
  return { greeting = "Olá, " .. (params.who or "mundo") .. "!" }
end
```

## Regras de segurança (docs §12.5)

1. A ferramenta roda dentro de um **sandbox Lua**: sem `os.execute`, `io`
   irrestrito, `require` controlado.
2. Os parâmetros são **validados** contra o esquema antes de `geny_run`.
3. `confirmation` acima de `none` exige **confirmação humana** a cada uso.
4. Todas as execuções são registradas no **log de auditoria** local.
5. A ferramenta recebe apenas a API `geny`:

| API | Descrição |
|---|---|
| `geny.toast(msg)` | Mostra um toast curto na tela |
| `geny.now_ms()` | Horário atual em ms |
| `geny.storage.get/set(key, value)` | KV persistente da ferramenta |
| `geny.http.get(url)` | HTTP GET (requer `network: true` no manifesto) |

## Instalação

Copie o `.lua` para a pasta de ferramentas do app (Configurações → Ferramentas
→ Importar) ou coloque em `tools/` antes do build. O catálogo é consultável
pelo usuário e pelo modelo de IA (que só pode escolher entre as registradas).

## Exemplos

- [`examples/greet.lua`](examples/greet.lua) — ferramenta mínima sem permissões.
- [`examples/battery_report.lua`](examples/battery_report.lua) — usa `geny.toast` e estado.
- [`examples/system_cleaner.lua`](examples/system_cleaner.lua) — exemplo com root
  (`confirmation: authenticated`), desativado por padrão.
