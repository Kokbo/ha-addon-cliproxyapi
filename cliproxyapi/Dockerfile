# syntax=docker/dockerfile:1.6

# Global ARGs — declared before any FROM so they are usable in FROM lines.
# BUILD_FROM is the multi-platform HA base image (formerly build_from in the
# deprecated build.yaml). BUILD_ARCH (amd64 / aarch64) is passed by the
# Supervisor and by CI.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.22
ARG BUILD_ARCH
ARG CLIPROXYAPI_VERSION=v8.0.79
ARG BUILD_DATE=unknown

# -----------------------------------------------------------------------------
# Stage 1: build CLIProxyAPI from source.
# Upstream go.mod currently requires Go >= 1.26.0, so we use the matching
# toolchain image. CLIPROXYAPI_VERSION selects the upstream release tag to clone;
# pin a tag (not a branch) so rebuilds are reproducible and not served from a
# stale Docker layer cache.
# BUILD_ARCH (aarch64 / amd64) is mapped to GOARCH below.
# Global ARGs go out of scope at FROM, so we re-declare the ones we need.
# -----------------------------------------------------------------------------
FROM golang:1.26-alpine AS builder

ARG CLIPROXYAPI_VERSION
ARG BUILD_ARCH
ARG BUILD_DATE

RUN apk add --no-cache git ca-certificates

WORKDIR /src
RUN git clone --depth=1 --branch "${CLIPROXYAPI_VERSION}" \
      https://github.com/router-for-me/CLIProxyAPI.git . \
    && git rev-parse HEAD > /src/.commit

RUN case "${BUILD_ARCH}" in \
      aarch64) GOARCH=arm64 ;; \
      amd64)   GOARCH=amd64 ;; \
      *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac && \
    export GOARCH && \
    CGO_ENABLED=0 GOOS=linux go build \
      -ldflags="-s -w -X 'main.Version=${CLIPROXYAPI_VERSION}' -X 'main.Commit=$(cat /src/.commit)' -X 'main.BuildDate=${BUILD_DATE}'" \
      -o /out/CLIProxyAPI \
      ./cmd/server/

# -----------------------------------------------------------------------------
# Stage 2: HA-base runtime image
# -----------------------------------------------------------------------------
FROM ${BUILD_FROM}

LABEL \
    org.opencontainers.image.title="Home Assistant App: CLIProxyAPI" \
    org.opencontainers.image.description="OpenAI/Claude-compatible API proxy for OAuth subscriptions, with an ingress auth shell" \
    org.opencontainers.image.source="https://github.com/Kokbo/ha-addon-cliproxyapi"

# ttyd: in-addon web terminal for OAuth bootstrap (exposed via HA ingress).
# bash:  cliproxy-shell entrypoint.
# nginx: fronts ttyd so only the HA ingress proxy (172.30.32.2) can reach it.
RUN apk add --no-cache ttyd bash nginx

COPY --from=builder /out/CLIProxyAPI /usr/bin/CLIProxyAPI
COPY cliproxyapi.example.yaml /usr/share/cliproxyapi/config.example.yaml
COPY rootfs/ /

RUN chmod +x \
        /usr/bin/CLIProxyAPI \
        /usr/local/bin/* \
        /etc/cont-init.d/* \
        /etc/services.d/*/run

# API on the LAN, ttyd auth shell behind HA ingress on 7681.
EXPOSE 8317 7681

# Supervisor's watchdog restarts the add-on when this turns unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS -o /dev/null http://127.0.0.1:8317/healthz || exit 1

# No CMD — HA base image's s6-overlay init runs /etc/cont-init.d/* once,
# then supervises every service in /etc/services.d/.
