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

    defaultConfig {
        applicationId = "com.carsaimz.genyassistant"
        minSdk = 26
        targetSdk = 35
        versionCode = 2
        versionName = "0.1.0-alpha.2"
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

    testOptions {
        unitTests.isIncludeAndroidResources = false
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
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
