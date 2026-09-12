/// <reference types="vitest" />
import { defineConfig } from 'vitest/config';

// Build determinista do app web do Geny Assistant.
// O output (dist/) e sincronizado para o projeto Android via Capacitor
// (ver scripts/sync-web.sh e docs/build.md).
export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
    sourcemap: true,
    target: 'es2020',
  },
  server: {
    port: 5173,
    strictPort: true,
  },
  test: {
    environment: 'jsdom',
    include: ['src/tests/**/*.test.ts'],
  },
});
