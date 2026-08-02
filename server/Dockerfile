FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY secrets ./secrets
COPY nixpacks.toml railway.toml BUILD_STAMP.txt ./

ENV NODE_ENV=production
ENV HOST=0.0.0.0
EXPOSE 8080

CMD ["npm", "start"]
