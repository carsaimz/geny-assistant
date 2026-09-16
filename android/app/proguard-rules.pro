# Regras ProGuard/R8 do Geny Assistant.
# Capacitor: preserva classes de plugin registradas via reflexao.
-keep class com.getcapacitor.** { *; }
-keep class com.carsaimz.genyassistant.bridge.** { *; }
-keepclassmembers class com.carsaimz.genyassistant.bridge.** {
    @com.getcapacitor.PluginMethod <methods>;
}

# JNI por nome (JNI lookup usa o nome exato do metodo e da classe):
# sem keep, R8 pode renomear a classe e quebrar o prefixo do simbolo.
-keep class com.carsaimz.genyassistant.ai.LlmJni { *; }
-keep class com.carsaimz.genyassistant.ai.TokenCallback { *; }
-keep class com.carsaimz.genyassistant.voice.WhisperJni { *; }
-keep class com.carsaimz.genyassistant.voice.EspeakPhonemizer { *; }

# org.json acessado via reflexao em alguns caminhos
-dontwarn org.json.**


# UniFFI + JNA (TODO core-04): os bindings acessam libgeny_core.so via JNA
# (Native.load resolve campos/métodos por nome — reflexão estrutural).
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { *; }
-dontwarn com.sun.jna.**
-keep class uniffi.geny_core.** { *; }

# Mantem linhas de stacktrace para o log de auditoria local
-keepattributes SourceFile,LineNumberTable
