# Voz — falar com a Geny / Voice — talking to Geny

> **PT** Guia do modo de voz (Fase 2): captura em contexto, reconhecimento
> on-device (sistema ou whisper.cpp) e respostas faladas. Tudo roda no
> aparelho — nenhum áudio sai do dispositivo.
> **EN** Voice mode guide (Phase 2): in-context capture, on-device
> recognition (system or whisper.cpp) and spoken replies. Everything runs on
> the device — no audio ever leaves it.

---

## PT — Português

### 1. Primeiro uso

1. Toque no botão de microfone 🎤 ao lado do campo de mensagem.
2. O Android pergunta **“Permitir que o Geny Assistant grave áudio?”** — a
   permissão é pedida **só nesse momento** (em contexto), nunca ao abrir o
   app. É a política do §14 da especificação técnica.
3. Fale normalmente: o painel mostra o nível do microfone e a transcrição
   ao vivo.
4. Toque em **Parar** (ou desative “encerrar automático”) e a transcrição
   vira mensagem no chat — a Geny responde normalmente.

### 2. Motores de reconhecimento (STT)

Configurações → **Voz** → *Reconhecimento de fala (STT)*:

| Motor | O que é | Quando usar |
|---|---|---|
| **Sistema (on-device)** | `SpeechRecognizer` do Android 12+ em modo *on-device* (`createOnDeviceSpeechRecognizer`); em versões anteriores usa `EXTRA_PREFER_OFFLINE` | Padrão. Sem download, funciona de fábrica na maioria dos aparelhos |
| **Whisper local** | whisper.cpp compilado no app + modelo GGML baixado sob demanda (Tiny/Base/Small/Medium) | Máxima privacidade e controle; aparelhos sem pacote de voz do sistema |

**Modelos Whisper**: baixados em *Voz → Modelo Whisper* com verificação de
integridade SHA-256 pinada. Tiny (~74 MB) é o mais rápido; Medium (~1,4 GB)
é o mais preciso — exige aparelho robusto. Nenhum modelo vem dentro do APK
e nenhum é enviado para a nuvem.

### 3. VAD — fim de fala automático

A detecção de atividade de voz (VAD) usa **energia RMS** (sempre disponível)
ou **Silero v5 via ONNX Runtime** (quando o modelo de ~2 MB é baixado — mais
preciso em ambientes barulhentos). Com “Encerrar quando eu parar de falar”
ligado, a gravação termina sozinha ao final da frase.

### 4. Responder por voz (TTS)

Configurações → **Voz** → *Responder por voz*: as respostas da Geny são
faladas pelo motor TTS do sistema (vozes on-device). A reprodução acontece
num **serviço em primeiro plano** com notificação e botão de parar — a fala
continua mesmo se você trocar de app. Cada resposta também tem um botão 🔊
para reproduzir de novo.

Idiomas priorizados na Fase 2: **pt-BR, pt-PT e en**. Outros idiomas usam a
voz instalada mais próxima.

### 5. Privacidade

- Áudio processado só no aparelho; nunca enviado para servidores.
- Modelos ficam no armazenamento privado do app (`filesDir/models`).
- A permissão de microfone pode ser revogada a qualquer momento nas
  configurações do Android — a Geny avisa e segue funcionando por texto.

---

## EN — English

### 1. First use

1. Tap the microphone button 🎤 next to the message field.
2. Android asks **“Allow Geny Assistant to record audio?”** — the permission
   is requested **only at that moment** (in context), never on app launch.
   That is the §14 policy of the technical specification.
3. Speak normally: the panel shows the mic level and a live transcript.
4. Tap **Stop** (or turn off auto-stop) and the transcript becomes a chat
   message — Geny replies as usual.

### 2. Recognition engines (STT)

Settings → **Voice** → *Speech recognition (STT)*:

| Engine | What it is | When to use |
|---|---|---|
| **System (on-device)** | Android 12+ `SpeechRecognizer` in on-device mode (`createOnDeviceSpeechRecognizer`); earlier versions use `EXTRA_PREFER_OFFLINE` | Default. No download, works out of the box on most devices |
| **Local Whisper** | whisper.cpp compiled into the app + GGML model downloaded on demand (Tiny/Base/Small/Medium) | Maximum privacy and control; devices without the system voice package |

**Whisper models**: downloaded under *Voice → Whisper model* with pinned
SHA-256 integrity verification. Tiny (~74 MB) is the fastest; Medium
(~1.4 GB) is the most accurate — needs a capable device. No model ships
inside the APK and none ever goes to the cloud.

### 3. VAD — automatic end of speech

Voice activity detection uses **RMS energy** (always available) or **Silero
v5 via ONNX Runtime** (once the ~2 MB model is downloaded — more accurate in
noisy places). With “Stop when I stop speaking” enabled, recording ends on
its own at the end of the utterance.

### 4. Voice replies (TTS)

Settings → **Voice** → *Reply by voice*: Geny’s replies are spoken by the
system TTS engine (on-device voices). Playback happens in a **foreground
service** with a notification and a stop button — speech survives app
switches. Every reply also has a 🔊 button to play it again.

Phase-2 languages first: **pt-BR, pt-PT and en**. Other languages fall back
to the closest installed voice.

### 5. Privacy

- Audio is processed on the device only; never uploaded.
- Models live in the app’s private storage (`filesDir/models`).
- The microphone permission can be revoked anytime in Android settings —
  Geny notifies you and keeps working by text.
