// nuxt.config.ts
export default defineNuxtConfig({
  // Mantiene la estructura de carpeta app/
  future: { 
    compatibilityVersion: 4 
  },

  // Importante: Para Tailwind 4 a veces es mejor dejar que PostCSS lo maneje
  // Si el módulo '@nuxtjs/tailwindcss' te sigue dando problemas, puedes quitarlo de aquí
  // y usar solo la configuración de abajo.
  postcss: {
    plugins: {
      '@tailwindcss/postcss': {}, // Aquí es donde registramos al nuevo "escolta"
      'autoprefixer': {},
    },
  },

  css: ['~/assets/css/main.css'],

  compatibilityDate: '2024-11-01'
})