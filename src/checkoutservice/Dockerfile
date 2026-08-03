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
# Docker Buildx thường tự động truyền giá trị phù hợp.
ARG BUILDPLATFORM

# =========================================================
# Stage 1: Build
# =========================================================

# Dùng Go SDK để download dependency và build binary.
FROM --platform=$BUILDPLATFORM \
    golang:1.26.4-alpine@sha256:3ad57304ad93bbec8548a0437ad9e06a455660655d9af011d58b993f6f615648 \
    AS builder

# Hệ điều hành và kiến trúc CPU mà binary sẽ chạy trên.
# Docker Buildx thường tự truyền TARGETOS và TARGETARCH.
ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

# Copy dependency manifests trước để tận dụng Docker build cache.
COPY go.mod go.sum ./

# Download Go modules.
# Layer này được tái sử dụng nếu go.mod/go.sum không thay đổi.
RUN go mod download

# Copy toàn bộ source code sau khi dependency đã được download.
COPY . .

# Skaffold truyền compiler flags khi chạy ở chế độ debug.
ARG SKAFFOLD_GO_GCFLAGS

# Build static binary cho đúng OS và CPU architecture.
# - CGO_ENABLED=0: không phụ thuộc thư viện C động.
# - -ldflags="-s -w": loại bỏ symbol/debug metadata để giảm kích thước.
# - Output: /checkoutservice
RUN GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    CGO_ENABLED=0 \
    go build \
    -ldflags="-s -w" \
    -gcflags="${SKAFFOLD_GO_GCFLAGS}" \
    -o /checkoutservice \
    .

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime image tối giản và mặc định chạy non-root.
# Không chứa shell, package manager, Go SDK hoặc source code.
FROM gcr.io/distroless/static:nonroot

WORKDIR /app

# Chỉ copy binary đã build từ builder.
# Distroless nonroot dùng UID/GID 65532.
COPY --chown=65532:65532 \
    --from=builder \
    /checkoutservice \
    /app/checkoutservice

# Chạy process bằng UID/GID non-root.
USER 65532:65532

# Thiết lập cách Go in stack trace khi application panic.
ENV GOTRACEBACK=single

EXPOSE 5050

# Khởi động static binary.
ENTRYPOINT ["/app/checkoutservice"]
