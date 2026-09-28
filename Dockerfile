# syntax=docker/dockerfile:1
# OpenBB Platform API - self-hosted financial data platform (AGPLv3).
# Recipe based on the vendor's own build/docker/platformAPI.Dockerfile,
# hardened for Railway: pinned base, build toolchain only at build time,
# non-root runtime, HEALTHCHECK, EXPOSE.
FROM python:3.14-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Toolchain for C-extension wheels (built at build time) + curl for healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# openbb[all]    = core + 50+ data-provider plugins + charting + MCP server
# openbb-platform-api = the REST server launched by `openbb-api` (default :6900)
RUN pip install --upgrade "pip>=24" \
    && pip install "openbb[all]" "openbb-platform-api" \
    # drop the compiler toolchain; wheels are already built
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/*

# Config/credentials cache lives under HOME; give the app user a home dir.
ENV HOME=/home/openbb \
    PORT=6900 \
    OPENBB_API_HOST=0.0.0.0 \
    OPENBB_API_PORT=6900

RUN useradd -m -d /home/openbb openbb \
    && chown -R openbb:openbb /app /home/openbb

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER openbb
EXPOSE 6900

HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=6 \
  CMD curl -fsS "http://127.0.0.1:${OPENBB_API_PORT:-6900}/openapi.json" -o /dev/null || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
