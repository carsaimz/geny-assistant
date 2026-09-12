# native/ — submodules C/C++ de inferência

Este diretório recebe os **submodules** das bibliotecas nativas (nada é
versionado aqui além deste README — cada clone baixa sob demanda):

| Biblioteca | Uso | Fase |
|---|---|---|
| `llama.cpp/` | inferência LLM on-device (GGUF) | 3 |
| `whisper.cpp/` | STT local | 2 |

## Preparar / set up

```bash
./scripts/setup-submodules.sh
```

O script fixa as versões (build determinista — docs §2.8). Atualize os pins
com intenção explícita, registrando no CHANGELOG.

## Compilar

- Rust core para Android: `./scripts/build-rust-android.sh`
- llama.cpp/whisper.cpp via CMake: entra na Fase 2/3 com presets por ABI
  (`TODO core-02/core-05`).
