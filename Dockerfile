# Build stage
FROM node:20.19.2-alpine AS builder

WORKDIR /app

# Install build dependencies (bash is needed for build scripts)
RUN apk add --no-cache bash git openssh-client

# Set HUSKY=0 to skip husky installation during Docker build
ENV HUSKY=0

# Copy package files and workspace structure
COPY package*.json ./
COPY packages ./packages
COPY scripts ./scripts

# Install all dependencies (including dev dependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Build only UI and generate config types (skip build-lib which is for publishing)
RUN npm run generate-config-types && npm run build-ui

# Production stage
FROM node:20.19.2-alpine

WORKDIR /app

# Install git (required for git-proxy functionality)
RUN apk add --no-cache git openssh-client

# Copy only node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages

# Copy package files (for reference)
COPY package*.json ./

# Copy source code and built UI from builder
COPY --from=builder /app/src ./src
COPY --from=builder /app/index.ts ./index.ts
COPY --from=builder /app/build ./build
COPY --from=builder /app/config.schema.json ./config.schema.json
COPY --from=builder /app/vite.config.ts ./vite.config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json

# Create directories for volumes
RUN mkdir -p /app/config /app/data /app/certs /app/.ssh

# Copy default config to root (will be used if volume not mounted)
COPY proxy.config.json /app/proxy.config.json

# Set environment variables
ENV NODE_ENV=production \
    PORT=8080 \
    PROXY_CONFIG_FILE=/app/config/proxy.config.json

# Expose ports
EXPOSE 8080 2222

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application using tsx (TypeScript executor)
CMD ["npx", "tsx", "index.ts"]
