# ========================================
# Dependency stage
# ========================================
FROM node:20-alpine AS dependencies

WORKDIR /app

COPY package*.json ./

RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi

# ========================================
# Production stage
# ========================================
FROM node:20-alpine

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=dependencies /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
COPY migrations ./migrations

USER appuser

EXPOSE 3000

HEALTHCHECK \
    --interval=30s \
    --timeout=3s \
    --start-period=10s \
    --retries=3 \
    CMD wget -qO- http://localhost:3000/live || exit 1

CMD ["node", "src/index.js"]
