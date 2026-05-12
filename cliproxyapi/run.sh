#!/usr/bin/with-contenv bashio
set -e

CONFIG_DIR=/config/cliproxyapi
AUTH_DIR="${CONFIG_DIR}/.cli-proxy-api"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
EXAMPLE_CONFIG=/usr/share/cliproxyapi/config.example.yaml

mkdir -p "${AUTH_DIR}"

if [ ! -f "${CONFIG_FILE}" ]; then
    bashio::log.warning "No config.yaml found in ${CONFIG_DIR}."
    bashio::log.warning "Seeding from example config; edit it before the addon will be useful."
    cp "${EXAMPLE_CONFIG}" "${CONFIG_FILE}"
    bashio::log.warning "Wrote ${CONFIG_FILE}. Set at least one api-keys entry,"
    bashio::log.warning "drop OAuth token files into ${AUTH_DIR}, then restart this addon."
fi

bashio::log.info "Starting CLIProxyAPI with config ${CONFIG_FILE}"
exec /usr/bin/CLIProxyAPI --config "${CONFIG_FILE}"
