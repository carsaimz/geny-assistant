# Luacheck: linter das ferramentas Lua do usuário.
# Instalado no CI via luarocks (workflow lint).
std = "lua54"
globals = [
    "geny_run",
    "geny",
]
exclude_files = ["examples/.luacheckrc"]
