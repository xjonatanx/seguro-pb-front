# --- ETAPA 1: Construcción ---
FROM node:20-alpine AS builder

# Crear carpeta de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install

# Copiar el resto del código
COPY . .

# Construir la aplicación (Genera la carpeta .output)
RUN npm run build

# --- ETAPA 2: Producción ---
FROM node:20-alpine AS runner

WORKDIR /app

# Definir variables de entorno
ENV NODE_ENV=production
ENV PORT=3001
ENV HOST=0.0.0.0

# Copiar solo lo necesario desde el builder (la carpeta .output)
COPY --from=builder /app/.output ./.output

# Exponer el puerto
EXPOSE 3001

# Comando para iniciar el servidor de Nuxt (Nitro)
CMD ["node", ".output/server/index.mjs"]