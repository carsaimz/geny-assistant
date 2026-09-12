// Build raiz do projeto Android do Geny Assistant.
// Versões fixadas no version catalog: gradle/libs.versions.toml (build determinista).
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}
