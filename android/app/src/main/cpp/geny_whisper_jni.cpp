// geny_whisper_jni.cpp — JNI bindings do whisper.cpp (docs §7.2, TODO core-02).
//
// PT: expõe init/free/transcribe para WhisperJni.kt. O modelo GGML é baixado
// sob demanda (nunca embutido no APK). PCM de entrada: float mono 16 kHz em
// [-1, 1]. Saída: texto concatenado dos segmentos.
// EN: exposes init/free/transcribe to WhisperJni.kt. The GGML model is
// downloaded on demand (never bundled in the APK). Input PCM: float mono
// 16 kHz in [-1, 1]. Output: concatenated segment text.

#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include "whisper.h"

#define GENY_LOG_TAG "geny-whisper"
#define GENY_LOGI(...) __android_log_print(ANDROID_LOG_INFO, GENY_LOG_TAG, __VA_ARGS__)
#define GENY_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, GENY_LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jlong JNICALL
Java_com_carsaimz_genyassistant_voice_WhisperJni_nativeInit(
        JNIEnv *env, jobject /*thiz*/, jstring model_path, jint threads) {
    if (model_path == nullptr) return 0;

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    if (path == nullptr) return 0;

    struct whisper_context_params params = whisper_context_default_params();
    params.use_gpu = false; // Fase 10: avaliar GPU; CPU é o caminho determinístico
    struct whisper_context *ctx = whisper_init_from_file_with_params(path, params);
    env->ReleaseStringUTFChars(model_path, path);

    if (ctx == nullptr) {
        GENY_LOGE("falha ao carregar modelo");
        return 0;
    }
    GENY_LOGI("modelo carregado (threads=%d)", (int) threads);
    return reinterpret_cast<jlong>(ctx);
}

extern "C" JNIEXPORT void JNICALL
Java_com_carsaimz_genyassistant_voice_WhisperJni_nativeFree(
        JNIEnv * /*env*/, jobject /*thiz*/, jlong ptr) {
    if (ptr == 0) return;
    struct whisper_context *ctx = reinterpret_cast<struct whisper_context *>(ptr);
    whisper_free(ctx);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_carsaimz_genyassistant_voice_WhisperJni_nativeTranscribe(
        JNIEnv *env, jobject /*thiz*/, jlong ptr, jfloatArray samples,
        jstring language, jint threads) {
    if (ptr == 0 || samples == nullptr) return env->NewStringUTF("");

    struct whisper_context *ctx = reinterpret_cast<struct whisper_context *>(ptr);

    const jsize n = env->GetArrayLength(samples);
    if (n <= 0) return env->NewStringUTF("");
    std::vector<float> pcm(static_cast<size_t>(n));
    env->GetFloatArrayRegion(samples, 0, n, pcm.data());

    // Copia o idioma ANTES de liberar a string JNI (evita ponteiro solto).
    std::string lang("auto");
    if (language != nullptr) {
        const char *raw = env->GetStringUTFChars(language, nullptr);
        if (raw != nullptr) {
            lang = raw;
            env->ReleaseStringUTFChars(language, raw);
        }
    }

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = threads > 0 ? threads : 2;
    params.language = lang.c_str(); // "auto" dispara detecção de idioma
    params.print_progress = false;
    params.print_special = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.single_segment = false;
    params.translate = false;
    params.no_context = true;

    if (whisper_full(ctx, params, pcm.data(), static_cast<int>(pcm.size())) != 0) {
        GENY_LOGE("whisper_full falhou");
        return env->NewStringUTF("");
    }

    std::string text;
    const int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        const char *seg = whisper_full_get_segment_text(ctx, i);
        if (seg != nullptr) text += seg;
    }
    return env->NewStringUTF(text.c_str());
}
