# models/ — modelos de IA (NUNCA versionados)

Modelos baixados (GGUF, whisper, Piper, ONNX) vivem aqui no ambiente de dev.
**Nenhum modelo é commitado** — o `.gitignore` bloqueia tudo exceto este README
(docs §5.2).

## Baixar / download

```bash
./scripts/download-model.sh <url> <destino> [sha256-esperado]
```

Sempre verifique o hash SHA-256 contra a fonte oficial. No dispositivo, o
download é feito pelo app com verificação de integridade
(`android/.../ai/ModelManager.kt`, Fase 3 traz a UI).

## Sugestões por categoria / suggested models

| Categoria | Modelo | Tamanho aprox. | Uso |
|---|---|---|---|
| LLM | Qwen2.5 1.5B Instruct Q4_K_M (GGUF) | ~940 MB | chat local (Fase 3) |
| LLM | Gemma 2 2B Q4_K_M (GGUF) | ~1.6 GB | alternativa com melhor pt |
| STT | whisper.cpp ggml-tiny.bin | ~75 MB | ditado multilíngue (Fase 2) |
| STT | whisper.cpp ggml-base.bin | ~142 MB | melhor precisão |
| TTS | Piper pt_BR-faber-medium | ~63 MB | voz pt-BR (Fase 2) |
