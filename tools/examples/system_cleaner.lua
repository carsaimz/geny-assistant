--[==[ Geny Tool
id: examples.system_cleaner
name: Limpador de sistema (root)
description: EXEMPLO EDUCATIVO de ferramenta privilegiada — limpa caches de
  sistema via shell. Requer root, confirmação autenticada e está desativada
  por padrão. Não execute sem entender o que faz.
version: 0.1.0
confirmation: authenticated
permissions: [root]
params:
  - name: dry_run
    type: boolean
    required: false
]==]--

--- Exemplo do nível `authenticated` (docs §12.3 nível 4):
--- cada execução exige desbloqueio do dispositivo + confirmação explícita,
--- e toda ação é registrada no log de auditoria.
function geny_run(params)
    local dry = params.dry_run == true

    -- Em sandbox real, shell de root só existe quando o usuário ativou
    -- explicitamente o modo root nas configurações (docs §13.4).
    if geny.root == nil then
        return { ok = false, reason = "modo root não ativado nas configurações" }
    end

    local command = "pm trim-caches 999999999999"
    if dry then
        return { ok = true, would_run = command, dry_run = true }
    end

    local ok, output = geny.root.run(command)
    return { ok = ok, output = output }
end
