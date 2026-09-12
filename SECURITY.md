# Política de Segurança / Security Policy

## Versões suportadas / Supported versions

| Versão | Suportada / Supported |
|---|---|
| 0.1.x (alpha) | ✅ — correções prioritárias / priority fixes |
| < 0.1 | ❌ |

## Reportando uma vulnerabilidade / Reporting a vulnerability

**PT** NÃO abra issue pública para vulnerabilidades. Use as **Security
Advisories privadas** do GitHub (aba Security → Report a vulnerability) ou
contate os mantenedores diretamente. Responderemos em até **72 horas** e
manteremos você informado da correção. Divulgação responsável: coordenamos a
publicação junto com a versão corrigida e damos crédito (se você desejar).

**EN** Do NOT open a public issue for vulnerabilities. Use GitHub's private
security advisories. We respond within 72 hours and coordinate disclosure with
the patched release.

## Escopo e modelo de ameaças / Scope & threat model

Pontos críticos deste projeto (ver docs/TECHNICAL_SPEC.md §13):

1. **Execução de ferramentas** — validação de parâmetros, confirmação humana
   (none/simple/explicit/authenticated) e auditoria local são obrigatórias.
   Qualquer caminho que execute algo sem esses portões é vulnerabilidade crítica.
2. **Root** — nunca automático, sempre opt-in e confirmado; bypass = crítico.
3. **Segredos** — chaves de API apenas no Android Keystore; proibido em logs,
   backups e texto plano.
4. **Comunicação** — TLS obrigatório; cleartext desativado no manifest.
5. **Dados do usuário** — nada sai do dispositivo sem ação explícita.

Fora de escopo: dispositivos com root comprometido, engenharia social,
vulnerabilidades em dependências já reportadas upstream.

## Práticas do projeto / Project practices

- CI com análise estática (clippy -D warnings, eslint, gradle lint) em todo PR.
- Dependabot para atualizações semanais de dependências.
- Verificação de integridade (SHA-256) obrigatória para modelos baixados.
- Auditoria local rotativa de ações sensíveis (filesDir/audit/).
