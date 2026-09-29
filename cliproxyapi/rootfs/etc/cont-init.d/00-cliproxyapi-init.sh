#!/usr/bin/with-contenv bashio
set -e

CONFIG_DIR=/config/cliproxyapi
AUTH_DIR="${CONFIG_DIR}/.cli-proxy-api"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
EXAMPLE_CONFIG=/usr/share/cliproxyapi/config.example.yaml

# Upstream (>= v7.1.46) disables every proxy endpoint (HTTP 403) while any of
# these example keys is listed under api-keys, even next to a real key.
PLACEHOLDER_KEY_RE='^[[:space:]]*-[[:space:]]*"?your-api-key-[123]"?[[:space:]]*$'

mkdir -p "${AUTH_DIR}"

if [ ! -f "${CONFIG_FILE}" ]; then
    bashio::log.warning "No config.yaml found in ${CONFIG_DIR}; seeding from example."
    api_key="$(head -c 36 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    sed -e "s/\"your-api-key-1\"/\"${api_key}\"/" \
        -e '/"your-api-key-[23]"/d' \
        "${EXAMPLE_CONFIG}" > "${CONFIG_FILE}"
    bashio::log.notice "Generated a random API key under api-keys."
    bashio::log.notice "View it via \"Open Web UI\" -> edit-config and use it in your clients."
fi

# OAuth tokens and api-keys: keep them private to the addon.
chmod 700 "${AUTH_DIR}"
chmod 600 "${CONFIG_FILE}"

if grep -qE "${PLACEHOLDER_KEY_RE}" "${CONFIG_FILE}"; then
    bashio::log.error "Example API key(s) 'your-api-key-N' found under api-keys in ${CONFIG_FILE}."
    bashio::log.error "CLIProxyAPI disables all proxy endpoints (HTTP 403) until they are removed."
    bashio::log.error "Fix: \"Open Web UI\" -> edit-config, delete the placeholders, keep a long random key, then restart-api."
fi

bashio::log.info "Auth dir:   ${AUTH_DIR}"
bashio::log.info "Config:     ${CONFIG_FILE}"

# Upstream's web management panel is the easiest way to log in to providers;
# it needs a management secret-key, and allow-remote to be used from the LAN.
if grep -qE '^[[:space:]]+secret-key:[[:space:]]*"?[^"[:space:]#]' "${CONFIG_FILE}"; then
    if grep -qE '^[[:space:]]+allow-remote:[[:space:]]*true' "${CONFIG_FILE}"; then
        bashio::log.info "Web panel:  http://<ha-ip>:8317/management.html (log in with your management secret-key)"
    else
        bashio::log.info "Web panel:  secret-key is set but allow-remote is false; set allow-remote: true to use http://<ha-ip>:8317/management.html from your LAN."
    fi
else
    bashio::log.info "Web panel:  disabled. Set remote-management secret-key + allow-remote: true to log in to providers from your browser (see README)."
fi
bashio::log.info "Auth shell: click \"Open Web UI\" for the terminal (edit-config, gemini-login, ...)."
