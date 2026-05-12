#!/usr/bin/with-contenv bashio
set -e

CONFIG_DIR=/config/cliproxyapi
AUTH_DIR="${CONFIG_DIR}/.cli-proxy-api"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
EXAMPLE_CONFIG=/usr/share/cliproxyapi/config.example.yaml

mkdir -p "${AUTH_DIR}"

if [ ! -f "${CONFIG_FILE}" ]; then
    bashio::log.warning "No config.yaml found in ${CONFIG_DIR}."
    bashio::log.warning "Seeding from example; edit api-keys before the API is useful."
    cp "${EXAMPLE_CONFIG}" "${CONFIG_FILE}"
fi

bashio::log.info "Auth dir:   ${AUTH_DIR}"
bashio::log.info "Config:     ${CONFIG_FILE}"
bashio::log.info "Auth shell: click \"Open Web UI\" to bootstrap OAuth credentials."
