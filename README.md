# Home Assistant Addon Repository: CLIProxyAPI

A single-addon Home Assistant repository that builds and runs
[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
as an HA addon — an OpenAI- / Claude-compatible HTTP proxy fronted by your
Claude Code (and other) OAuth subscriptions.

## Addons in this repository

- **[CLIProxyAPI](cliproxyapi/)** — the proxy server. See
  [cliproxyapi/README.md](cliproxyapi/README.md) for install and OAuth setup.

## Installation

### As a remote repository (recommended)

1. In Home Assistant, **Settings → Add-ons → Add-on Store**, three-dot menu →
   **Repositories**.
2. Paste this repo's Git URL and **Add**.
3. The **CLIProxyAPI** addon appears in the store list. Open it and click
   **Install**.

### As a local repository

1. Copy or clone this entire repository into `/addons/` on the HA host so the
   layout is `/addons/ha-addon-cliproxyapi/cliproxyapi/...`.
2. **Settings → Add-ons → Add-on Store**, three-dot menu → **Check for
   updates**. The addon shows up under "Local add-ons".

Tested target: Home Assistant Yellow (CM4, `aarch64`). The build also targets
`armv7` and `amd64`.
