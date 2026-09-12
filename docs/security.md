# Segurança e privacidade — notas de implementação

Referência normativa: [especificação técnica §13](TECHNICAL_SPEC.md).
Este documento registra **como** cada princípio está implementado hoje (Fase 1)
e o que falta.

## O que já está implementado / implemented now

| Princípio | Implementação | Código |
|---|---|---|
| Nada sai do dispositivo sem ação explícita | modo local não abre socket; mock web não acessa rede | `app/src/core/bridge.ts` |
| TLS obrigatório | `usesCleartextTraffic=false` no manifest; sem mixed content no Capacitor | `AndroidManifest.xml`, `capacitor.config.*` |
| Chaves no Keystore | AES-256-GCM com IV aleatório, prefs `geny_secure` excluídas de backup | `security/KeystoreManager.kt`, `res/xml/*_rules.xml` |
| Confirmação humana | 4 níveis, fail-safe negar, aprovação de uso único, vibração + diálogo nativo | `security/ConfirmationManager.kt`, `bridge/GenyPlugin.kt` |
| Auditoria local | JSON Lines rotativo (512 KB) em `filesDir/audit/`, excluído de backup | `security/ConfirmationManager.kt` (AuditLog) |
| Modelo não inventa comandos | validação estrita + rejeição de ferramenta não registrada | `tools/ToolRegistry.kt`, `core/src/tools/validator.rs` |
| Zero telemetria | nenhum SDK de analytics; dependências auditáveis no lockfile | — |
| Modelos com integridade | SHA-256 obrigatório no download (script e app) | `scripts/download-model.sh`, `ai/ModelManager.kt` |

## Ameaças consideradas / threat model (resumo)

1. **Modelo manipulado pede ação perigosa** → portões 1–4 do tool calling;
   parâmetros desconhecidos são rejeitados; root exige `authenticated`.
2. **WebView comprometida** → segredos ficam no Keystore; aprovações vivem no
   lado nativo; a ponte revalida tudo.
3. **Backup do Android exfiltrando dados** → regras excluem `geny_secure.xml`
   e `audit/` de backup e device-transfer.
4. **Dependência maliciosa** → dependabot semanal + travas de versão + revisão
   de diffs em atualizações de runtime (capacitor, coroutines).

## Pendências programadas / planned gaps

- [ ] Certificate pinning opcional por provedor (Fase 6) — `SEC-01`
- [ ] BiometricPrompt para nível `authenticated` (Fase 7) — `android-11`
- [ ] Criptografia opcional do banco (SQLCipher) (Fase 5) — `SEC-02`
- [ ] Detecção de segredos commitados no CI (gitleaks) — `ci-03`
- [ ] Exportação/importação cifrada de logs e configuração (Fase 5) — `app-04`

Reporte vulnerabilidades em privado: [SECURITY.md](../SECURITY.md).
