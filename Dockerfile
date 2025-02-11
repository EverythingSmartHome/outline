# ===== STAGE 1: Builder =====
FROM node:20-slim AS builder

ARG APP_PATH=/opt/outline
WORKDIR ${APP_PATH}

# Install Git so we can clone the repository
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Clone your fork of Outline
RUN git clone --depth=1 https://github.com/everythingsmarthome/outline.git .

# Check out the branch with your custom iframe changes
RUN git checkout iframe-serial

# Increase Node memory limit for building
ENV NODE_OPTIONS=--max-old-space-size=4096

# Install dependencies and build Outline
RUN yarn install --frozen-lockfile && yarn build

# ===== STAGE 2: Production Runner =====
FROM node:20-slim AS runner

ARG APP_PATH=/opt/outline
WORKDIR ${APP_PATH}
ENV NODE_ENV=production

# Copy build output and required files from the builder stage
COPY --from=builder ${APP_PATH}/build ./build
COPY --from=builder ${APP_PATH}/server ./server
COPY --from=builder ${APP_PATH}/public ./public
COPY --from=builder ${APP_PATH}/.sequelizerc ./.sequelizerc
COPY --from=builder ${APP_PATH}/node_modules ./node_modules
COPY --from=builder ${APP_PATH}/package.json ./package.json

# Install wget for healthchecks
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Create a non-root user and set permissions
RUN addgroup --gid 1001 nodejs && \
  adduser --uid 1001 --ingroup nodejs nodejs && \
  chown -R nodejs:nodejs ${APP_PATH}/build && \
  mkdir -p /var/lib/outline && \
  chown -R nodejs:nodejs /var/lib/outline

ENV FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data
RUN mkdir -p "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
  chown -R nodejs:nodejs "$FILE_STORAGE_LOCAL_ROOT_DIR" && \
  chmod 1777 "$FILE_STORAGE_LOCAL_ROOT_DIR"

VOLUME /var/lib/outline/data

USER nodejs

HEALTHCHECK --interval=1m CMD wget -qO- "http://localhost:${PORT:-3000}/_health" | grep -q "OK" || exit 1

EXPOSE 3000
CMD ["yarn", "start"]
