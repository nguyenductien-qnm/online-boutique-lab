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
# Base image
# =========================================================

# Dùng target-platform base để native wheels khớp runtime architecture.
FROM python:3.14.6-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92 AS base

# =========================================================
# Stage 1: Install dependencies
# =========================================================

# Builder dùng để cài Python dependencies và compile
# các package có native extension.
FROM base AS builder

# Không tạo file .pyc và ghi log trực tiếp ra stdout/stderr.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Cài compiler và Linux headers cho các package cần build.
# Các build tools chỉ tồn tại trong builder.
RUN apk add --no-cache \
    g++ \
    linux-headers

WORKDIR /build

# Copy dependency manifest trước để tận dụng Docker build cache.
COPY requirements.txt .

# Cài Python dependencies vào một thư mục riêng
# để dễ copy sang runtime.
RUN pip install \
    --no-cache-dir \
    --prefix=/install \
    -r requirements.txt

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime chỉ chứa Python, runtime libraries,
# dependencies và Locust test script.
FROM base AS runtime

# Không tạo file .pyc và ghi log trực tiếp ra stdout/stderr.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GEVENT_SUPPORT=True

# Một số dependency cần C++ runtime khi chạy.
RUN apk add --no-cache libstdc++

WORKDIR /loadgen

# Copy Python dependencies từ builder.
COPY --chown=10001:10001 \
    --from=builder \
    /install \
    /usr/local

# Copy Locust test definition.
COPY --chown=10001:10001 \
    locustfile.py \
    .

# Chạy application bằng UID/GID non-root.
USER 10001:10001

# Khởi động Locust ở chế độ headless.
# FRONTEND_ADDR, USERS và RATE được truyền qua environment variables.
ENTRYPOINT ["sh", "-c", "exec locust --host=\"http://${FRONTEND_ADDR}\" --headless -u \"${USERS:-10}\" -r \"${RATE:-1}\""]
