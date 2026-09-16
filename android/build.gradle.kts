// Build raiz do projeto Android do Geny Assistant.
// Versões fixadas no version catalog: gradle/libs.versions.toml (build determinista).
// O android-library é registrado AQUI na raiz para vencer a corrida de
// classpath com o build.gradle do :capacitor-android (npm), que carrega
// com.android.library sem versão (AGP 8.2.1 embutido).
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    // KSP (TODO android-04): processador de anotações do Room.
    alias(libs.plugins.ksp) apply false
}
