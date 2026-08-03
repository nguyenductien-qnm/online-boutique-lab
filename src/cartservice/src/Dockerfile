# Copyright 2021 Google LLC
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

# Dùng .NET SDK để restore dependency và publish application.
FROM --platform=$BUILDPLATFORM \
    mcr.microsoft.com/dotnet/sdk:10.0.100-noble@sha256:c7445f141c04f1a6b454181bd098dcfa606c61ba0bd213d0a702489e5bd4cd71 \
    AS builder

# Kiến trúc CPU mà artifact sẽ chạy trên.
# Docker Buildx thường tự truyền amd64 hoặc arm64.
ARG TARGETARCH

WORKDIR /app

# Copy file project trước để tận dụng Docker build cache.
COPY cartservice.csproj ./

# Restore NuGet dependencies cho kiến trúc đích.
# Layer này được tái sử dụng nếu file .csproj không thay đổi.
RUN dotnet restore cartservice.csproj \
    -a ${TARGETARCH}

# Copy toàn bộ source code sau khi dependency đã được restore.
COPY . .

# Publish application ở chế độ Release.
# - Build executable self-contained
# - Đóng gói thành single file
# - Loại bỏ các thành phần không sử dụng
# - Xuất artifact vào /cartservice
RUN dotnet publish cartservice.csproj \
    -c Release \
    -a ${TARGETARCH} \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true \
    -p:TrimMode=full \
    -o /cartservice

# =========================================================
# Stage 2: Runtime
# =========================================================

# Runtime image tối giản, chỉ chứa OS dependencies.
# Không chứa .NET SDK, source code hoặc NuGet cache.
FROM mcr.microsoft.com/dotnet/runtime-deps:10.0.0-noble-chiseled@sha256:b857c8cb8d929183cfe4c6dd9994abba92a2639dd2dbaf06005379f815991604

WORKDIR /app

# Chỉ copy artifact đã publish từ builder.
# Gán quyền sở hữu cho UID/GID non-root cố định.
COPY --chown=10001:10001 \
    --from=builder \
    /cartservice/ \
    /app/

# Cấu hình ASP.NET Core lắng nghe trên port 7070.
# Tắt .NET diagnostics trong runtime production.
ENV DOTNET_EnableDiagnostics=0 \
    ASPNETCORE_HTTP_PORTS=7070

# Chạy application bằng UID/GID non-root.
# Không cần tạo user hoặc group bên trong image.
USER 10001:10001

EXPOSE 7070

# Chạy executable self-contained đã được publish.
ENTRYPOINT ["/app/cartservice"]
