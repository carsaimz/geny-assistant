# Regras ProGuard/R8 do Geny Assistant.
# Capacitor: preserva classes de plugin registradas via reflexao.
-keep class com.getcapacitor.** { *; }
-keep class com.carsaimz.genyassistant.bridge.** { *; }
-keepclassmembers class com.carsaimz.genyassistant.bridge.** {
    @com.getcapacitor.PluginMethod <methods>;
}

# org.json acessado via reflexao em alguns caminhos
-dontwarn org.json.**

# Mantem linhas de stacktrace para o log de auditoria local
-keepattributes SourceFile,LineNumberTable
