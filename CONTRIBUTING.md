# Contribuir para o Geny Assistant / Contributing

Obrigado pelo interesse! **PT** primeiro, **EN** em seguida.

## Código de conduta / Code of conduct

Ao participar, você concorda com o [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Como posso ajudar? / How can I help?

1. **Issues** — reporte bugs ou proponha funcionalidades (templates prontos).
   Novas ideias vão também para a seção 💡 do [ROADMAP.md](ROADMAP.md).
2. **Código** — escolha uma issue aberta, comente que vai pegá-la e siga o fluxo abaixo.
3. **Documentação** — traduções, guias e correções são contribuições valiosas.
4. **Testes** — mais cobertura e dispositivos diferentes na matriz de testes.

## Fluxo de trabalho / Workflow

- Branches: `main` (estável), `develop` (integração), `feature/*`, `fix/*`.
- Faça o fork ou crie branch a partir de `develop`.
- PRs apontam para `develop`; releases saem de `main` via tags `v*`.

```bash
git checkout -b feature/minha-feature develop
# ... código + testes ...
git commit -m "feat(escopo): descrição em português / english description"
git push -u origin feature/minha-feature
# abra o PR com o template
```

## Conventional commits bilingues / Bilingual conventional commits

Formato: `tipo(escopo): descrição em pt / en description`

```
feat(core): adiciona memória semântica / add semantic memory
fix(android): corrige permissão de SMS em API 34 / fix SMS permission on API 34
docs(app): traduz guia de privacidade / translate privacy guide
refactor(app), test(core), chore(ci), ci(android), docs(especificacao)…
```

Quebra de compatibilidade: `!` após o tipo e nota `BREAKING CHANGE:` no corpo.

## Padrões de qualidade / Quality gates

Antes de abrir o PR, rode e garanta verde (all green):

```bash
cd core    && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
cd app     && npm run lint && npm test && npm run build
cd android && gradle :app:lintDebug :app:testDebugUnitTest
```

## Princípios não negociáveis / Non-negotiable principles

1. **Local-first**: funcionalidade essencial sem internet.
2. **Zero telemetria**: nada de analytics, ads ou coleta.
3. **Menor privilégio**: permissões em contexto; root opt-in.
4. **Confirmação humana**: ações sensíveis exigem nível adequado
   (none/simple/explicit/authenticated) e auditoria.
5. **Sem segredos**: nenhuma credencial versionada; chaves vão no Keystore.

PRs que violarem estes princípios serão recusados independentemente da qualidade técnica.
