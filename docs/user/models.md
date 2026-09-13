# Modelo local (LLM) — guia do usuário / Local model (LLM) — user guide

> **PT** A Fase 3 traz inferência de linguagem 100% local: o Geny roda um
> modelo GGUF com llama.cpp compilado no próprio app (arm64-v8a e x86_64).
> Nenhum texto sai do dispositivo, nenhum modelo vem embutido no APK e nada
> é enviado a servidores — local-first de verdade.
> **EN** Phase 3 brings 100% on-device language inference: Geny runs a GGUF
> model with llama.cpp compiled into the app itself (arm64-v8a and x86_64).
> No text leaves the device, no model ships inside the APK and nothing is
> sent to servers — local-first for real.

## Requisitos / Requirements

| | |
|---|---|
| **PT** | Android 8.0+ (API 26). O aparelho precisa de RAM livre suficiente: ~1,6 GB para o Qwen 0.5B, ~2,2 GB para o Llama 1B, ~2,8 GB para o Qwen 1.5B e ~3,4 GB para o Gemma 2B (modelo × 1,35 + 128 MB de overhead). |
| **EN** | Android 8.0+ (API 26). The phone needs enough free RAM: ~1.6 GB for Qwen 0.5B, ~2.2 GB for Llama 1B, ~2.8 GB for Qwen 1.5B and ~3.4 GB for Gemma 2B (model × 1.35 + 128 MB overhead). |

## Instalar um modelo / Installing a model

**PT**

1. Abra **Configurações** (ícone ⚙) e vá até a seção **Modelo local (LLM)**.
2. Escolha um modelo na lista. O selo ✓ indica que ele já está no aparelho.
3. Toque em **Baixar**. O progresso aparece em percentual — o download vem do
   HuggingFace e é verificado por **SHA-256 pinado**; se um byte sair
   diferente do catálogo, o ficheiro é descartado.
4. Depois do download, toque em **Carregar** para deixar o modelo na memória.
5. No modo **Local** (padrão), as mensagens do chat passam a usar o modelo.

**EN**

1. Open **Settings** (⚙ icon) and go to the **Local model (LLM)** section.
2. Pick a model from the list. The ✓ badge means it is already on the device.
3. Tap **Download**. Progress shows as a percentage — the file comes from
   HuggingFace and is verified against a **pinned SHA-256**; if a single byte
   differs from the catalog, the file is discarded.
4. After the download, tap **Load** to keep the model in memory.
5. In **Local** mode (the default), chat messages now use the model.

## Catálogo inicial / Initial catalog

| Modelo | Tamanho | Licença | Observação |
|---|---|---|---|
| Qwen2.5 0.5B Instruct | ~469 MB | Apache-2.0 | Ideal para aparelhos com pouca RAM |
| Llama 3.2 1B Instruct | ~770 MB | Llama 3.2 | Bom equilíbrio |
| Qwen2.5 1.5B Instruct | ~1,0 GB | Apache-2.0 | Melhor qualidade, mais RAM |
| Gemma 2 2B IT | ~1,6 GB | Gemma | Melhor qualidade do catálogo |

Todos são quantizações **Q4_K_M** — o melhor equilíbrio entre tamanho e
qualidade para CPU de celular. Todos os três idiomas prioritários
(pt-BR/pt-PT/en) funcionam bem.

*All of them are **Q4_K_M** quantizations — the best size/quality balance
for phone CPUs. All three priority languages (pt-BR/pt-PT/en) work well.*

## Espaço e limpeza / Storage and cleanup

**PT** A linha *Modelos no aparelho* mostra o uso total de disco (modelos de
voz inclusos). O botão **Excluir** remove o GGUF selecionado; se ele estiver
carregado, o Geny descarrega antes. Modelos ficam em um diretório privado do
app — o desinstalar remove tudo junto.

**EN** The *Models on device* line shows total disk usage (voice models
included). The **Delete** button removes the selected GGUF; if it is loaded,
Geny unloads it first. Models live in a private app directory — uninstalling
the app removes everything.

## Privacidade / Privacy

- **PT** A inferência acontece inteiramente no CPU do aparelho (llama.cpp,
  sem GPU nos alpha). O histórico de mensagens nunca é enviado a rede no modo
  local; a auditoria local registra o tempo de geração, não o conteúdo.
- **EN** Inference happens entirely on the phone CPU (llama.cpp, no GPU in
  the alphas). Message history never touches the network in local mode; the
  local audit log records generation time, not content.

## Solução de problemas / Troubleshooting

| Situação | O que fazer / What to do |
|---|---|
| `low_memory` | Feche outros apps ou escolha um modelo menor (Qwen 0.5B). / Close other apps or pick a smaller model (Qwen 0.5B). |
| `modelo_nao_carregado` | Toque em **Carregar** na seção do modelo antes de conversar. / Tap **Load** in the model section before chatting. |
| `download_failed` | Verifique a conexão e tente de novo; o download recomeça do zero com hash verificado. / Check the connection and retry; the download restarts from scratch with hash verification. |
| Motor local indisponível | Seu build não compilou o `:llama-native` — use um APK da release oficial. / Your build lacks `:llama-native` — use an official release APK. |
| Resposta lenta | Modelos maiores são lentos em CPU; prefira Qwen 0.5B em aparelhos modestos. / Larger models are slow on CPU; prefer Qwen 0.5B on modest phones. |

## Limitações da alpha / Alpha limitations

**PT** A geração não tem streaming (a resposta aparece completa ao final); a
janela de contexto é de 2048 tokens; não há seleção de seed/temperatura na UI
(defaults sensatos). Estas capacidades entram nas próximas alphas, junto com
TTS neural (Piper) e wake word — ver ROADMAP.

**EN** Generation has no streaming (the reply appears complete at the end);
the context window is 2048 tokens; there is no seed/temperature selection in
the UI (sensible defaults). These capabilities land in upcoming alphas,
together with neural TTS (Piper) and wake word — see the ROADMAP.
