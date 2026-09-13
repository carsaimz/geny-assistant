plugins {
    alias(libs.plugins.android.library)
}

// Módulo nativo do LLM local (docs §6, TODO core-05): apenas o wrapper JNI
// do llama.cpp. Zero código Kotlin/Java — o .so é empacotado no APK via
// dependency do :app. Módulo separado porque o ggml do llama.cpp v0.4.0
// colide com o ggml do whisper.cpp v1.7.4 num único configure do CMake
// (detalhes em src/main/cpp/CMakeLists.txt).
android {
    namespace = "com.carsaimz.genyassistant.llamanative"
    compileSdk = 35
    ndkVersion = "27.2.12479018"

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")

        ndk {
            // Mesmos ABIs do :app — armeabi-v7a (32-bit), arm64-v8a, x86_64.
            // Sem o armv7 o merge empacota o APK sem libgeny_llama_jni.so
            // nessa ABI (silencioso) e telemóveis 32-bit ficam sem LLM.
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DLLAMA_DIR=${File(rootDir.parentFile, "native/llama.cpp").absolutePath}",
                    "-DCMAKE_BUILD_TYPE=Release",
                )
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
}
