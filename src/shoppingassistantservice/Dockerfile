# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
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
FROM python:3.14.6-slim@sha256:b877e50bd90de10af8d82c57a022fc2e0dc731c5320d762a27986facfc3355c1 AS base

# =========================================================
# Stage 1: Install dependencies
# =========================================================

# Builder dùng để compile và cài các Python dependency.
FROM base AS builder

# Cài C++ compiler cho các package có native extension.
# Compiler chỉ tồn tại trong builder, không được đưa vào runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Tạo virtual environment riêng để dễ copy sang runtime.
RUN python -m venv /opt/venv

# Ưu tiên sử dụng Python và pip bên trong virtual environment.
ENV PATH="/opt/venv/bin:${PATH}"

# Copy dependency manifest trước để tận dụng Docker build cache.
COPY requirements.txt ./

# Cài Python dependencies vào virtual environment.
# Layer này được tái sử dụng nếu requirements.txt không thay đổi.
RUN pip install --no-cache-dir \
    -r requirements.txt

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime chỉ chứa Python, application và dependencies.
# Không chứa compiler hoặc build tools.
FROM base AS runtime

WORKDIR /shoppingassistantservice

# Copy virtual environment đã được chuẩn bị từ builder.
COPY --chown=10001:10001 \
    --from=builder \
    /opt/venv \
    /opt/venv

# Copy source code của application.
COPY --chown=10001:10001 . .

# Sử dụng Python và packages trong virtual environment.
# PYTHONUNBUFFERED giúp log được ghi ngay ra stdout/stderr.
ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# Chạy application bằng UID/GID non-root cố định.
USER 10001:10001

EXPOSE 8080

# Khởi động Shopping Assistant service.
ENTRYPOINT ["python", "shoppingassistantservice.py"]
