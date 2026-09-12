pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    // PREFER_SETTINGS: o build.gradle do :capacitor-android (npm) registra
    // repositórios próprios; os nossos (google/mavenCentral) têm prioridade.
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "GenyAssistant"
include(":app")

// O runtime do Capacitor distribui-se via npm (@capacitor/android) e liga-se
// como projeto local do Gradle. Requer `npm ci` em app/ antes do build Android.
include(":capacitor-android")
project(":capacitor-android").projectDir =
    file("../app/node_modules/@capacitor/android/capacitor")

