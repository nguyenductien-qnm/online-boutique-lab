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

# Platform dùng để chạy stage build.
# Docker Buildx thường tự động truyền giá trị này.
ARG BUILDPLATFORM

# =========================================================
# Stage 1: Build
# =========================================================

# Dùng JDK để tải dependency và build ứng dụng Java.
FROM --platform=$BUILDPLATFORM \
    eclipse-temurin:24.0.2_12-jdk-noble@sha256:dacac8e9a0df0d2bd24e702b4431132875c249930b70555ebd7ca285b5bee684 \
    AS builder

WORKDIR /app

# Copy Gradle manifest và wrapper trước để tận dụng build cache.
COPY ["build.gradle", "gradlew", "./"]
COPY gradle ./gradle

# Cấp quyền chạy cho Gradle Wrapper.
RUN chmod +x gradlew

# Tải dependency trước khi copy source code.
# Layer này được tái sử dụng nếu cấu hình dependency không thay đổi.
RUN ./gradlew downloadRepos

# Copy toàn bộ source code.
COPY . .

# Đảm bảo gradlew vẫn có quyền chạy sau khi COPY . .
RUN chmod +x gradlew

# Build Java distribution.
# Artifact được tạo tại /app/build/install/hipstershop.
RUN ./gradlew installDist

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime chỉ cần JRE, không cần JDK, Gradle hay source code.
FROM eclipse-temurin:25.0.3_9-jre-alpine@sha256:28db6fdf60e38945e43d840c0333aeaec66c15943070104f7586fd3c9d1665b0

WORKDIR /app

# Chỉ copy artifact đã build sang runtime image.
# Gán quyền sở hữu cho UID/GID non-root cố định.
COPY --chown=10001:10001 \
    --from=builder \
    /app/build/install/hipstershop/ \
    /app/

# Chạy ứng dụng bằng UID/GID non-root.
# Không cần tạo username hoặc group trong /etc/passwd.
USER 10001:10001

# Application lắng nghe trên port 9555.
EXPOSE 9555

# Khởi động application bằng script do Gradle tạo.
ENTRYPOINT ["/app/bin/AdService"]
