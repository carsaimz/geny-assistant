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
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
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

