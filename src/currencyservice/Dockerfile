# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# =========================================================
# Stage 1: Install dependencies
# =========================================================

# Native dependencies phải được cài cho target architecture.
FROM node:20.20.2-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293 AS deps

# Một số package Node.js cần compiler để build native addon.
RUN apk add --no-cache \
    python3 \
    make \
    g++

WORKDIR /usr/src/app

# Copy dependency manifests trước để tận dụng Docker build cache.
COPY package*.json ./

# Cài production dependencies.
RUN npm ci --omit=dev

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime chỉ chứa Node.js để chạy application.
FROM node:20.20.2-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293

WORKDIR /usr/src/app

# Copy production dependencies từ builder.
COPY --chown=10001:10001 \
    --from=deps \
    /usr/src/app/node_modules \
    ./node_modules

# Copy source code.
COPY --chown=10001:10001 . .

# Chạy application bằng UID/GID non-root.
USER 10001:10001

EXPOSE 7000

# Khởi động Node.js application.
ENTRYPOINT ["node", "server.js"]
