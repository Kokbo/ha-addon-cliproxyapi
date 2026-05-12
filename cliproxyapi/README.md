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

## Installation (local addon repository)

1. SSH or Samba into your Home Assistant host.
2. Copy this folder (the directory containing `config.yaml`, `Dockerfile`,
   `run.sh`) into `/addons/cliproxyapi/` on the host.
3. In Home Assistant, open **Settings → Add-ons → Add-on Store**, click the
   three-dot menu → **Check for updates**. "Local add-ons" should now list
   **CLIProxyAPI**.
4. Open the addon and click **Install**. The first build clones and compiles
   the upstream Go binary — expect several minutes on a CM4.
5. Start the addon. The first start writes a default config and immediately
   logs a warning telling you to edit it — that's expected.

To pin a specific upstream version, edit `CLIPROXYAPI_VERSION` in
[build.yaml](build.yaml) (default: `main`) before installing.

## First-time setup: obtaining OAuth tokens

The Claude Code / Codex / Gemini OAuth flows require a browser, which Home
Assistant doesn't have. Do the auth dance on a regular workstation, then copy
the resulting token files to the addon's auth directory.

1. On a machine with a browser, install the Claude Code CLI and sign in:
   ```
   npm install -g @anthropic-ai/claude-code
   claude
   ```
   Complete the OAuth flow in the browser window it opens.

2. CLIProxyAPI looks for token files under `~/.cli-proxy-api/` by default,
   but the Claude Code CLI itself writes to `~/.claude/`. Check both:
   - macOS / Linux: `~/.cli-proxy-api/` and `~/.claude/`
   - Windows: `%USERPROFILE%\.cli-proxy-api\` and `%USERPROFILE%\.claude\`

   You may need to run CLIProxyAPI once locally (`./CLIProxyAPI --login`-style
   flows documented in the upstream README) to mint the
   `~/.cli-proxy-api/*.json` files it expects. Follow the auth instructions
   in the [upstream README](https://github.com/router-for-me/CLIProxyAPI)
   for the specific provider you want (Claude, Codex, Gemini, Antigravity).

3. Copy every `*.json` file produced under `~/.cli-proxy-api/` into the
   addon's auth directory on the HA host:
   ```
   /config/cliproxyapi/.cli-proxy-api/
   ```
   Use the Samba share addon, the SSH/File editor addon, or `scp`.

4. Restart the CLIProxyAPI addon. The startup log should list the loaded
   credentials.

## Configuration

After the first start, edit `/config/cliproxyapi/config.yaml`. The two fields
you almost certainly need to change:

- **`api-keys`** — replace the `your-api-key-N` placeholders with at least one
  long, random secret. Clients authenticate by sending this as a bearer token
  (`Authorization: Bearer <your-key>` for OpenAI-shaped requests, or
  `x-api-key: <your-key>` for Anthropic-shaped requests).
- **`auth-dir`** — already preset to `/config/cliproxyapi/.cli-proxy-api`.
  Leave it alone unless you have a reason.

Optional sections (Gemini API keys, Codex/Claude/Vertex API keys, OpenAI
compatibility providers, payload rewriting, model aliases, etc.) are all
commented out in the example. Uncomment and fill in only what you need.

Restart the addon after editing `config.yaml`.

## Usage

Point any OpenAI- or Anthropic-compatible client at the addon:

- Base URL: `http://<home-assistant-ip>:8317`
- OpenAI-style endpoints: `/v1/chat/completions`, `/v1/models`, ...
- Anthropic-style endpoints: `/v1/messages`, ...
- Auth: bearer token / `x-api-key` set to one of your `api-keys`.

Quick smoke test from another machine on the LAN:

```
curl -H "Authorization: Bearer your-api-key-1" \
     http://<ha-ip>:8317/v1/models
```

Known-good clients: Open WebUI, Cline (VS Code), Continue, LibreChat, plain
`curl` / SDK calls.

## Token refresh and maintenance

OAuth tokens expire. CLIProxyAPI refreshes them in the background while they
remain valid, but if a refresh token is itself revoked or expires, requests
will start failing with auth errors in the addon log. When that happens:

1. Re-run the OAuth flow on a browser machine (step 1–2 of "First-time
   setup").
2. Replace the JSON files under
   `/config/cliproxyapi/.cli-proxy-api/` with the new ones.
3. Restart the addon.

Keep a backup of `/config/cliproxyapi/` — losing the auth directory means
re-doing the OAuth dance for every provider.

## Updating CLIProxyAPI

The upstream version is pinned by the `CLIPROXYAPI_VERSION` build arg in
[build.yaml](build.yaml). To upgrade:

1. Edit `build.yaml`, change `CLIPROXYAPI_VERSION` to the tag or branch you
   want (e.g. `v7.4.0`, or leave at `main`).
2. Bump `version` in `config.yaml` so Home Assistant offers a "Rebuild".
3. Rebuild from the addon page.
