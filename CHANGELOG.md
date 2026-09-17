# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
versionamento [Semântico](https://semver.org/lang/pt-BR/).

## [0.3.0-alpha.11] — Fase 5 completa: Memória / Phase 5 complete: Memory

### Adicionado / Added

- **Memória semântica no core** (`core-08`, Fase 5, #45): feature `semantic`
  com `HashingEmbedder` — embeddings determinísticos multilíngues (n-gramas
  de 1–3 caracteres, FNV-1a 64-bit, projeção 256d normalizada L2, zero
  dependências) — e `SemanticIndex` com busca top-k por cosseno. O objeto
  UniFFI `GenyMemory` expõe o ciclo completo ao Kotlin (remember/forget/
  recall/list/search semântica e substring/export/import/retention), com o
  índice reconstruído a partir do Room e sincronizado a cada escrita. O
  upgrade para MiniLM via ONNX permanece como rota futura (a trait
  `Embedder` é o ponto de extensão); sem a feature, `search_semantic` cai
  para substring com score 0.
  *Semantic memory in the core* (`core-08`, Phase 5, #45): `semantic`
  feature with `HashingEmbedder` — deterministic multilingual embeddings
  (1–3 char n-grams, FNV-1a 64-bit, 256d L2-normalized projection, zero
  deps) — and `SemanticIndex` with top-k cosine search. The UniFFI
  `GenyMemory` object exposes the full cycle to Kotlin (remember/forget/
  recall/list/semantic and substring search/export/import/retention), with
  the index rebuilt from Room and synced on every write. The MiniLM-via-ONNX
  upgrade remains a future path (the `Embedder` trait is the extension
  point); without the feature, `search_semantic` falls back to substring
  with score 0.

- **Recall antes de responder** (`core-08`, Fase 5): o chat consulta
  `memorySearch` com a última mensagem do usuário e injeta os fatos
  relevantes na seção de memória do prompt de sistema — em 11 idiomas
  (`memory_header` no Rust, `MEMORY_HEADERS` espelho no TS) — para os
  backends remoto e local, via `system_prompt_with_memory` (Rust),
  `buildSystemPromptWithMemory` (UniFFI) e `buildSystemPrompt` com
  `memoryLines` (web). Sem fatos, o prompt segue inalterado.
  *Recall before answering* (`core-08`, Phase 5): the chat queries
  `memorySearch` with the user's last message and injects relevant facts
  into the system prompt's memory section — across 11 languages
  (`memory_header` in Rust, `MEMORY_HEADERS` TS mirror) — for both remote
  and local backends, via `system_prompt_with_memory` (Rust),
  `buildSystemPromptWithMemory` (UniFFI) and `buildSystemPrompt` with
  `memoryLines` (web). Without facts, the prompt is unchanged.

- **Política de retenção** (`core-09`, Fase 5, #47): `RetentionPolicy`
  (max_facts, max_age_days, max_value_bytes) aplicada automaticamente a
  cada escrita (`remember` e `apply_retention`) — os mais antigos saem
  primeiro, com desempate por chave — e o envelope de exportação/importação
  versionado v1 (compatível com o array legado v0), compartilhado entre
  core (Rust), ponte (`memoryExport`/`memoryImport`) e backup cifrado.
  Espelho Kotlin puro (`RetentionLogic`) JVM-testável cobre builds sem o
  core. Chaves internas (`wakeword.*`) não aparecem na memória do usuário.
  *Retention policy* (`core-09`, Phase 5, #47): `RetentionPolicy`
  (max_facts, max_age_days, max_value_bytes) applied automatically on every
  write (`remember` and `apply_retention`) — oldest first, key as tiebreak
  — plus the versioned v1 export/import envelope (backwards-compatible with
  the legacy v0 array), shared by the core (Rust), the bridge
  (`memoryExport`/`memoryImport`) and the encrypted backup. A pure Kotlin
  mirror (`RetentionLogic`), JVM-testable, covers core-less builds. Internal
  keys (`wakeword.*`) never surface in the user's memory.

- **Tela nativa de Memória** (`android-08`, Fase 5, #46): `MemoryActivity`
  no estilo da tela de Modelos (Material3, tema `Theme.Geny`, UI em código)
  com lista de fatos (Room), busca semântica (core) com fallback substring,
  adicionar/editar/apagar com confirmação, limpar tudo, resumo e edição da
  política de retenção (0 = sem limite). Métodos `memoryList`/`memorySet`/
  `memoryDelete`/`memoryClear`/`memorySearch`/`memoryExport`/`memoryImport`/
  `memoryRetention`/`openMemoryScreen` na ponte; mock web com fatos em
  localStorage e busca substring.
  *Native Memory screen* (`android-08`, Phase 5, #46): `MemoryActivity` in
  the Models-screen style (Material3, `Theme.Geny` theme, code-built UI)
  with the facts list (Room), semantic search (core) with substring
  fallback, add/edit/delete with confirmation, clear all, plus a retention
  summary and editor (0 = unlimited). `memoryList`/`memorySet`/
  `memoryDelete`/`memoryClear`/`memorySearch`/`memoryExport`/
  `memoryImport`/`memoryRetention`/`openMemoryScreen` bridge methods; web
  mock keeps facts in localStorage with substring search.

- **Backup cifrado de configuração** (`app-04`, Fase 5, #48): arquivo
  portátil `GENYBAK1` — PBKDF2-HMAC-SHA256 (210.000 iterações, salt 16B)
  deriva a chave AES-256 da senha do usuário; AES-256-GCM (IV 12B, tag 128)
  cifra o envelope com configurações (incluindo chave de API, pois o arquivo
  inteiro é cifrado) + fatos + retenção. Gravação/leitura via SAF
  (`ACTION_CREATE_DOCUMENT`/`ACTION_OPEN_DOCUMENT`) com `backupExport`/
  `backupImport` na ponte; seção Backup nas configurações web (só no app,
  com nota honesta no navegador); restauração aplica os fatos nativamente e
  devolve as configurações à web. Sem nuvem e sem Keystore no formato — a
  senha é o único segredo.
  *Encrypted settings backup* (`app-04`, Phase 5, #48): portable `GENYBAK1`
  file — PBKDF2-HMAC-SHA256 (210,000 iterations, 16B salt) derives the
  AES-256 key from the user's passphrase; AES-256-GCM (12B IV, 128-bit tag)
  encrypts the envelope holding settings (including the API key, since the
  whole file is passphrase-encrypted) + facts + retention. Written/read via
  SAF (`ACTION_CREATE_DOCUMENT`/`ACTION_OPEN_DOCUMENT`) with `backupExport`/
  `backupImport` on the bridge; Backup section in the web settings (app
  only, with an honest note in the browser); restore applies facts
  natively and hands settings back to the web layer. No cloud and no
  Keystore in the format — the passphrase is the only secret.

## [0.3.0-alpha.10] — Fase 4 completa: OCR local / Phase 4 complete: local OCR

### Adicionado / Added

- **OCR local** (`android-06`, Fase 4, #41): tool `ocr.read` (nível SIMPLE)
  com `OcrReader` no pacote `ocr` — ML Kit v2 (`text-recognition` 16.0.1,
  bundle Latin: pt/en/es/fr/de/it), 100% on-device, sem Play Services e sem
  permissões amplas de armazenamento: a imagem abre por `content://`
  (seletor do sistema ou pasta autorizada SAF). Execução em thread de fundo
  com `Tasks.await` e limite de 30 s; envelope JSON com códigos estáveis
  (`ok`/`uri_invalida`/`falha_ao_carregar`/`tempo_esgotado`/
  `falha_do_motor`), texto extraído, número de blocos e de linhas.
  `ocrRead` na ponte + mock web honesto + `ocr.read` no catálogo web.
  Testes Robolectric: códigos estáveis, URIs inválidas e falha de abertura.
  *Local OCR* (`android-06`, Phase 4, #41): `ocr.read` tool (SIMPLE level)
  with `OcrReader` — ML Kit v2 (Latin bundle: pt/en/es/fr/de/it), 100%
  on-device, no Play Services and no broad storage permissions: the image
  opens via `content://` (system picker or authorized SAF folder). Runs on
  a background thread with `Tasks.await` and a 30 s cap; JSON envelope with
  stable codes, extracted text, block and line counts. `ocrRead` on the
  bridge + honest web mock + `ocr.read` in the web catalog. Robolectric
  tests: stable codes, invalid URIs and open failures.

## [0.3.0-alpha.9] — SAF, resposta a notificações e catálogo de ferramentas / SAF, notification reply and tool catalog

### Adicionado / Added

- **Pastas autorizadas (SAF)** (`android-05`, Fase 4, #40): seletor de pasta
  via `ACTION_OPEN_DOCUMENT_TREE` com permissão persistida e lista guardada
  nos fatos do GenyDb. Métodos `safPickFolder`/`safAuthorized`/`safRevoke`/
  `safList`/`safRead`/`safWrite`/`safMkdir`/`safDelete` na ponte — criar,
  ler, escrever (com append), criar pastas e excluir por caminho RELATIVO,
  sempre dentro da pasta autorizada (`SafPaths` rejeita `..`, `.` e
  absolutos), com guard de pasta autorizada na ponte, limite de leitura de
  2 MiB e auditoria. Mock web nega com honestidade.
  *Authorized folders (SAF)* (`android-05`, Phase 4, #40): folder picker via
  `ACTION_OPEN_DOCUMENT_TREE` with persisted grant, folder list kept in
  GenyDb facts. `safPickFolder`/`safAuthorized`/`safRevoke`/`safList`/
  `safRead`/`safWrite`/`safMkdir`/`safDelete` bridge methods — create, read,
  write (with append), mkdir and delete by RELATIVE path, always inside the
  authorized folder (`SafPaths` rejects `..`, `.` and absolute paths), with
  an authorized-folder guard on the bridge, a 2 MiB read cap and audit. The
  web mock denies honestly.

- **Responder notificações** (`android-07`, Fase 4, #43): tool
  `notifications.reply` (nível EXPLICIT) que localiza a ação de resposta da
  notificação capturada (`remoteInputs`), escreve o texto via
  `androidx.core.app.RemoteInput.addResultsToIntent` (mecanismo correto por
  versão, lido por `RemoteInput.getResultsFromIntent` no app de origem) e
  dispara o PendingIntent — sem rede nem credenciais. Códigos de resultado
  estáveis (`sent`/`sem_acao_de_resposta`/...) no envelope e na auditoria;
  testes Robolectric com notificação real.
  *Notification replies* (`android-07`, Phase 4, #43): the `notifications.reply`
  tool (EXPLICIT level) locates the captured notification's reply action
  (`remoteInputs`), writes the text via
  `androidx.core.app.RemoteInput.addResultsToIntent` (per-version mechanism
  read by `RemoteInput.getResultsFromIntent` on the origin app) and fires
  the PendingIntent — no network, no credentials. Stable result codes
  (`sent`/`sem_acao_de_resposta`/...) in the envelope and audit; Robolectric
  tests with a real notification.

- **Catálogo de ferramentas na UI** (`app-03`, Fase 4, #44): nova seção
  "Ferramentas registradas" nas configurações lista cada ferramenta da
  ponte com nome, descrição, parâmetros (`req*` marcados) e um selo
  colorido do nível de confirmação (nenhuma/simples/explícita/
  autenticada), com contagem. 6 chaves novas nos 11 locales e testes de
  contrato web (selos, locales, catálogo do mock).
  *Tool catalog in the UI* (`app-03`, Phase 4, #44): a new "Registered
  tools" section in settings lists each bridge tool with name, description,
  parameters (`req*` marked) and a colored confirmation-level badge
  (none/simple/explicit/authenticated), plus a count. 6 new keys in all 11
  locales and web contract tests (badges, locales, mock catalog).

### Corrigido / Fixed

- Envio de resposta usa `addResultsToIntent` do androidx core — as
  constantes/métodos do framework (`EXTRA_RESULTS`, `remoteInputSources`)
  não estão disponíveis no compileSdk atual.
  *Reply sending uses androidx core's `addResultsToIntent` — framework
  constants/methods (`EXTRA_RESULTS`, `remoteInputSources`) are not
  available on the current compileSdk.*

## [0.3.0-alpha.8] — Sandbox Lua para ferramentas do usuário / Lua sandbox for user tools

### Adicionado / Added

- **Sandbox mlua** (`core-07`, Fase 4, #42): nova feature `lua` no geny-core
  com mlua 0.12 (Lua 5.4 vendored — sem dependência do sistema). O manifesto
  `--[==[ Geny Tool ... ]==]--` é parseado e validado (id, nome, descrição,
  versão, nível de confirmação, permissões e esquema de parâmetros, com
  continuação multilinha e listas `[a, b]`). A sandbox roda em modo seguro:
  `StdLib::ALL_SAFE`, sem `io`/`package`/`require`/`dofile`/`loadfile`/`load`,
  `os` reduzido a `time`/`clock`/`date` — mais teto de memória (8 MiB) e
  orçamento de instruções via hook de depuração, que interrompe loops
  infinitos. A API `geny.*` é injetada pelo host via trait `LuaHost`:
  `geny.toast`, `geny.now_ms`, `geny.storage.get/set`, `geny.device`
  (somente leitura) e `geny.root.run` opt-in com `allow_root` (Fase 7).
  `load_tools_from_dir` carrega a pasta `tools/` e `LuaTool.definition`
  mapeia cada ferramenta para o registro padrão, pronto para catálogo e
  prompt. 26 testes novos cobrem os 3 exemplos reais, bloqueios de
  segurança (io/os/require), limites de memória e de instruções, validação
  de parâmetros obrigatórios/tipos e manifestos inválidos.
  *mlua sandbox* (`core-07`, Phase 4, #42): new `lua` feature in geny-core
  with mlua 0.12 (vendored Lua 5.4 — no system dependency). The
  `--[==[ Geny Tool ... ]==]--` manifest is parsed and validated (id, name,
  description, version, confirmation level, permissions and param schema,
  with multi-line continuation and `[a, b]` lists). The sandbox runs in safe
  mode: `StdLib::ALL_SAFE`, no `io`/`package`/`require`/`dofile`/`loadfile`/
  `load`, `os` reduced to `time`/`clock`/`date` — plus a memory cap (8 MiB)
  and an instruction budget via debug hook that interrupts infinite loops.
  The `geny.*` API is injected by the host through the `LuaHost` trait:
  `geny.toast`, `geny.now_ms`, `geny.storage.get/set`, `geny.device`
  (read-only) and opt-in `geny.root.run` with `allow_root` (Phase 7).
  `load_tools_from_dir` loads the `tools/` folder and `LuaTool.definition`
  maps each tool into the standard registry, ready for catalog and prompt.
  26 new tests cover the 3 real examples, security blocks (io/os/require),
  memory and instruction limits, required/type parameter validation and
  invalid manifests.

### Documentação / Documentation

- `docs/tool-calling.md` e `tools/README.md` atualizados com a API real da
  sandbox (incl. ausência deliberada de `geny.http` nesta fase).
  *docs/tool-calling.md and tools/README.md updated with the actual sandbox
  API (including the deliberate absence of `geny.http` in this phase).*

## [0.3.0-alpha.7] — Fase 3 completa: wake word + Room + UniFFI / Phase 3 complete

### Adicionado / Added

- **Wake word opcional** (`android-03b`, Fase 3, #37): openWakeWord
  (Apache-2.0) com pipeline ONNX fiel ao openwakeword 0.6, validado
  numericamente contra o original — melspectrogram (1280+480 amostras,
  transformação `spec/10+2`), janela de 76 frames → embeddings 96-d do
  speech_embedding do Google, últimos 16 embeddings → score da frase.
  Catálogo da release v0.5.1 com SHA-256 pinado: 2 modelos de
  características compartilhados + 4 frases ("Hey Jarvis", "Hey Mycroft",
  "Alexa", "Hey Rhasspy"). `WakeWordService` em primeiro plano (microfone)
  DESLIGADO por padrão: ao disparar, emite `genyWake {type:'triggered'}` e
  notificação de toque; a UI abre a tela de voz. Gatilho puro (aquecimento
  de 5 frames, limiar 0,5, refratário de 2,5 s) coberto por testes JVM.
  *Optional wake word* (`android-03b`, Phase 3, #37): openWakeWord
  (Apache-2.0) with an ONNX pipeline faithful to openwakeword 0.6,
  numerically validated against the original — melspectrogram (1280+480
  samples, `spec/10+2` transform), 76-frame window → Google speech_embedding
  96-d, last 16 embeddings → phrase score. v0.5.1 release catalog with
  pinned SHA-256: 2 shared feature models + 4 phrases. The microphone
  foreground `WakeWordService` is OFF by default: on trigger it emits
  `genyWake {type:'triggered'}` plus a tap notification; the web UI opens
  the voice screen. Pure trigger logic (5-frame warm-up, 0.5 threshold,
  2.5 s refractory) covered by JVM tests.

- **Persistência com Room** (`android-04`, Fase 3, #36): `GenyDb` migra de
  SQLiteOpenHelper para Room 2.6.1 via KSP, com a MESMA API síncrona
  (chamadores intactos). Migração 1→2 recria `tool_calls`/`models`/`facts`
  no formato Room preservando dados; `ModelManager.delete` passa a remover
  também o registro. Testes JVM do Room via Robolectric (SQLite real).
  *Room persistence* (`android-04`, Phase 3, #36): `GenyDb` moves from
  SQLiteOpenHelper to Room 2.6.1 via KSP with the SAME synchronous API
  (callers untouched). Migration 1→2 rebuilds `tool_calls`/`models`/`facts`
  in Room's format preserving data; `ModelManager.delete` now also removes
  the DB row. Room JVM tests via Robolectric (real SQLite).

- **UniFFI — núcleo Rust no app** (`core-04`, Fase 3, #38): nova superfície
  `uniffi_api` no geny-core (`core_version`, `resolve_language`, `is_rtl`,
  `build_system_prompt` — i18n.rs direto com o catálogo REAL de ferramentas)
  exposta ao Kotlin via `libgeny_core.so` (cdylib, 3 ABIs) + JNA. Bindings
  Kotlin gerados versionados; o CI regenera e compara (drift check).
  `CoreBridge` degrada graciosamente sem a lib (dev/JVM); `GenyPlugin` usa
  o core no fallback do prompt de sistema quando o app não envia um.
  *UniFFI — Rust core in the app* (`core-04`, Phase 3, #38): new
  `uniffi_api` surface in geny-core exposed to Kotlin through
  `libgeny_core.so` (cdylib, 3 ABIs) + JNA. Generated Kotlin bindings
  committed; CI regenerates and diffs (drift check). `CoreBridge` degrades
  gracefully without the lib (dev/JVM); `GenyPlugin` uses the core for the
  system-prompt fallback when the app sends none.

### Alterado / Changed

- Catálogo unificado da tela nativa de Modelos cresce de 13 para 19
  entradas (seção `wakeword` depois de `llm`); seção "Palavra de ativação"
  nas configurações web com downloads `kind='wakeword'` e paridade i18n nos
  11 locales.
  *The native Models screen unified catalog grows from 13 to 19 entries
  (`wakeword` section after `llm`); "Wake word" section in the web settings
  with `kind='wakeword'` downloads and i18n parity across all 11 locales.*

## [0.3.0-alpha.6] — Tela nativa de Modelos / Native Models screen

### Adicionado / Added

- **Tela nativa de Modelos** (`android-03`, Fase 3, #35): espelho offline da
  seção de modelos da web num `ModelsActivity` dedicado — lista única dos
  catálogos Whisper (STT), Silero (VAD), vozes Piper (TTS) e modelos GGUF
  (LLM) com estado do arquivo no disco, SHA-256 pinado em cada cartão,
  download com barra de progresso (e fase de extração do espeak-ng),
  exclusão e resumo de espaço (livre no volume + uso dos modelos). Aberta
  pela seção Modelo local nas configurações (botão visível só no app) via
  novo método `openModelsScreen` da ponte; strings em en/pt/es e ícones do
  tema Material3 existente.
  *Native Models screen* (`android-03`, Phase 3, #35): an offline mirror of
  the web models section in a dedicated `ModelsActivity` — a single list of
  the Whisper (STT), Silero (VAD), Piper voice (TTS) and GGUF (LLM)
  catalogs with on-disk state, pinned SHA-256 per card, download with a
  progress bar (including the espeak-ng extraction phase), delete and a
  space summary (free volume + models usage). Opened from the web settings'
  Local model section (button visible in the app only) through the new
  `openModelsScreen` bridge method; strings in en/pt/es on the existing
  Material3 theme.

### Alterado / Changed

- `ModelManager` ganha guarda estática anti-colisão de downloads: a tela
  nativa e a UI web agora compartilham o controle por arquivo — quem pedir
  o mesmo modelo enquanto outro download está em andamento recebe erro em
  vez de corromper o `.part`.
  *`ModelManager` gains a static download anti-collision guard: the native
  screen and the web UI now share per-file control — requesting the same
  model while another download is running fails cleanly instead of
  corrupting the shared `.part` file.*

- Novos testes: catálogo unificado (13 entradas, hashes/bytes válidos,
  ordem stt→vad→tts→llm, `formatBytes` determinístico), guarda de download
  (exclusividade e case-insensitive) e contrato web do botão/ponte com
  paridade de i18n nos 11 locales.
  *New tests: unified catalog (13 entries, valid hashes/bytes, stt→vad→tts→llm
  order, deterministic `formatBytes`), download guard (exclusivity and
  case-insensitivity) and the web button/bridge contract with i18n parity
  across all 11 locales.*

## [0.3.0-alpha.5] — Modo automático + follow-up de ferramentas / Auto backend + tool follow-up

### Adicionado / Added

- **Modo Automático de backend** (Fase 3): seleção automática por turno —
  remoto quando há rede, chave configurada e bateria saudável (>15%, sem
  poupança de energia nem térmico alto); modelo local quando offline ou
  bateria baixa; intenções offline como último recurso. Bateria
  desconhecida (nativo devolve 0) não bloqueia o remoto. O `auto` é o novo
  modo padrão; `local`/`remoto`/`self-hosted` continuam disponíveis e
  preservam o comportamento explícito. No `auto`, motor local indisponível
  degrada para intenções em vez de mostrar erro.
  *Automatic backend mode (Phase 3): per-turn selection — remote when there
  is network, a configured key and healthy battery (>15%, no battery saver,
  no thermal alert); local model when offline or low battery; offline
  intents as the last resort. Unknown battery (native returns 0) does not
  block the remote path. `auto` is the new default mode; the explicit
  `local`/`remote`/`selfhosted` modes keep their previous behavior. In
  `auto`, an unavailable local engine degrades to intents instead of
  showing an error.*
- **Follow-up de 2ª passagem** (`core-06`, Fase 4): o resultado de uma
  ferramenta executada com sucesso volta ao modelo (remoto **ou** local)
  como instrução compacta com o JSON do outcome — a resposta passa a ser
  natural e contextual ("Agora são 10h00 em Maputo") em vez do genérico
  "Feito". A resposta da 2ª passagem nunca é reinterpreta­da como tool call
  (sem loops); falha mantém a mensagem genérica de sucesso. Funciona no
  chat e na tela de voz (que usa o mesmo fluxo).
  *Second-pass follow-up (`core-06`, Phase 4): a successful tool outcome
  goes back to the model (remote **or** local) as a compact instruction
  with the outcome JSON — the reply becomes natural and contextual
  ("It's 10:00 in Maputo now") instead of a generic "Done". The 2nd-pass
  reply is never re-interpreted as a tool call (no loops); on failure the
  generic success message is kept. Works in chat and the voice screen
  (same flow).*

### Alterado / Changed

- Novos testes: matriz do `pickBackend` (bateria/rede/modo) e do follow-up
  (contrato, resposta natural, fallback) — 62 testes vitest.
  *New tests: `pickBackend` matrix (battery/network/mode) and follow-up
  (contract, natural reply, fallback) — 62 vitest tests.*

## [0.3.0-alpha.4] — Streaming do LLM + TTS neural Piper / LLM streaming + Piper neural TTS

### Adicionado / Added

- **Streaming de tokens do LLM local** (`core-05b`): a resposta da Geny agora
  aparece palavra por palavra no chat — novo `nativeGenerateStream` no JNI do
  llama.cpp (callback por token, mesma thread do executor), eventos `llmToken`
  no canal `genyLlm`, bolha provisória com cursor pulsante, botão **Parar**
  que interrompe a geração e mantém o texto parcial (`stopped: true`, flag
  atômica no handle nativo), e novos controles de **temperatura** e **seed**
  na seção Modelo local.
  *Local LLM token streaming (`core-05b`): the assistant's reply now appears
  word by word in the chat — new `nativeGenerateStream` in the llama.cpp JNI
  (per-token callback on the executor thread), `llmToken` events on the
  `genyLlm` channel, a provisional bubble with a blinking cursor, a **Stop**
  button that cancels generation and keeps the partial text (`stopped: true`,
  atomic flag on the native handle), plus new **temperature** and **seed**
  controls in the Local model section.*
- **TTS neural via Piper** (`core-03`): vozes VITS do projeto Piper tocadas
  100% on-device — pt-BR (Faber), pt-PT (Tugão) e en-US (Amy), ~63 MB por voz,
  baixadas sob demanda com SHA-256 pinado. Fonemização IPA via espeak-ng
  compilado no app (submodule pinado @ ed530aa, mesmo pin do sherpa-onnx —
  núcleo `geny_espeak_*` espelha o piper-phonemize: IPA por oração com
  pontuação e filtro de marcadores de idioma) + inferência VITS com o ONNX
  Runtime já presente (Silero VAD) — nenhum nativo extra no APK além do
  wrapper. Os dados de fonemas do espeak (~9 MB) são um download único
  compartilhado entre as vozes. Seleção automática de voz por idioma da
  conversa (pt sem região → pt-PT); fallback silencioso para o TTS do sistema
  quando o Piper não está pronto; seção nova nas configurações com motor,
  dados de fonemas e vozes. Testes JVM do catálogo; strings nos 11 idiomas.
  *Neural TTS via Piper (`core-03`): Piper's VITS voices played 100%
  on-device — pt-BR (Faber), pt-PT (Tugão) and en-US (Amy), ~63 MB each,
  downloaded on demand with pinned SHA-256. IPA phonemization via espeak-ng
  compiled into the app (pinned submodule @ ed530aa, same pin as
  sherpa-onnx — the `geny_espeak_*` core mirrors piper-phonemize: per-clause
  IPA with punctuation and language-flag filtering) + VITS inference with the
  ONNX Runtime already bundled (Silero VAD) — no extra native code beyond
  the wrapper. The espeak phoneme data (~9 MB) is a single download shared
  across voices. Automatic voice selection by conversation language
  (region-less pt → pt-PT); silent fallback to system TTS when Piper isn't
  ready; new settings section with engine, phoneme data and voices. JVM
  catalog tests; strings in all 11 languages.*

### Alterado / Changed

- `LlmJni`/`WhisperJni`/`EspeakPhonemizer` e `TokenCallback` ficam protegidos
  de ofuscação R8 (JNI resolve símbolos por nome exato).
  *`LlmJni`/`WhisperJni`/`EspeakPhonemizer` and `TokenCallback` are kept from
  R8 obfuscation (JNI resolves symbols by exact name).*

### Corrigido / Fixed

- **Contrato da ponte do LLM local** (`core-05b`): o app enviava `messages`
  (array) e o plugin lia `messagesJson` (string) — todo pedido do LLM local
  falhava com `sem_mensagens` e o streaming nunca engatava. O histórico
  agora viaja serializado em `messagesJson` (convenção `*Json` da ponte,
  como `invokeTool`), o plugin aceita também `messages` (array) por
  robustez, e testes de regressão travam o contrato dos dois lados.
  *Local LLM bridge contract (`core-05b`): the app sent `messages` (array)
  while the plugin read `messagesJson` (string) — every local LLM request
  failed with `sem_mensagens` and streaming never engaged. History now
  travels serialized in `messagesJson` (the bridge's `*Json` convention,
  like `invokeTool`), the plugin also accepts `messages` (array) for
  robustness, and regression tests lock the contract on both sides.*

### Adicionado / Added

- **Prompt de sistema por idioma/cultura** (Fase 3): fonte única
  `buildSystemPrompt` no app — espelho do `i18n.rs` do core (mesmas regras,
  privacidade local-first e notas de cultura por idioma, ex.: pt-BR
  acolhedor, pt-PT formal, ja 丁寧) — para os backends **remoto e local**.
  Antes cada camada tinha um prompt artesanal divergente e o LLM local usava
  o locale do *dispositivo*, não o idioma escolhido no app; o prompt agora
  viaja pela ponte (`system`) com fallback pelo dispositivo, e o catálogo de
  ferramentas entra como JSON.
  *System prompt per language/culture (Phase 3): single source
  `buildSystemPrompt` in the app — mirror of the core `i18n.rs` (same rules,
  local-first privacy and per-language culture notes, e.g. pt-BR welcoming,
  pt-PT formal, ja 丁寧) — for **both** remote and local backends. Previously
  each layer had a divergent hand-rolled prompt and the local LLM used the
  *device* locale instead of the app language; the prompt now travels the
  bridge (`system`) with a device fallback, and the tool catalog ships as
  JSON.*

## [0.3.0-alpha.3] — Tela de voz + correção do microfone / Voice screen + mic fix

### Corrigido / Fixed

- **Crash ao tocar no microfone ("o app parou")**: `SpeechRecognizer.startListening`
  e `createOnDeviceSpeechRecognizer` eram chamados sem proteção — em aparelhos
  com o serviço de reconhecimento ocupado ou sem o pacote offline eles lançam
  `RejectedExecutionException`/`SecurityException`/`UnsupportedOperationException`,
  derrubando o app no primeiro toque. Agora qualquer falha vira evento de erro
  (`busy`/`unavailable`) com mensagem amigável; a captura whisper (AudioRecord)
  e a ponte também ganharam redes de proteção.
  *Crash when tapping the microphone ("app keeps stopping"): `startListening`
  and `createOnDeviceSpeechRecognizer` were unguarded — on devices with a busy
  recognition service or missing offline package they throw
  `RejectedExecutionException`/`SecurityException`/`UnsupportedOperationException`,
  killing the app on first tap. Failures now become friendly error events
  (`busy`/`unavailable`); the whisper (AudioRecord) capture and the bridge also
  gained safety nets.*
- Eventos `level` do microfone limitados a ~10/s (antes ~33/s afogava a ponte
  em aparelhos lentos); `TtsService.onDone` sem NPE em shutdown e início de
  serviço em segundo plano protegido (`ForegroundServiceStartNotAllowed`).
  *Mic `level` events throttled to ~10/s (previously ~33/s flooded the bridge
  on slow devices); `TtsService.onDone` NPE-free on shutdown and guarded
  background service start (`ForegroundServiceStartNotAllowed`).*

### Adicionado / Added

- **Tela de conversa por voz em tela cheia** (estilo assistente de voz): orb
  animado por estado (respirando → ouvindo → pensando → falando) que pulsa
  com o nível do microfone, legenda ao vivo, histórico da conversa, botão
  grande e modo **mãos-livres** — a Geny responde por voz e volta a ouvir
  sozinha quando termina de falar (novo canal `genyTts` com eventos
  start/done/error e rede de segurança por timeout). Strings nos 11 idiomas;
  8 novos testes de UI.
  *Full-screen voice conversation screen (voice-assistant style): state-driven
  animated orb (breathing → listening → thinking → speaking) that pulses with
  mic level, live caption, conversation log, big button and **hands-free**
  mode — the assistant speaks its reply and starts listening again
  automatically (new `genyTts` channel with start/done/error events plus a
  safety timeout). Strings in all 11 languages; 8 new UI tests.*

## [0.3.0-alpha.2] — Correção de instalação / Install fix

### Corrigido / Fixed

- **APK volta a instalar em telemóveis 32-bit (armeabi-v7a)**: o `abiFilters`
  introduzido com o pipeline de voz (`725441d`) reduziu o APK a arm64-v8a +
  x86_64 — em aparelhos 32-bit a instalação falhava com
  `INSTALL_FAILED_NO_MATCHING_ABIS`, o que deixou as releases
  v0.2.0-alpha.1 e v0.3.0-alpha.1 ininstaláveis (o encolhimento de 72 MB para
  43–54 MB era o mesmo sintoma, não uma otimização). O APK universal passa a
  conter armeabi-v7a, arm64-v8a e x86_64.
  *APK installs again on 32-bit (armeabi-v7a) phones: the `abiFilters`
  introduced with the voice pipeline (`725441d`) shrank the APK to arm64-v8a +
  x86_64 — on 32-bit devices installation failed with
  `INSTALL_FAILED_NO_MATCHING_ABIS`, making releases v0.2.0-alpha.1 and
  v0.3.0-alpha.1 un-installable (the 72 MB → 43–54 MB shrink was the same
  symptom, not an optimization). The universal APK now ships armeabi-v7a,
  arm64-v8a and x86_64.*
- **`libgeny_llama_jni.so` ausente no armv7**: o módulo `:llama-native`
  mantinha o mesmo filtro antigo (arm64+x86_64), e o merge de JNI libs
  empacotava o APK sem o LLM no armv7 silenciosamente. Filtros alinhados nos
  dois módulos; llama.cpp v0.4.0 compila e carrega em armv7.
  *Missing `libgeny_llama_jni.so` on armv7: the `:llama-native` module kept
  the old filter (arm64+x86_64), so JNI lib merge silently packed the APK
  without the LLM on armv7. Filters aligned across both modules; llama.cpp
  v0.4.0 now builds and loads on armv7.*

## [0.3.0-alpha.1] — Fase 3: LLM local / Phase 3: Local LLM

### Adicionado / Added

- **LLM 100% no dispositivo**: llama.cpp pinado @ v0.4.0 compilado no app via
  NDK, em módulo Gradle próprio (`:llama-native`, arm64-v8a/x86_64) — módulo
  separado porque o ggml do llama v0.4.0 é incompatível com o ggml vendored
  pelo whisper.cpp v1.7.4 (ambos usam a guarda `if (NOT TARGET ggml)`).
  JNI próprio (`geny_llama_jni`): init/free/generate com o template de chat
  do próprio modelo (GGUF), amostragem greedy (temperatura ≤ 0) ou
  top-p + temperatura + seed.
  *Fully on-device LLM: llama.cpp pinned @ v0.4.0 compiled into the app via
  NDK inside its own Gradle module (`:llama-native`) — separate because
  llama's ggml v0.4.0 is incompatible with the one vendored by whisper.cpp
  v1.7.4. Own JNI with the model's own chat template, greedy or top-p +
  temperature + seed sampling.*
- **Catálogo de modelos GGUF** com SHA-256 pinado (LFS do HuggingFace,
  verificado em 2026-09) e download sob demanda pelo ModelManager — nenhum
  modelo embutido no APK: Qwen2.5 0.5B/1.5B Instruct (Apache-2.0), Llama 3.2
  1B Instruct e Gemma 2 2B IT, todos Q4_K_M.
  *GGUF model catalog with pinned SHA-256 (HuggingFace LFS) and on-demand
  download — no model bundled in the APK: Qwen2.5 0.5B/1.5B Instruct
  (Apache-2.0), Llama 3.2 1B Instruct and Gemma 2 2B IT, all Q4_K_M.*
- **Guarda de RAM na carga**: o modelo só carrega se houver memória livre
  suficiente (bytes × 1,35 + 128 MB); erros mapeados para a UI
  (`low_memory`, `not_downloaded`, `jni_unavailable`, `load_failed`).
  *RAM guard on load: the model only loads with enough free memory
  (bytes × 1.35 + 128 MB); errors mapped for the UI.*
- **Seção "Modelo local (LLM)" nas configurações** (TODO app-02): seletor com
  estado de download (✓), download com progresso %, carregar/descarregar,
  remoção e uso de disco; eventos no canal `genyLlm` (`llmProgress`,
  `llmReady`, `llmStatus`, `llmError`).
  *"Local model (LLM)" settings section: picker with download state, % progress
  download, load/unload, delete and disk usage; events on the `genyLlm`
  channel.*
- **Chat com backend local**: no modo Local com modelo carregado, as
  mensagens passam pelo GGUF (com suporte a tool calling pelo mesmo
  contrato JSON do modo remoto); sem modelo ou sem JNI, cai para o roteador
  de intenções offline. Mock web honesto (motor indisponível no navegador).
  *Chat with the local backend: in Local mode with a loaded model, messages
  go through the GGUF (tool calling via the same JSON contract as remote);
  without a model or JNI it falls back to the offline intent router. Honest
  web mock (engine unavailable in browsers).*
- **ci-02**: job `cpp-android` no Build Native — matriz arm64-v8a/x86_64
  compilando os dois wrappers JNI via CMake+NDK com artefatos por ABI;
  caches nativos por módulo (whisper e llama) nos workflows Build APK e
  Release.
  *ci-02: `cpp-android` job in Build Native — arm64-v8a/x86_64 matrix
  compiling both JNI wrappers via CMake+NDK with per-ABI artifacts;
  per-module native caches in the Build APK and Release workflows.*
- **Testes**: LlmTest.kt (catálogo + parser de mensagens + RAM/threads) e
  llm.test.ts (contrato do mock LLM) — **26 testes web + 36 testes JVM**.
  *LlmTest.kt (catalog + message parser + RAM/threads) and llm.test.ts
  (LLM mock contract) — 26 web tests + 36 JVM tests.*

### Documentação / Documentation

- Guia bilíngue [`docs/user/models.md`](docs/user/models.md): requisitos de
  RAM, instalação passo a passo, catálogo, espaço, privacidade e solução de
  problemas. README/ROADMAP/TODO atualizados.
  *Bilingual guide: RAM requirements, step-by-step install, catalog, storage,
  privacy and troubleshooting. README/ROADMAP/TODO updated.*

## [0.2.0-alpha.1] — Fase 2: Voz / Phase 2: Voice

### Adicionado / Added

- **Conversa por voz**: botão de microfone no chat com painel de gravação
  (nível do microfone em tempo real, transcrição ao vivo, cancelar/parar) e
  envio automático da transcrição como mensagem.
  *Voice conversation: mic button in the chat with a recording panel
  (real-time mic level, live transcript, cancel/stop) and the transcript
  becomes the user's message.*
- **STT dupla e local-first**: reconhecedor do sistema em modo on-device
  (Android 12+ `createOnDeviceSpeechRecognizer`; `EXTRA_PREFER_OFFLINE` em
  versões anteriores) e whisper.cpp compilado no app via NDK (JNI próprio,
  submodule pinado v1.7.4, ABIs arm64-v8a/x86_64) com modelos GGML
  tiny/base/small/medium baixados sob demanda e verificados por SHA-256
  pinado — nenhum modelo embutido no APK.
  *Dual local-first STT: system recognizer on-device plus whisper.cpp
  compiled in-app via NDK with on-demand GGML models and pinned SHA-256.*
- **VAD**: energia RMS com histerese (espelho no core Rust — feature `vad`,
  6 testes) e Silero v5 via ONNX Runtime Android (modelo ~2 MB com SHA-256
  pinado, fallback automático para energia).
  *VAD: hysteresis RMS energy (mirrored in the Rust core) plus Silero v5 via
  ONNX Runtime with automatic fallback.*
- **TTS em serviço foreground** (`mediaPlayback`): motor TextToSpeech do
  sistema, pt-BR/pt-PT/en primeiro, notificação com botão de parar, e botão
  🔊 em cada resposta para reproduzir de novo.
  *Foreground-service TTS with the system engine, stop notification and
  per-message replay button.*
- **Permissão RECORD_AUDIO em contexto** (nunca no arranque), via
  PermissionCallback do Capacitor, com auditoria local.
  *RECORD_AUDIO requested in context only, audited locally.*
- **CI**: NDK r27.2 + CMake 3.22.1 + `submodules: recursive` em 4 workflows
  e cache do build nativo (TODO ci-01).
  *CI installs NDK/CMake, checks out submodules and caches native builds.*
- **docs/user/voice.md** bilíngue (configuração de vozes, STT, VAD, TTS).

### Corrigido / Fixed

- `@PermissionCallback` sem argumentos (API Capacitor 6) e nível de RMS
  lido do `AnalyserNode` no mock web — pegos por testes novos.
  *Fixed callback annotation usage and the web-mock level meter — caught by
  new tests.*

## [0.1.0-alpha.3] — Correção do contrato de invokeTool / invokeTool contract fix

### Corrigido / Fixed

- **Toda ferramenta falhava no Android (crítico)**: o `GenyPlugin.invokeTool`
  resolvia com o objeto de outcome cru (`status/tool_id/data`) em vez do
  envelope `{ outcomeJson: "<json>" }` esperado pela camada web — no
  dispositivo, `JSON.parse(undefined)` produzia o erro
  `"undefined" is not valid JSON` e a UI mostrava "Ação falhou" para
  ferramentas que executavam de verdade (ex.: `apps.open` abria o app e
  depois reportava falha). O mock web cumpria o contrato, por isso os
  testes de browser não apanhavam o desvio. Correção: `OutcomeEnvelope`
  centraliza `ok/failed/denied` com `outcomeJson` serializado + `callId`,
  validado por testes JVM; teste de contrato do lado web varre o catálogo
  e garante `outcomeJson` parseável em todas as ferramentas.
  *Every tool call failed on Android (critical): `GenyPlugin.invokeTool`
  resolved with the raw outcome object instead of the `{ outcomeJson:
  "<json>" }` envelope the web layer expects — on device,
  `JSON.parse(undefined)` threw `"undefined" is not valid JSON` and the UI
  showed "failed" for tools that actually executed. The web mock honored
  the contract, so browser tests never caught it. Fixed with
  `OutcomeEnvelope` + JVM tests and a web-side contract test.*

## [0.1.0-alpha.2] — Correção do ecrã preto / Black-screen fix

### Corrigido / Fixed

- **Ecra preto ao abrir (crítico)**: o `#settings-drawer` tinha o atributo
  `hidden` no HTML, mas `display: flex` no CSS sobrepunha o `display: none`
  da folha de estilos do navegador — a gaveta vazia (380px, fundo escuro,
  `position: fixed`) cobria 92% do ecrã desde o arranque. Correção: regra
  global `[hidden] { display: none !important; }` + guarda de regressão.
  *Black screen on launch (critical): the settings drawer's `hidden`
  attribute was overridden by the author `display: flex` rule — an empty
  dark fixed panel covered the screen on startup. Fixed with a global
  `[hidden] { display: none !important; }` rule + regression guard.*
- **Chave i18n ausente**: `chat.placeholder` era usada no código mas não
  existia em nenhum locale — o campo de mensagem mostrava a chave crua.
  Adicionada nos 11 idiomas + testes de integridade (todos os locales com
  conjuntos de chaves idênticos; toda chave usada em código existe).
  *Missing i18n key `chat.placeholder` added to all 11 locales with
  integrity tests.*
- **`captureInput: true` removido** do config Capacitor: instala uma
  `BaseInputConnection` falsa que degrada a digitação do teclado na WebView.
  *Removed `captureInput: true` (fake input connection breaks IME typing).*
- **`webContentsDebuggingEnabled` omitido**: o default do Capacitor
  (`ligado em builds debug, desligado em release`) é o correto — antes o
  `false` explícito impedia inspecionar o APK debug via `chrome://inspect`.
  *Omitted explicit flag; Capacitor default (debug-builds-only) restored.*
- **CI reparado após majors do dependabot**: bumps major meseados
  (TypeScript 7, AGP 9, Kotlin 2.4, material/appcompat 1.14/1.8) quebravam
  `npm ci` (typescript-eslint 8 sem suporte a TS 7) e exigiriam Gradle 9.
  Revertidos para a combinação comprovada (TS 5.9.3, AGP 8.7.3, Kotlin
  2.0.21, material 1.12, appcompat 1.7); minors seguros mantidos (Vite 8,
  globals 17, thiserror 2, coroutines 1.9). Dependabot passa a ignorar
  majors até a migração deliberada (ver ROADMAP). *CI repaired after merged
  dependabot majors; risky majors reverted, safe minors kept, dependabot
  now ignores majors until the planned migration.*

### Adicionado / Added

- **APK release assinado em CI**: segredos `KEYSTORE_BASE64`,
  `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` + `signingConfig`
  condicional no Gradle e verificação com `apksigner` no workflow Release.
  Com fallback declarado: sem segredos, publica-se o APK debug como
  instalável da alpha. *Signed release APK via CI secrets with apksigner
  verification and declared debug fallback.*
- **Testes de regressão de UI/i18n**: 3 novos testes (guarda `[hidden]`,
  paridade de chaves entre locales, existência de chaves usadas no código).
  15 testes no app (antes 12).

## [0.1.0-alpha.1] — Fase 1: Fundação

### Adicionado / Added

- **Monorepo** com camadas separadas: `app/` (TypeScript), `android/` (Kotlin),
  `core/` (Rust), `tools/` (Lua), `scripts/`, `docs/`, `.github/`.
- **Núcleo Rust (`geny-core`)**: orquestrador com tool calling, registro e
  validação estrita de ferramentas, política de confirmação humana em 4 níveis
  (none/simple/explicit/authenticated), memória de longo prazo com
  exportação/importação JSON, i18n com 10 idiomas e suporte RTL, seleção
  dinâmica de backend (local/remoto/self-hosted). 37 testes unitários.
- **App web (TypeScript + Vite + Capacitor)**: chat com roteador de intenções
  offline (local-first), backend remoto compatível com OpenAI com injeção de
  catálogo de ferramentas, ponte `GenyBridge` com mock web, confirmação
  humana para ações sensíveis, i18n em 11 locales (pt-BR, pt-PT, en, es, fr,
  de, it, ru, zh-CN, ja, ar) com direção RTL, tema escuro/claro e
  acessibilidade. 12 testes.
- **Android (Kotlin)**: plugin Capacitor `GenyBridge` com 18 ferramentas
  (apps, dispositivo, comunicação, notificações, notas, localização,
  lembretes), confirmação nativa fail-safe com aprovação de uso único,
  `KeystoreManager` AES-256-GCM, `AuditLog` rotativo local, serviço em
  primeiro plano, overlay HUD arrastável, `NotificationListenerService`,
  `ModelManager` (download com SHA-256), `RemoteBackend` OpenAI-compat e
  `BackendSelector`. Persistência SQLite v0. 14 testes JVM.
- **Ferramentas Lua do usuário**: formato de manifesto com esquema de
  parâmetros e 3 exemplos (incluindo ferramenta root `authenticated`).
- **Scripts**: `bootstrap.sh`, `build-rust-android.sh`, `sync-web.sh`,
  `download-model.sh` (SHA-256), `setup-submodules.sh`.
- **CI/CD (GitHub Actions)**: `lint` (tsc/eslint/clippy/rustfmt/gradle
  lint/luacheck), `test` (vitest/cargo/gradle), `build-native` (Rust para
  arm64-v8a, armeabi-v7a, x86_64 via NDK r27), `build-apk` (web → assets →
  APK debug com artefato), `release` (tags v*, fallback alpha) e dependabot.
- **Documentação**: especificação técnica completa v1.0, guias de arquitetura,
  build, segurança e tool calling, docs de usuário (início e privacidade),
  templates de issue/PR, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY.

### Decisões / Decisions

- Licença **Apache-2.0** (permissiva com concessão de patentes; compatível
  com as dependências MIT do ecossistema llama.cpp/whisper.cpp/Piper/ONNX).
- Persistência v0 com `SQLiteOpenHelper` — migração para Room + KSP fica
  para a Fase 3 (`android-04`) para manter o build alpha simples.
- Sem submodules clonados por padrão — `scripts/setup-submodules.sh` baixa
  sob demanda com versões pinadas (build determinista).
