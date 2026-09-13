package com.carsaimz.genyassistant.ai

/**
 * Catálogo de modelos LLM locais (Fase 3 — docs §6, TODO core-05).
 *
 * **PT** Nenhum modelo é embutido no APK: o GGUF é baixado sob demanda pelo
 * ModelManager com verificação SHA-256 (hashes pinados abaixo, obtidos do
 * LFS do HuggingFace em 2026-09). Quantizações Q4_K_M: bom equilíbrio
 * tamanho/qualidade para CPU de celular. Todos inferem em pt-BR/pt-PT/en.
 * **EN** No model ships inside the APK: the GGUF is downloaded on demand by
 * the ModelManager with SHA-256 verification (pinned hashes below, taken
 * from the HuggingFace LFS on 2026-09). Q4_K_M quantization: a good
 * size/quality balance for phone CPUs. All of them infer pt-BR/pt-PT/en.
 */
data class LlmModelInfo(
    val id: String,
    val fileName: String,
    val url: String,
    val sha256: String,
    val bytes: Long,
    /** Tamanho de contexto alocado na carga (tokens). */
    val contextTokens: Int,
    /** Rótulo curto para a UI. */
    val label: String,
)

object LlmCatalog {

    /**
     * Qwen2.5 0.5B Instruct (Apache-2.0) — aparelhos com pouca RAM (~4 GB).
     * https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF
     */
    val QWEN_0_5B = LlmModelInfo(
        id = "qwen2.5-0.5b-instruct",
        fileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf",
        url = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
        sha256 = "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db",
        bytes = 491_400_032L,
        contextTokens = 2048,
        label = "Qwen2.5 0.5B (~469 MB)",
    )

    /**
     * Llama 3.2 1B Instruct — bom equilíbrio para 6 GB de RAM.
     * https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF
     */
    val LLAMA_1B = LlmModelInfo(
        id = "llama-3.2-1b-instruct",
        fileName = "llama-3.2-1b-instruct-q4_k_m.gguf",
        url = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        sha256 = "6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83",
        bytes = 807_694_464L,
        contextTokens = 2048,
        label = "Llama 3.2 1B (~770 MB)",
    )

    /**
     * Qwen2.5 1.5B Instruct (Apache-2.0) — melhor qualidade, ~8 GB de RAM.
     * https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF
     */
    val QWEN_1_5B = LlmModelInfo(
        id = "qwen2.5-1.5b-instruct",
        fileName = "qwen2.5-1.5b-instruct-q4_k_m.gguf",
        url = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        sha256 = "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e",
        bytes = 1_117_320_736L,
        contextTokens = 2048,
        label = "Qwen2.5 1.5B (~1,0 GB)",
    )

    /**
     * Gemma 2 2B IT — a melhor qualidade do catálogo, ~8 GB de RAM.
     * https://huggingface.co/bartowski/gemma-2-2b-it-GGUF
     */
    val GEMMA_2B = LlmModelInfo(
        id = "gemma-2-2b-it",
        fileName = "gemma-2-2b-it-q4_k_m.gguf",
        url = "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf",
        sha256 = "e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787",
        bytes = 1_708_582_752L,
        contextTokens = 2048,
        label = "Gemma 2 2B (~1,6 GB)",
    )

    val MODELS: List<LlmModelInfo> = listOf(
        QWEN_0_5B,
        LLAMA_1B,
        QWEN_1_5B,
        GEMMA_2B,
    )

    fun byId(id: String): LlmModelInfo? = MODELS.firstOrNull { it.id == id }

    fun byFileName(fileName: String): LlmModelInfo? =
        MODELS.firstOrNull { it.fileName.equals(fileName, ignoreCase = true) }
}
