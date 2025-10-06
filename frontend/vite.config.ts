import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    host: true,
    port: 3000,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        secure: false,
        ws: false, // 禁用WebSocket代理，避免冲突
      },
      '/v1': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        secure: false,
        ws: false, // 禁用WebSocket代理，避免冲突
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
})
