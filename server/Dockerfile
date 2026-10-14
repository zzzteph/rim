# The RIM lobby server. On the VPS docker-compose.yml builds this and puts Caddy (TLS) in front of it.
FROM node:22-alpine

ENV NODE_ENV=production \
    PORT=8787
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && rm -rf /root/.npm
COPY index.js lobby.js ./

USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT}/health" || exit 1
CMD ["node", "index.js"]
