# Home Assistant Addon: CLIProxyAPI

A Home Assistant addon that wraps
[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI),
exposing your Claude Code, Codex, Gemini, Grok/xAI, and other OAuth providers
as an OpenAI- and Claude-compatible HTTP API on `http://<ha-ip>:8317`.

Tested target: Home Assistant Yellow (CM4, aarch64). The build also produces
images for `armv7` and `amd64`.

## What this addon does

CLIProxyAPI lets local clients (Open WebUI, Cline, Continue, LibreChat, custom
scripts, etc.) talk to your Claude Code / Codex / Gemini / Antigravity / xAI
OAuth sessions through standard OpenAI- or Anthropic-shaped HTTP endpoints. The
addon runs the server alongside Home Assistant, persisting OAuth tokens and
config under `/config/cliproxyapi/`.

There are two ways to log in to providers, neither needing SSH, Samba or a
local CLIProxyAPI install:

- **Web management panel (recommended)** — upstream's browser UI at
  `http://<ha-ip>:8317/management.html`. Click a provider, sign in, done.
- **Web terminal (fallback)** — a `ttyd` shell behind HA ingress
  (**Open Web UI**) with `*-login` helpers. Needed for Gemini, and handy for
  `edit-config` and troubleshooting.

## Installation

1. In Home Assistant, **Settings → Add-ons → Add-on Store**, three-dot menu →
   **Repositories**. Add this repo's Git URL, or copy the parent directory
   into `/addons/` and use **Check for updates**.
2. Open **CLIProxyAPI** and click **Install**. The first build clones and
   compiles the upstream Go server from source; budget several minutes on a
   CM4.
3. Start the addon. On first boot it creates `/config/cliproxyapi/` with a
   default config (including one randomly generated API key) and an empty
   auth dir.

This add-on release builds upstream CLIProxyAPI `v8.0.4` by default. To pin a
different upstream version, change the `CLIPROXYAPI_VERSION` default in
[Dockerfile](Dockerfile) before installing.

## First-time setup

### 1. Enable the web management panel (once)

1. With the addon running, click **Open Web UI** and run `edit-config`.
2. Under `remote-management:` set:
   ```yaml
   remote-management:
     allow-remote: true
     secret-key: "a-long-random-password"
   ```
   The plaintext key is hashed in place on the next start. Keep your own copy.
3. Save, exit, and run `restart-api`. The addon log now shows
   `Web panel: http://<ha-ip>:8317/management.html`.

### 2. Log in to your providers

1. Open `http://<ha-ip>:8317/management.html` and log in with the management
   `secret-key`. If it asks for the server address, use `http://<ha-ip>:8317`.
2. Go to the OAuth login section and pick a provider (Claude, Codex,
   Antigravity, Kimi, xAI, ...). Sign in on the page that opens.
3. If the provider finishes on a `localhost` URL that fails to load, that is
   expected: copy the full URL from the browser's address bar and paste it
   into the panel's callback field. No port forwarding needed.
4. The new credential appears under the panel's auth files. CLIProxyAPI picks
   it up automatically — no restart needed.

Gemini CLI login isn't offered in the panel; use `gemini-login` in the
terminal (see below).

### 3. Get the API key for your clients

In the terminal run `edit-config` and copy the key under `api-keys:`
(generated on first boot). Add more keys or replace it with your own long,
random secret if you like, then `restart-api`.

## Alternative: log in via the web terminal

1. With the addon running, click **Open Web UI**. A terminal opens in your
   browser, authenticated via HA ingress. A banner lists the available
   commands.

2. Run the login command for the provider you want:

   | Command             | Provider / flow                                  |
   |---------------------|--------------------------------------------------|
   | `claude-login`      | Claude (Anthropic) — paste-back code, no callback|
   | `codex-login`       | Codex — **device code flow** (recommended)       |
   | `codex-oauth-login` | Codex — OAuth web flow (needs reachable callback)|
   | `gemini-login`      | Google / Gemini — OAuth (see Gemini caveat)      |
   | `antigravity-login` | Antigravity (Google) — OAuth                     |
   | `kimi-login`        | Kimi (Moonshot) — OAuth                          |
   | `xai-login`         | xAI / Grok — OAuth                               |

3. The CLI prints a URL. Open it on any device with a browser, sign in,
   complete the consent prompt, then either copy the displayed code back into
   the terminal (Claude, device-code flows) or wait for the callback
   (OAuth-callback flows — see Gemini caveat below).

4. `list-auths` should now show `*.json` files in
   `/config/cliproxyapi/.cli-proxy-api/`.

5. `restart-api`. The CLIProxyAPI service bounces and picks up the new tokens
   and config. The API is now live on `http://<ha-ip>:8317`.

