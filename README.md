# Home Assistant App Repository: CLIProxyAPI

[![CI][ci-badge]][ci-url]
[![App version][version-badge]](cliproxyapi/CHANGELOG.md)
![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[![Open your Home Assistant instance and show the add app repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FKokbo%2Fha-addon-cliproxyapi)

A single-app Home Assistant repository that builds and runs
[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
as an HA app (called add-ons before Home Assistant 2026.2) — an OpenAI- / Claude-compatible HTTP proxy fronted by your
Claude Code, Codex, Gemini, Grok/xAI, and other OAuth subscriptions.

## Apps in this repository

- **[CLIProxyAPI](cliproxyapi/)** — the proxy server. See
  [cliproxyapi/DOCS.md](cliproxyapi/DOCS.md) for install and OAuth setup.

## Installation

### As a remote repository (recommended)

1. Click the button above, or in Home Assistant go to **Settings → Apps → App
   store**, three-dot menu → **Repositories**.
2. Add `https://github.com/Kokbo/ha-addon-cliproxyapi`.
3. The **CLIProxyAPI** app appears in the store list. Open it and click
   **Install**.

### As a local repository

1. Copy or clone this entire repository into `/addons/` on the HA host so the
   layout is `/addons/ha-addon-cliproxyapi/cliproxyapi/...`.
2. **Settings → Apps → App store**, three-dot menu → **Check for
   updates**. The app shows up under "Local apps".

## Updates

New stable CLIProxyAPI releases are picked up automatically: a daily workflow
bumps the app, builds and starts it for every arch, and only then updates
`main`. See
[Updating CLIProxyAPI](cliproxyapi/DOCS.md#updating-cliproxyapi) for
failures and manual updates.

Tested target: Home Assistant Yellow (CM4, `aarch64`). The build also targets
`amd64`.

[ci-badge]: https://github.com/Kokbo/ha-addon-cliproxyapi/actions/workflows/ci.yaml/badge.svg
[ci-url]: https://github.com/Kokbo/ha-addon-cliproxyapi/actions/workflows/ci.yaml
[version-badge]: https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FKokbo%2Fha-addon-cliproxyapi%2Fmain%2Fcliproxyapi%2Fconfig.yaml&query=%24.version&label=app
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
