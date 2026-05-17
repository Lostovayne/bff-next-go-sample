# Single multi-stage build using pnpm
FROM node:22-alpine AS builder
WORKDIR /app
# copy lockfile first for better cache
COPY package.json pnpm-lock.yaml* ./
RUN corepack enable && corepack prepare pnpm@11.1.2 --activate
# non-interactive in CI/docker
ENV CI=true
# install all deps (dev+prod) to allow build
RUN pnpm install --frozen-lockfile

# copy source and build
COPY . .
RUN pnpm run build

# prune devDependencies to keep only production modules
RUN pnpm prune --prod

# Runtime image
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["sh","-lc","corepack enable && corepack prepare pnpm@11.1.2 --activate && pnpm start"]
