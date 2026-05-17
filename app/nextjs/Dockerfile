# Stage 1: install deps (using pnpm via corepack)
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN corepack enable && corepack prepare pnpm@11.0.0 --activate || true
RUN pnpm install --production --frozen-lockfile || true

# Stage 2: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY . .
RUN corepack enable && corepack prepare pnpm@11.0.0 --activate || true
RUN pnpm install --frozen-lockfile
RUN pnpm run build

# Stage 3: runtime
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["sh","-lc","corepack enable && corepack prepare pnpm@11.0.0 --activate && pnpm start"]
