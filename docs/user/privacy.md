# Privacidade em linguagem simples / Privacy in plain language

## A regra de ouro / The golden rule

**PT** Nada sai do seu dispositivo sem que você execute uma ação explícita para
isso. Não existe telemetria, analytics, anúncios ou coleta de uso no Geny
Assistant — você pode verificar no código aberto, pois não há nada escondido.

**EN** Nothing leaves your device unless you explicitly make it happen. No
telemetry, analytics, ads or usage collection — verify it in the open source.

## Onde ficam seus dados / Where your data lives

| Dado | Local | Saí daí quando… |
|---|---|---|
| Conversas | banco local do app | você apagar (Configurações → Privacidade) |
| Notas | `filesDir/notes` | você apagá-las |
| Fatos que a Geny aprende | banco local | você apagá-los (Fase 5 traz UI) |
| Chave de API | Android Keystore (AES-256-GCM) | nunca — excluída de backup |
| Auditoria de ações | `filesDir/audit` (rotativa) | você exportar |

Backup do Android **não** copia segredos nem auditoria (regras em
`backup_rules.xml`).

## Quando a rede é usada / When network is used

Só nestes casos, sempre iniciados por você:

1. **Modo remoto/self-hosted** — você configurou uma API/servidor e mandou
   uma mensagem para ele.
2. **Pesquisa web** — você pediu ("pesquisa…") e o navegador abre.
3. **Download de modelos** — você iniciou o download.

O modo **Local (offline)** padrão não abre conexão nenhuma.

## Root

O root é **desligado por padrão**. Se você ativar (Fase 7), cada ação
privilegiada exige confirmação autenticada e fica num log de auditoria
separado. A Geny nunca pede root por conta própria.

## Seus direitos (LGPD/GDPR)

- **Acesso/exportação**: exporte conversas e logs nas configurações.
- **Exclusão**: apague conversas, fatos e auditoria a qualquer momento.
- **Portabilidade**: exportação em formatos abertos (JSON/Markdown).
- **Revogação**: permissões Android podem ser revogadas quando quiser —
  a Geny continua funcionando com o que sobrou.

Dúvidas de privacidade: abra uma issue com a etiqueta `privacy` ou leia
[SECURITY.md](../../SECURITY.md).
