// geny_llama_jni.cpp — JNI bindings do llama.cpp (docs §6, TODO core-05/05b).
//
// PT: expõe init/free/generate para LlmJni.kt. O modelo GGUF é baixado sob
// demanda (nunca embutido no APK). O prompt é montado com o template de chat
// do próprio modelo (llama_chat_apply_template com tmpl=nullptr lê o template
// do GGUF), decodificado em blocos e amostrado (greedy quando temperature
// <= 0; top-p + temp + dist caso contrário). Duas variantes de geração
// compartilham o mesmo núcleo: `nativeGenerate` (resposta completa) e
// `nativeGenerateStream` (chama `TokenCallback.onToken` a cada peça gerada,
// TODO core-05b). `nativeCancel` aborta a geração em andamento — o loop
// consulta a flag atômica do handle entre tokens e o JSON devolvido traz
// "stopped":true quando a parada foi pedida.
// EN: exposes init/free/generate to LlmJni.kt. The GGUF model is downloaded
// on demand (never bundled in the APK). The prompt is formatted with the
// model's own chat template (llama_chat_apply_template with tmpl=nullptr
// reads the GGUF template), decoded in chunks and sampled (greedy when
// temperature <= 0; otherwise top-p + temp + dist). Two generation variants
// share the same core: `nativeGenerate` (full reply) and
// `nativeGenerateStream` (invokes `TokenCallback.onToken` per generated
// piece, TODO core-05b). `nativeCancel` aborts the running generation — the
// loop checks the handle's atomic flag between tokens and the returned JSON
// carries "stopped":true when a stop was requested.

#include <jni.h>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
#include <vector>
#include <android/log.h>
#include "llama.h"

#define GENY_LOG_TAG "geny-llama"
#define GENY_LOGI(...) __android_log_print(ANDROID_LOG_INFO, GENY_LOG_TAG, __VA_ARGS__)
#define GENY_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, GENY_LOG_TAG, __VA_ARGS__)

namespace {

struct LlamaHandle {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    // Flag de cancelamento consultada entre tokens (nativeCancel).
    std::atomic<bool> cancelled{false};
};

std::string jstringToStd(JNIEnv *env, jstring s) {
    if (s == nullptr) return {};
    const char *raw = env->GetStringUTFChars(s, nullptr);
    if (raw == nullptr) return {};
    std::string out(raw);
    env->ReleaseStringUTFChars(s, raw);
    return out;
}

std::string jsonEscape(const std::string &in) {
    std::string out;
    out.reserve(in.size() + 16);
    for (unsigned char c : in) {
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                } else {
                    out += static_cast<char>(c); // UTF-8 passa direto
                }
        }
    }
    return out;
}

