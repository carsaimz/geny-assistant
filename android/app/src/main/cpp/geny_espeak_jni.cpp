// geny_espeak_jni.cpp — fonemização IPA via espeak-ng (TODO core-03, Piper).
//
// PT: wrapper mínimo sobre a API do espeak-ng (submodule pinado
// native/espeak-ng @ ed530aa, o mesmo pin do sherpa-onnx) para o PiperTts:
// init com o caminho do espeak-ng-data (baixado sob demanda), seleção de voz
// e conversão texto → fonemas IPA com pontuação por oração. O núcleo
// (geny_espeak_*) replica o algoritmo do piper-phonemize: por oração,
// espeak_TextToPhonemesWithTerminator com phonememode IPA (0x02), filtro de
// marcadores de troca de idioma "(en)", pontuação pelo terminador
// (CLAUSE_* de translate.h) e espaço extra após vírgula/dois
// pontos/ponto-e-vírgula. A decomposição NFD e o mapeamento para IDs do
// modelo ficam no Kotlin (PiperTtsEngine) — aqui só o espeak fala.
// EN: minimal wrapper over the espeak-ng API (pinned submodule
// native/espeak-ng @ ed530aa, same pin as sherpa-onnx) for PiperTts: init
// with the espeak-ng-data path (downloaded on demand), voice selection and
// text → IPA phonemes with per-clause punctuation. The core (geny_espeak_*)
// mirrors piper-phonemize's algorithm: per clause,
// espeak_TextToPhonemesWithTerminator with IPA phonememode (0x02), language
// switch flag "(en)" filtering, punctuation from the terminator (CLAUSE_*
// from translate.h) and extra space after comma/colon/semicolon. NFD
// decomposition and model ID mapping live in Kotlin (PiperTtsEngine) — only
// espeak speaks here.

#include <jni.h>
#include <android/log.h>
#include <string>
#include <cstring>

#include <espeak-ng/speak_lib.h>
#include "translate.h" // CLAUSE_* (src/libespeak-ng)

#define GENY_LOG_TAG "geny-espeak"
#define GENY_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, GENY_LOG_TAG, __VA_ARGS__)

namespace {

bool g_initialized = false;

// Máximo de orações por chamada — rede de segurança contra loops infinitos
// em textos patológicos (espeak devolve textptr=NULL no fim; nunca chegamos
// perto disso em respostas de assistente).
constexpr int kMaxClauses = 4096;

} // namespace

// ------------------------------------------------------------- core (test) --

extern "C" int geny_espeak_init(const char *data_path) {
    if (g_initialized) return 0;
    if (data_path == nullptr) return -1;
    // SYNCHRONOUS: não abre áudio — só queremos fonemas (o áudio é do VITS).
    // Retorno: sample rate em Hz (positivo = ok) ou EE_INTERNAL_ERROR.
    // Return: sample rate in Hz (positive = ok) or EE_INTERNAL_ERROR.
    if (espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, 0, data_path, 0) < 0) {
        GENY_LOGE("espeak_Initialize falhou (data=%s)", data_path);
        return -1;
    }
    g_initialized = true;
    return 0;
}

extern "C" int geny_espeak_set_voice(const char *voice) {
    if (!g_initialized || voice == nullptr) return -1;
    if (espeak_SetVoiceByName(voice) == EE_OK) return 0;
    // Fallback: propriedades por idioma (ex.: "pt" sem região).
    espeak_VOICE spec;
    std::memset(&spec, 0, sizeof(spec));
    spec.languages = voice;
    if (espeak_SetVoiceByProperties(&spec) != EE_OK) {
        GENY_LOGE("espeak_SetVoice falhou (%s)", voice);
        return -1;
    }
    return 0;
}

// Texto → fonemas IPA com pontuação por oração (algoritmo do piper).
// Text → IPA phonemes with per-clause punctuation (piper's algorithm).
extern "C" std::string geny_espeak_phonemize(const std::string &text) {
    std::string out;
    if (!g_initialized || text.empty()) return out;
    std::string copy = text;
    const char *ptr = copy.c_str();
    int terminator = 0;

    for (int clause = 0; ptr != nullptr && clause < kMaxClauses; ++clause) {
        const char *phonemes = espeak_TextToPhonemesWithTerminator(
                reinterpret_cast<const void **>(&ptr),
                /*textmode=*/espeakCHARS_AUTO,
                /*phonememode=*/espeakPHONEMES_IPA,
                &terminator);
        if (phonemes == nullptr) break;

        // Filtro de marcadores de idioma: "(pt)" do espeak não é fonema.
        bool in_flag = false;
        for (const char *p = phonemes; *p != '\0'; ++p) {
            const char c = *p;
            if (in_flag) {
                if (c == ')') in_flag = false;
            } else if (c == '(') {
                in_flag = true;
            } else {
                out.push_back(c);
            }
        }

        // Pontuação do terminador (mesma tabela do piper-phonemize).
        const int punctuation = terminator & 0x000FFFFF;
        if (punctuation == CLAUSE_PERIOD) {
            out.push_back('.');
        } else if (punctuation == CLAUSE_QUESTION) {
            out.push_back('?');
        } else if (punctuation == CLAUSE_EXCLAMATION) {
            out.push_back('!');
        } else if (punctuation == CLAUSE_COMMA) {
            out.push_back(',');
            out.push_back(' ');
        } else if (punctuation == CLAUSE_COLON) {
            out.push_back(':');
            out.push_back(' ');
        } else if (punctuation == CLAUSE_SEMICOLON) {
            out.push_back(';');
            out.push_back(' ');
        }
    }
    return out;
}

extern "C" void geny_espeak_terminate() {
    if (!g_initialized) return;
    espeak_Terminate();
    g_initialized = false;
}

// -------------------------------------------------------------- JNI shell --

extern "C" JNIEXPORT jboolean JNICALL
Java_com_carsaimz_genyassistant_voice_EspeakPhonemizer_nativeInit(
        JNIEnv *env, jobject /*thiz*/, jstring data_path) {
    if (data_path == nullptr) return JNI_FALSE;
    const char *raw = env->GetStringUTFChars(data_path, nullptr);
    if (raw == nullptr) return JNI_FALSE;
    const int rc = geny_espeak_init(raw);
    env->ReleaseStringUTFChars(data_path, raw);
    return rc == 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_carsaimz_genyassistant_voice_EspeakPhonemizer_nativeSetVoice(
        JNIEnv *env, jobject /*thiz*/, jstring voice) {
    if (voice == nullptr) return JNI_FALSE;
    const char *raw = env->GetStringUTFChars(voice, nullptr);
    if (raw == nullptr) return JNI_FALSE;
    const int rc = geny_espeak_set_voice(raw);
    env->ReleaseStringUTFChars(voice, raw);
    return rc == 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_carsaimz_genyassistant_voice_EspeakPhonemizer_nativePhonemize(
        JNIEnv *env, jobject /*thiz*/, jstring text) {
    if (text == nullptr) return env->NewStringUTF("");
    const char *raw = env->GetStringUTFChars(text, nullptr);
    if (raw == nullptr) return env->NewStringUTF("");
    const std::string phonemes = geny_espeak_phonemize(std::string(raw));
    env->ReleaseStringUTFChars(text, raw);
    return env->NewStringUTF(phonemes.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_carsaimz_genyassistant_voice_EspeakPhonemizer_nativeTerminate(
        JNIEnv * /*env*/, jobject /*thiz*/) {
    geny_espeak_terminate();
}
