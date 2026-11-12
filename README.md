<div align="center">

# ✨ Geny

### **Your Private, Multilingual, On-Device AI Assistant — for Android**
*Female voice · Speaks English, Português, Français, Español · Runs offline*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Release](https://img.shields.io/badge/Release-v2.0.0-8B5CF6?style=for-the-badge&logo=github)](../../releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-No%20Telemetry-22C55E?style=for-the-badge&logo=shield&logoColor=white)](#-privacy--security)
[![CI](https://img.shields.io/badge/Build-GitHub%20Actions-2088FF?style=the-badge&logo=githubactions&logoColor=white)](.github/workflows)

<p align="center">
  <b><i>"Your keys. Your data. Your device. Nothing leaves your phone except the AI calls you configure."</i></b>
</p>

</div>

---

## 🌟 What is Geny?

**Geny** is a next-generation personal AI assistant for Android, with a warm **female voice and personality**. She listens hands-free, speaks your language, controls your phone, automates apps — and can run **100% offline** with an on-device AI model downloaded inside the app.

Geny is the evolution of the open-source **J.A.R.V.I.S. PrivateAgent** project, rebuilt with:

| | |
|---|---|
| 🗣️ **Multilingual** | Full UI + conversation in **English, Português, Français, Español** — speech recognition and studio neural voices in your language |
| 🎀 **Female voice by default** | Ultra-realistic neural voices (Sonia, Francisca, Denise, Elvira...) plus custom assistant **name** and **voice** picker |
| 🧠 **Offline AI models** | Download a **light (~0.55 GB)** or **heavy (~2.5 GB)** model inside the app (Gemma 3 via MediaPipe GenAI) and chat with **zero internet** |
| 🤖 **Autonomous agent** | Reads the screen (accessibility service) and performs taps, swipes and typing to complete real tasks |
| 🔒 **Privacy-first** | No telemetry, no trackers, no hidden endpoints. Security-audited: cleartext traffic blocked except localhost, secrets excluded from backups, unused dangerous permissions removed |
| 📡 **Optional bridges** | Your own Telegram bot (remote control), your own LLM API key (DeepSeek/OpenAI/Gemini/OpenRouter/NVIDIA/Ollama), your own Home Assistant |

---

## ✨ Feature Highlights

### Voice & Language Studio
- **Choose Geny's name** and **your name** (how she calls you)
- **Voice picker** with female/male neural voices per language + live preview
- **Offline voices**: one tap to open the system voice-data downloader
- Hands-free "Hey Geny" continuous listening (opt-in)
- Multilingual STT: recognition locale follows the app language (pt-BR, fr-FR, es-ES...)

### On-Device AI (Offline Mode)
- In-app **Model Manager**: light (fast, every phone) vs heavy (flagships) models
- Streamed download with progress, delete, custom `.task` model URL support
- Once downloaded, **chat works with the phone in airplane mode**
- Powered by MediaPipe GenAI (LiteRT) — inference stays on your chip

### Autonomous Device Agent
- Observe → think → act loop over the Android screen hierarchy
- Opens apps, searches, plays media, fills forms, sends drafted messages
- Multi-task "brain dump" parsing, workflow macros, self-evolving Hermes engine (SOUL/USER/AGENT memory)

### Iron-Man-Style Extras
- 3D hologram HUD (Arc Reactor / genie avatar), floating bubble co-pilot
- Air gestures, charging telemetry HUD, sound radar, airspace radar
- Sentry anti-theft mode (motion → front-camera alert to your own Telegram)
- Network audit, Code Black lockout, smart home via Home Assistant

---

## 🚀 Getting Started

### Build from source
```bash
git clone https://github.com/carsaimz/geny-assistant.git
cd geny-assistant
flutter pub get
flutter run            # or: flutter build apk --release
```
Requirements: Flutter (stable), Android SDK 35, Java 17.

### Download a ready APK
Every tag triggers a GitHub Actions release build — grab `Geny-<version>-release.apk` from [Releases](../../releases).

### First run
1. Pick your **language** on the welcome screen
2. (Optional) enable **Screen Control** in Accessibility settings
3. Connect an AI provider with your own API key — **or** open **Offline AI Models** and download the light model
4. Talk to her: *"Good morning"*, *"play lofi on YouTube"*, *"que horas são?"*, *"quel temps fait-il ?"*

---

## ⚙️ AI Providers

| Provider | Base URL | Key |
|---|---|---|
| DeepSeek (default) | `https://api.deepseek.com/v1` | yours |
| OpenAI | `https://api.openai.com/v1` | yours |
| Google Gemini | OpenAI-compatible endpoint | yours |
| OpenRouter | `https://openrouter.ai/api/v1` | yours |
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | yours |
| Ollama (local) | `http://127.0.0.1:11434/v1` | none |
| **Offline model** | on-device | none |

---

## 🔒 Privacy & Security

Geny is **audited**: an exhaustive review of every service file, the Kotlin layer and the manifest found **no telemetry SDKs, no trackers, no hidden exfiltration**. Hardening applied in this version:

- **Cleartext HTTP is blocked globally** (network security config) — only `127.0.0.1`/`localhost` (Ollama) and `homeassistant.local` are exempt
- **`allowBackup=false`** — API keys and bot tokens never leave the device via Android cloud backup
- **Telegram pairing hardened** — the first stranger who messages your bot can no longer claim ownership; you authorize your Chat ID explicitly in Settings
- **Removed unused dangerous permissions**: `RECEIVE_SMS`, `SEND_SMS`, `WRITE_CONTACTS`; removed dead Shizuku privileged-shell code
- **Honest Sentry speech** and opt-in cloud TTS (offline TTS fallback built-in)
- Smart-home calls are skipped until you actually configure Home Assistant

Data goes **only** where you configure: your LLM provider, your Telegram bot, your smart home. That's it.

---

## 🏗️ Project Structure

```
lib/
├── i18n/                  # EN/PT/FR/ES string catalog
├── models/                # chat, tasks, screen nodes, skills
├── screens/               # home, onboarding, settings, history, security
├── services/              # 50 services: AI, voice, models, agent, tools...
├── widgets/               # liquid-glass HUD components
├── overlay/               # floating bubble app
└── theme/                 # Geny violet-fuchsia design system
android/.../kotlin/
├── MainActivity.kt        # voice channels, sensors, local-LLM bridge
├── GenyLocalLlm.kt        # MediaPipe GenAI on-device inference
├── AgentAccessibilityService.kt
└── InboxNotificationListenerService.kt
.github/workflows/         # CI + release builds
```

---

## 🙌 Credits

Geny is built on the excellent open-source **J.A.R.V.I.S. (PrivateAgent)** project by **Abuzar (AbuZar-Ansarii)** — original architecture, agent loop and Iron-Man feature set by him, under the MIT license. Rebranded, multilingualized, security-hardened and extended with offline on-device AI by the Geny project.

## 📄 License

MIT — see [LICENSE](LICENSE).
