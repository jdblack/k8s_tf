# cline.Dockerfile — the resident Cline's image. Recess #2, 2026-10-14.
# No official server image exists, so: node + the pinned cline CLI. See memory `todo-cline-pod`.
FROM docker.io/library/node:23-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates jq \
 && rm -rf /var/lib/apt/lists/*

# Pin the CLI package version. NB: the npm `cline` package is 3.x; 4.1.23 is the VS Code EXTENSION's
# version (a different artifact). `cline@4.1.23` -> ETARGET. Latest CLI = 3.0.71 (2026-10-14).
ARG CLINE_VERSION=3.0.71
RUN npm install -g cline@${CLINE_VERSION} \
 && npm cache clean --force

# node:23-slim already ships a uid-1000 `node` user; reuse it instead of colliding.
ENV HOME=/home/node
WORKDIR /home/node
USER node

ENTRYPOINT ["cline"]
