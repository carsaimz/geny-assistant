import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.carsaimz.genyassistant',
  appName: 'Geny Assistant',
  webDir: 'dist',
  android: {
    // Privacidade: nenhuma comunicação em texto plano (docs §13.3).
    allowMixedContent: false,
    captureInput: true,
    webContentsDebuggingEnabled: false,
  },
  server: {
    // Sem live-reload apontando para hosts externos por padrão (local-first).
    androidScheme: 'https',
  },
};

export default config;