// Concatena as mensagens (system + histórico) num vetor de llama_chat_message.
std::vector<llama_chat_message> buildMessages(JNIEnv *env, jstring system,
                                              jobjectArray roles,
                                              jobjectArray contents) {
    std::vector<llama_chat_message> msgs;
    const std::string sys = jstringToStd(env, system);
    if (!sys.empty()) {
        // system é sempre a primeira mensagem (role fixo, content é cópia)
        char *sysCopy = strdup(sys.c_str());
        msgs.push_back({"system", sysCopy});
    }
    if (roles != nullptr && contents != nullptr) {
        const jsize n = env->GetArrayLength(roles);
        for (jsize i = 0; i < n; ++i) {
            auto role = (jstring) env->GetObjectArrayElement(roles, i);
            auto content = (jstring) env->GetObjectArrayElement(contents, i);
            const std::string r = jstringToStd(env, role);
            const std::string c = jstringToStd(env, content);
            if (role != nullptr) env->DeleteLocalRef(role);
            if (content != nullptr) env->DeleteLocalRef(content);
            if (r.empty() || c.empty()) continue;
            char *rCopy = strdup(r.c_str());
            char *cCopy = strdup(c.c_str());
            msgs.push_back({rCopy, cCopy});
        }
    }
    return msgs;
}

} // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_carsaimz_genyassistant_ai_LlmJni_nativeInit(
        JNIEnv *env, jobject /*thiz*/, jstring model_path, jint context_tokens,
        jint threads) {
    const std::string path = jstringToStd(env, model_path);
    if (path.empty()) return 0;

    // Inicialização global do backend (idempotente — uma vez por processo).
    static bool backend_ready = []() {
        llama_backend_init();
        return true;
    }();
    (void) backend_ready;

    llama_model_params mparams = llama_model_default_params();
    mparams.load_mode = LLAMA_LOAD_MODE_MMAP; // menos RAM residente em aparelhos limitados
    struct llama_model *model = llama_model_load_from_file(path.c_str(), mparams);
    if (model == nullptr) {
        GENY_LOGE("falha ao carregar modelo GGUF");
        return 0;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = static_cast<uint32_t>(context_tokens > 0 ? context_tokens : 2048);
    cparams.n_batch = 512;
    cparams.n_ubatch = 512;
    cparams.n_threads = threads > 0 ? threads : 4;
    cparams.n_threads_batch = threads > 0 ? threads : 4;
    struct llama_context *ctx = llama_init_from_model(model, cparams);
    if (ctx == nullptr) {
        GENY_LOGE("falha ao criar contexto");
        llama_model_free(model);
        return 0;
    }

    auto *handle = new LlamaHandle{model, ctx};
    GENY_LOGI("modelo pronto (n_ctx=%u threads=%d)", llama_n_ctx(ctx), threads);
    return reinterpret_cast<jlong>(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_carsaimz_genyassistant_ai_LlmJni_nativeFree(
        JNIEnv * /*env*/, jobject /*thiz*/, jlong ptr) {
    if (ptr == 0) return;
    auto *handle = reinterpret_cast<LlamaHandle *>(ptr);
    if (handle->ctx != nullptr) llama_free(handle->ctx);
    if (handle->model != nullptr) llama_model_free(handle->model);
    delete handle;
}

// Núcleo compartilhado de geração: monta o template, tokeniza, amostra e
// decodifica. `onToken` (pode ser null) recebe cada peça gerada — usado pelo
// streaming (TODO core-05b). Devolve o JSON de resultado (ou {"error":…}).
// Shared generation core: formats the template, tokenizes, samples and
// decodes. `onToken` (nullable) receives each generated piece — used by the
// streaming path (TODO core-05b). Returns the result JSON (or {"error":…}).
std::string runGeneration(JNIEnv *env, LlamaHandle *handle, jstring system,
                          jobjectArray roles, jobjectArray contents,
                          jint max_tokens, jfloat temperature, jfloat top_p,
                          jint seed,
                          const std::function<void(const std::string &)> &onToken) {
    std::vector<llama_chat_message> msgs = buildMessages(env, system, roles, contents);
    if (msgs.empty()) return "{\"error\":\"sem_mensagens\"}";

    // 1) Template de chat do próprio modelo (tmpl=nullptr → lê do GGUF).
    size_t total_chars = 0;
    for (const auto &m : msgs) total_chars += strlen(m.content) + strlen(m.role) + 8;
    std::vector<char> fmt(2 * total_chars + 256);
    int32_t n_formatted = llama_chat_apply_template(
            nullptr, msgs.data(), msgs.size(), true, fmt.data(),
            static_cast<int32_t>(fmt.size()));
    // Cópia dos buffers: buildMessages usou strdup; libera ao final.
    for (auto &m : msgs) {
        free(const_cast<char *>(m.role));
        free(const_cast<char *>(m.content));
    }
    if (n_formatted < 0) {
        GENY_LOGE("chat template falhou");
        return "{\"error\":\"template\"}";
    }
    std::string prompt(fmt.data(), static_cast<size_t>(n_formatted));

    const llama_vocab *vocab = llama_model_get_vocab(handle->model);

    // 2) Tokenização do prompt (add_special=false: o template já tem especiais).
    const int n_prompt_max = llama_n_ctx(handle->ctx) - 8;
    std::vector<llama_token> tokens(static_cast<size_t>(n_prompt_max));
    int n_prompt = llama_tokenize(vocab, prompt.c_str(),
                                  static_cast<int32_t>(prompt.size()),
                                  tokens.data(), n_prompt_max, false, true);
    if (n_prompt <= 0) {
        GENY_LOGE("tokenizacao falhou ou contexto cheio (n=%d)", n_prompt);
        return "{\"error\":\"tokenizacao\"}";
    }
    tokens.resize(static_cast<size_t>(n_prompt));

    // 3) Sampler: greedy (determinístico) ou top-p + temp + dist.
    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler *smpl = llama_sampler_chain_init(sparams);
    if (temperature <= 0.0f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(top_p > 0.0f ? top_p : 0.9f, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(seed > 0 ? static_cast<uint32_t>(seed) : LLAMA_DEFAULT_SEED));
    }

    // 4) Decodificação do prompt em blocos + geração autoregressiva.
    llama_memory_clear(llama_get_memory(handle->ctx), true);
    handle->cancelled.store(false);
    const auto started = std::chrono::steady_clock::now();

    std::string text;
    bool stopped = false;
    int n_generated = 0;
    const size_t n_batch = 512;

    for (size_t i = 0; i < tokens.size(); i += n_batch) {
        if (handle->cancelled.load()) { stopped = true; break; }
        const size_t chunk = std::min(n_batch, tokens.size() - i);
        if (llama_decode(handle->ctx,
                         llama_batch_get_one(&tokens[i], static_cast<int32_t>(chunk))) != 0) {
            llama_sampler_free(smpl);
            GENY_LOGE("decode do prompt falhou");
            return "{\"error\":\"decode\"}";
        }
    }

    if (!stopped) {
        const int max_new = max_tokens > 0 ? max_tokens : 256;
        char piece[64];
        while (n_generated < max_new) {
            if (handle->cancelled.load()) { stopped = true; break; }
            llama_token tok = llama_sampler_sample(smpl, handle->ctx, -1);
            if (llama_vocab_is_eog(vocab, tok)) break;
            llama_sampler_accept(smpl, tok);

            const int n_piece = llama_token_to_piece(vocab, tok, piece, sizeof(piece), 0, false);
            if (n_piece > 0) {
                text.append(piece, static_cast<size_t>(n_piece));
                if (onToken) onToken(std::string(piece, static_cast<size_t>(n_piece)));
            }

            if (llama_decode(handle->ctx, llama_batch_get_one(&tok, 1)) != 0) break;
            n_generated++;
        }
    }
    llama_sampler_free(smpl);

    const long ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                            std::chrono::steady_clock::now() - started)
                            .count();
    GENY_LOGI("geracao ok: %d tokens em %ld ms (stopped=%d)", n_generated, ms,
              stopped ? 1 : 0);

    std::string json = "{\"text\":\"" + jsonEscape(text) + "\",\"tokens\":" +
                       std::to_string(n_generated) + ",\"ms\":" + std::to_string(ms) +
                       ",\"stopped\":" + (stopped ? "true" : "false") + "}";
    return json;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_carsaimz_genyassistant_ai_LlmJni_nativeGenerate(
        JNIEnv *env, jobject /*thiz*/, jlong ptr, jstring system,
        jobjectArray roles, jobjectArray contents, jint max_tokens,
        jfloat temperature, jfloat top_p, jint seed) {
    if (ptr == 0) return env->NewStringUTF("{\"error\":\"nao_carregado\"}");
    auto *handle = reinterpret_cast<LlamaHandle *>(ptr);
    const std::string json = runGeneration(env, handle, system, roles, contents,
                                           max_tokens, temperature, top_p, seed,
                                           nullptr);
    return env->NewStringUTF(json.c_str());
}

// TokenCallback.onToken(String) — resolvido uma vez por chamada de streaming.
extern "C" JNIEXPORT jstring JNICALL
Java_com_carsaimz_genyassistant_ai_LlmJni_nativeGenerateStream(
        JNIEnv *env, jobject /*thiz*/, jlong ptr, jstring system,
        jobjectArray roles, jobjectArray contents, jint max_tokens,
        jfloat temperature, jfloat top_p, jint seed, jobject callback) {
    if (ptr == 0) return env->NewStringUTF("{\"error\":\"nao_carregado\"}");
    auto *handle = reinterpret_cast<LlamaHandle *>(ptr);
    if (callback == nullptr) {
        const std::string json = runGeneration(env, handle, system, roles, contents,
                                               max_tokens, temperature, top_p, seed,
                                               nullptr);
        return env->NewStringUTF(json.c_str());
    }

    jclass cbClass = env->GetObjectClass(callback);
    if (cbClass == nullptr) return env->NewStringUTF("{\"error\":\"callback\"}");
    jmethodID onTokenMethod = env->GetMethodID(cbClass, "onToken", "(Ljava/lang/String;)V");
    env->DeleteLocalRef(cbClass);
    if (onTokenMethod == nullptr) {
        GENY_LOGE("TokenCallback.onToken nao encontrado");
        return env->NewStringUTF("{\"error\":\"callback\"}");
    }

    // O callback roda na MESMA thread da geração (executor dedicado do
    // Kotlin) — a JNIEnv passada é válida durante toda a chamada. Cada
    // jstring criada é liberada na hora: gerações longas estourariam a
    // tabela de local refs.
    // The callback runs on the SAME thread as generation (Kotlin's dedicated
    // executor) — the JNIEnv passed in stays valid for the whole call. Each
    // created jstring is released immediately: long generations would blow
    // the local-ref table.
    auto onToken = [&](const std::string &piece) {
        jstring jpiece = env->NewStringUTF(piece.c_str());
        if (jpiece == nullptr) return; // OOM: segue sem streaming deste token
        env->CallVoidMethod(callback, onTokenMethod, jpiece);
        env->DeleteLocalRef(jpiece);
        if (env->ExceptionCheck()) {
            env->ExceptionClear(); // a UI nunca derruba a geração
        }
    };

    const std::string json = runGeneration(env, handle, system, roles, contents,
                                           max_tokens, temperature, top_p, seed,
                                           onToken);
    return env->NewStringUTF(json.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_carsaimz_genyassistant_ai_LlmJni_nativeCancel(
        JNIEnv * /*env*/, jobject /*thiz*/, jlong ptr) {
    if (ptr == 0) return;
    auto *handle = reinterpret_cast<LlamaHandle *>(ptr);
    handle->cancelled.store(true);
}
