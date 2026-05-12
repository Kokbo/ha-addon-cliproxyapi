# Home Assistant Addon: CLIProxyAPI

A Home Assistant addon that wraps
[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI),
exposing your Claude Code OAuth subscription (and other supported providers)
as an OpenAI- and Claude-compatible HTTP API on `http://<ha-ip>:8317`.

Tested target: Home Assistant Yellow (CM4, aarch64). The build also produces
images for `armv7` and `amd64`.

## What this addon does

CLIProxyAPI lets local clients (Open WebUI, Cline, Continue, LibreChat, custom
scripts, etc.) talk to your Claude Code / Codex / Gemini / Antigravity OAuth
sessions through standard OpenAI- or Anthropic-shaped HTTP endpoints. The
addon runs the server alongside Home Assistant, persisting OAuth tokens and
config under `/config/cliproxyapi/`.

A second process — an `ttyd` web terminal exposed via HA ingress — is the
recommended way to bootstrap OAuth credentials. No SSH, no Samba copy, no
local CLIProxyAPI install required.

## Installation

1. In Home Assistant, **Settings → Add-ons → Add-on Store**, three-dot menu →
   **Repositories**. Add this repo's Git URL, or copy the parent directory
   into `/addons/` and use **Check for updates**.
2. Open **CLIProxyAPI** and click **Install**. The first build clones and
   compiles the upstream Go server from source; budget several minutes on a
   CM4.
3. Start the addon. On first boot it creates `/config/cliproxyapi/` with a
   default config and an empty auth dir, and logs a warning telling you to
   bootstrap OAuth.

To pin a specific upstream version, change the `CLIPROXYAPI_VERSION` default
in [Dockerfile](Dockerfile) (default: `main`) before installing.

## First-time setup: OAuth via the in-addon web terminal

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

3. The CLI prints a URL. Open it on any device with a browser, sign in,
   complete the consent prompt, then either copy the displayed code back into
   the terminal (Claude, device-code flows) or wait for the callback
   (OAuth-callback flows — see Gemini caveat below).

4. `list-auths` should now show `*.json` files in
   `/config/cliproxyapi/.cli-proxy-api/`.

5. Before the API is useful you must also set at least one bearer token.
   In the same terminal:
   ```
   edit-config
   ```
   replace the `your-api-key-N` placeholders under `api-keys:` with a long,
   random secret, save, and exit.

6. `restart-api`. The CLIProxyAPI service bounces and picks up the new tokens
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

`codex-login` is similar; prefer `codex-login` (device code flow) which
doesn't need a callback.

## Configuration

Runtime config lives at `/config/cliproxyapi/config.yaml`. The example seeded
on first boot has only the obvious fields enabled; everything else is
commented out. The fields you almost certainly need to touch:

- **`api-keys`** — replace placeholders with long, random secrets. Clients
  send one of these as `Authorization: Bearer <key>` (OpenAI-shaped) or
  `x-api-key: <key>` (Anthropic-shaped).
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
curl -H "Authorization: Bearer your-api-key-1" \
     http://<ha-ip>:8317/v1/models
```

Known-good clients: Open WebUI, Cline (VS Code), Continue, LibreChat, plain
`curl` / SDK calls.

## Token refresh and maintenance

OAuth tokens expire; CLIProxyAPI refreshes them silently while their refresh
tokens remain valid. If a refresh token is revoked or expires you'll see auth
errors in the addon log. To recover:

1. **Open Web UI**, re-run the relevant `*-login` command.
2. `restart-api`.

Keep a backup of `/config/cliproxyapi/` — losing the auth directory means
re-doing the OAuth dance for every provider.

## Updating CLIProxyAPI

The upstream version is pinned by `ARG CLIPROXYAPI_VERSION=main` in
[Dockerfile](Dockerfile). To upgrade:

1. Edit `Dockerfile`, change the `CLIPROXYAPI_VERSION` default to the tag or
   branch you want (e.g. `v7.4.0`).
2. Bump `version` in [config.yaml](config.yaml) so HA offers a Rebuild.
3. Rebuild from the addon page.
