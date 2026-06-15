# syntax=docker/dockerfile:1

###############################################################################
# Stage 1 - dependencies (production only)
###############################################################################
FROM node:20-alpine AS deps

WORKDIR /app

# Only copy manifests first so the dependency layer is cached independently of
# source changes.
COPY package.json package-lock.json ./

# Install production dependencies deterministically.
RUN npm ci --omit=dev && npm cache clean --force

###############################################################################
# Stage 2 - runtime
###############################################################################
FROM node:20-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

# wget is bundled in alpine busybox and used by the HEALTHCHECK below.
WORKDIR /app

# Copy installed node_modules from the deps stage.
COPY --from=deps /app/node_modules ./node_modules

# Copy application source and runtime config needed at start.
COPY package.json package-lock.json .sequelizerc ./
COPY src ./src

# uploads/ is a writable runtime directory and is mounted as a volume in
# docker-compose. Create it so the path exists even without a mount, and make
# sure the non-root user owns it.
RUN mkdir -p uploads logs \
    && addgroup -g 1001 -S nodejs \
    && adduser -u 1001 -S nodejs -G nodejs \
    && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000

# The app exposes GET /api/health (200 when DB is up, 503 when down).
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/health || exit 1

CMD ["node", "src/server.js"]
