# 1. Cambiamos a Node 22 para cumplir con los requisitos de tus plugins (Visualizer/Prisma)
FROM node:22-alpine AS builder

# 2. Instalamos las dependencias de compilación necesarias para better-sqlite3
# Alpine no las trae por defecto para ahorrar espacio
RUN apk add --no-cache python3 make g++

WORKDIR /app

# 3. Copiamos los archivos de configuración
COPY package*.json ./

# 4. Ahora npm install podrá compilar los módulos nativos sin errores
RUN npm install

# 5. Copiamos el resto del proyecto
COPY . .

# 6. Construimos el proyecto (Nuxt/Nitro)
RUN npm run build

# --- Etapa de Producción (Opcional pero recomendado) ---
FROM node:22-alpine
WORKDIR /app
COPY --from=builder /app/.output ./ .output
# Instalar solo dependencias de producción si es necesario
EXPOSE 3000
CMD ["node", ".output/server/index.mjs"]
