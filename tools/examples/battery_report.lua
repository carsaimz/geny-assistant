--[==[ Geny Tool
id: examples.battery_report
name: Relatório de bateria
description: Mostra um toast com o nível de bateria e guarda o último valor.
version: 0.1.0
confirmation: none
permissions: []
params: []
]==]--

--- Usa geny.storage para lembrar a última leitura.
function geny_run(_params)
    -- A API device.battery do host é injetada como geny.device quando o
    -- usuário autoriza ferramentas que tocam o dispositivo (Fase 4).
    local level = 80 -- fallback enquanto a ponte nativa não está anexada
    if geny.device ~= nil and geny.device.battery_level ~= nil then
        level = geny.device.battery_level
    end

    local previous = geny.storage.get("last_level")
    geny.storage.set("last_level", tostring(level))

    local trend = ""
    if previous ~= nil then
        local p = tonumber(previous) or level
        if level > p then
            trend = " (subiu desde a última consulta)"
        elseif level < p then
            trend = " (caiu desde a última consulta)"
        end
    end

    local message = "Bateria: " .. tostring(level) .. "%" .. trend
    geny.toast(message)
    return { level = level, message = message }
end
