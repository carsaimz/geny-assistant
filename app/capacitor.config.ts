import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.carsaimz.genyassistant',
  appName: 'Geny Assistant',
  webDir: 'dist',
  android: {
    // Privacidade: nenhuma comunicação em texto plano (docs §13.3).
    allowMixedContent: false,
    // captureInput permanece false (default): true instala uma
    // BaseInputConnection falsa e quebra a digitação do teclado na WebView.
    // webContentsDebuggingEnabled: omitido — o default do Capacitor é
    // "ligado só em builds debug" (inspetável via chrome://inspect no USB).
  },
  server: {
    // Sem live-reload apontando para hosts externos por padrão (local-first).
    androidScheme: 'https',
  },
};

export default config;
