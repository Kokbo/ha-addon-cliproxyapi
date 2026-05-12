# syntax=docker/dockerfile:1.6

# Global ARGs — declared before any FROM so they are usable in FROM lines.
# BUILD_FROM and BUILD_ARCH are injected by the HA addon builder.
ARG BUILD_FROM
ARG BUILD_ARCH
ARG CLIPROXYAPI_VERSION=main

# -----------------------------------------------------------------------------
# Stage 1: build CLIProxyAPI from source.
# Upstream go.mod currently requires Go >= 1.26.0, so we use the matching
# toolchain image. CLIPROXYAPI_VERSION selects a branch or tag to clone.
# BUILD_ARCH (aarch64 / armv7 / amd64) is mapped to GOARCH/GOARM below.
# Global ARGs go out of scope at FROM, so we re-declare the ones we need.
# -----------------------------------------------------------------------------
FROM golang:1.26-alpine AS builder

ARG CLIPROXYAPI_VERSION
ARG BUILD_ARCH

RUN apk add --no-cache git ca-certificates

WORKDIR /src
RUN git clone --depth=1 --branch "${CLIPROXYAPI_VERSION}" \
      https://github.com/router-for-me/CLIProxyAPI.git . \
    && git rev-parse HEAD > /src/.commit

RUN case "${BUILD_ARCH}" in \
      aarch64) GOARCH=arm64; GOARM= ;; \
      amd64)   GOARCH=amd64; GOARM= ;; \
      armv7)   GOARCH=arm;   GOARM=7 ;; \
      *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac && \
    export GOARCH GOARM && \
    CGO_ENABLED=0 GOOS=linux go build \
      -ldflags="-s -w -X 'main.Version=${CLIPROXYAPI_VERSION}' -X 'main.Commit=$(cat /src/.commit)'" \
      -o /out/CLIProxyAPI \
      ./cmd/server/

# -----------------------------------------------------------------------------
# Stage 2: HA-base runtime image
# -----------------------------------------------------------------------------
FROM ${BUILD_FROM}

COPY --from=builder /out/CLIProxyAPI /usr/bin/CLIProxyAPI
COPY cliproxyapi.example.yaml /usr/share/cliproxyapi/config.example.yaml
COPY run.sh /run.sh
RUN chmod +x /run.sh /usr/bin/CLIProxyAPI

EXPOSE 8317

CMD ["/run.sh"]
