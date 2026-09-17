# 前端构建产物由后端同源托管，因此在同一镜像内完成构建
FROM node:22-alpine AS frontend
WORKDIR /build
COPY frontend/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --fetch-retries=6 --fetch-retry-maxtimeout=60000
COPY frontend/ ./
RUN npm run build

FROM python:3.13-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 国内网络：apt 与 PyPI 走清华镜像，避免 deb.debian.org / Fastly 连接被重置
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
      /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list 2>/dev/null; \
    apt-get update \
    && apt-get install -y --no-install-recommends fonts-wqy-microhei \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy PYTHONPATH=/app/backend
ENV UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple

COPY backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen --all-extras --no-dev

COPY backend/ ./
COPY --from=frontend /build/dist /app/frontend/dist

ENV PATH="/app/backend/.venv/bin:$PATH"
EXPOSE 7302