### Gemini OAuth caveat

`gemini-login` (Google OAuth) wants to redirect back to a `localhost:<port>`
URL on the machine that opened the browser. If you run it from the HA
terminal, that callback will hit the addon container — not your laptop — and
likely fail. Two workarounds:

- **SSH local-forward** the callback port from your workstation to the addon
  before clicking the OAuth URL, e.g.
  `ssh -L 8085:127.0.0.1:8085 <ha-host>`. Use
  `--oauth-callback-port 8085` if you need to pin the port.
- **Do the auth on a workstation**, then copy the resulting
  `~/.cli-proxy-api/*.json` files into `/config/cliproxyapi/.cli-proxy-api/`
  on the HA host (via the SSH or Samba addon).

`codex-oauth-login` has the same problem; prefer `codex-login` (device code
flow) or the web panel, neither of which needs a callback.

## Configuration

Runtime config lives at `/config/cliproxyapi/config.yaml`. The example seeded
on first boot has only the obvious fields enabled; everything else is
commented out. The fields you almost certainly need to touch:

- **`api-keys`** — long, random secrets. Clients send one of these as
  `Authorization: Bearer <key>` (OpenAI-shaped) or `x-api-key: <key>`
  (Anthropic-shaped). **Never leave `your-api-key-1/2/3` in this list:**
  CLIProxyAPI then disables every proxy endpoint (HTTP 403, logged as
  `unsafe example API key configured`), which clients such as Open WebUI
  report as a network error. The addon logs an error at startup if it
  finds them.
- **`auth-dir`** — already preset to `/config/cliproxyapi/.cli-proxy-api`.
  Leave it alone unless you have a reason.

Optional sections (Gemini/Codex/Claude/Vertex API keys, OpenAI compatibility
providers, payload rewriting, model aliases, etc.) are all commented out in
the example. Uncomment and fill in only what you need, then `restart-api`.

## Usage

Point any OpenAI- or Anthropic-compatible client at the addon:

- Base URL: `http://<home-assistant-ip>:8317`
- OpenAI-style endpoints: `/v1/chat/completions`, `/v1/models`, ...
- Anthropic-style endpoints: `/v1/messages`, ...
- Auth: bearer token / `x-api-key` set to one of your `api-keys`.

Smoke test from any LAN client:

```
curl -H "Authorization: Bearer <your-api-key>" \
     http://<ha-ip>:8317/v1/models
```

Known-good clients: Open WebUI, Cline (VS Code), Continue, LibreChat, plain
`curl` / SDK calls.

## Token refresh and maintenance

OAuth tokens expire; CLIProxyAPI refreshes them silently while their refresh
tokens remain valid. If a refresh token is revoked or expires you'll see auth
errors in the addon log. To recover:

- **Web panel:** log in to the provider again from the OAuth login section
  (no restart needed), or
- **Terminal:** **Open Web UI**, re-run the relevant `*-login` command, then
  `restart-api`.

Keep a backup of `/config/cliproxyapi/` — losing the auth directory means
re-doing the OAuth dance for every provider.

## Security notes

- The web terminal is a root shell with access to your OAuth tokens. It is
  only reachable through Home Assistant ingress: ttyd listens on loopback and
  an nginx gate on the ingress port admits only the HA ingress proxy
  (`172.30.32.2`), so other addons on the internal network can't reach it.
- The auth dir is `chmod 700` and `config.yaml` is `chmod 600` on every boot.
- Port 8317 is exposed on your LAN and protected only by `api-keys`; don't
  forward it to the internet.
- With `allow-remote: true` the management API and panel on 8317 are also
  reachable from your LAN, guarded by the management `secret-key` (full admin
  rights, including your credentials). Use a long random key; upstream bans
  an IP for 30 minutes after repeated wrong keys. If you only log in rarely,
  you can set `allow-remote: false` again afterwards.
- The panel page itself is downloaded from GitHub
  (`panel-github-repository`) on first use and auto-updated; set
  `remote-management.disable-control-panel: true` to turn it off entirely.

## Updating CLIProxyAPI

The upstream version is pinned by `ARG CLIPROXYAPI_VERSION=v8.0.4` in
[Dockerfile](Dockerfile). To upgrade:

1. Edit `Dockerfile`, change the `CLIPROXYAPI_VERSION` default to the release
   tag you want (e.g. `v8.1.0`). Prefer tags over branches such as `main`:
   a branch isn't reproducible and Docker may reuse a cached clone, so a
   rebuild can silently keep the old code.
2. Bump `version` in [config.yaml](config.yaml) so HA offers a Rebuild.
3. Rebuild from the addon page.
