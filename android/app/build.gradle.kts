plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

// Assinatura de release via segredos de CI (docs §17.5). Os valores chegam
// por variáveis de ambiente preenchidas a partir de GitHub Actions Secrets
// (KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD). Sem segredos
// (build local), o APK release sai sem assinar — o debug é o instalável.
val genyKeystoreFile: String? = System.getenv("GENY_KEYSTORE_FILE")
val hasReleaseSigning = !genyKeystoreFile.isNullOrEmpty()

android {
    namespace = "com.carsaimz.genyassistant"
    compileSdk = 35
    // NDK pinado (mesma versão no CI) — evita auto-download do default.
    ndkVersion = "27.2.12479018"

    defaultConfig {
        applicationId = "com.carsaimz.genyassistant"
        minSdk = 26
        targetSdk = 35
        versionCode = 4
        versionName = "0.2.0-alpha.1"

        ndk {
            // arm64-v8a: aparelhos modernos; x86_64: emulador/dev.
            abiFilters += listOf("arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                // Submodule pinado (native/whisper.cpp @ v1.7.4).
                arguments += listOf(
                    "-DWHISPER_DIR=${File(rootDir.parentFile, "native/whisper.cpp").absolutePath}",
                    "-DCMAKE_BUILD_TYPE=Release",
                )
            }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("genyRelease") {
                storeFile = file(genyKeystoreFile!!)
                storePassword = System.getenv("GENY_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("GENY_KEY_ALIAS")
                keyPassword = System.getenv("GENY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("genyRelease")
            }
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    testOptions {
        unitTests.isIncludeAndroidResources = false
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    // Silero VAD (Fase 2, TODO core-01): ONNX Runtime Android
    implementation(libs.onnxruntime.android)
    implementation(libs.androidx.appcompat)
    implementation(libs.google.material)
    implementation(libs.androidx.lifecycle.runtime)
    implementation(libs.kotlinx.coroutines.android)
    // Runtime Capacitor: projeto local vindo de app/node_modules
    // (@capacitor/android via npm) — ver settings.gradle.kts.
    implementation(project(":capacitor-android"))

    testImplementation(libs.junit)
    // org.json real para testes JVM (o stub do android.jar lanca excecao)
    testImplementation(libs.org.json)
}
