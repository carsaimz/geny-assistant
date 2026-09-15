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

# Mantem linhas de stacktrace para o log de auditoria local
-keepattributes SourceFile,LineNumberTable
