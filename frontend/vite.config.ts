import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

/** VITE_BASE_PATH=/hrm/ khi copy vao XAMPP C:\xampp\htdocs\hrm */
const base = (process.env.VITE_BASE_PATH || '/').replace(/\/?$/, '/') ;

export default defineConfig({
  base,
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/j1-api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
