--[==[ Geny Tool
id: examples.greet
name: Cumprimentar
description: Devolve uma saudação personalizada em texto puro.
version: 0.1.0
confirmation: none
permissions: []
params:
  - name: who
    type: string
    required: false
]==]--

--- Saudação simples, sem permissões nem efeitos colaterais.
-- @param params.who nome opcional de quem cumprimentar
-- @return tabela com a mensagem
function geny_run(params)
    local who = params.who
    if who == nil or who == "" then
        who = "mundo"
    end
    return {
        greeting = "Olá, " .. who .. "! Tudo roda aqui no seu dispositivo."
    }
end
