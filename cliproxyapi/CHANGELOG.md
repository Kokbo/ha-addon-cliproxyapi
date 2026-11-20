# Changelog

## 0.3.4

- Drop `armv7`: Home Assistant no longer supports it (since 2025.12) and the
  new multi-platform base images don't include it. aarch64 and amd64 are
  unchanged.
- Move the base image from the deprecated `build.yaml` into the Dockerfile
  (`ghcr.io/home-assistant/base:3.22`, the multi-platform form of the same
  image).
- Full documentation moved from `README.md` to `DOCS.md`, so it shows on the
  app's Documentation tab; `README.md` is now a short store introduction.
- Add a translation for the port description.
- `url` and `repository.yaml` now point to this repository instead of upstream.

## 0.3.3

- Update CLIProxyAPI to [v8.0.79](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v8.0.79) ([changes since v8.0.4](https://github.com/router-for-me/CLIProxyAPI/compare/v8.0.4...v8.0.79)).

## 0.3.2

- Replace the obsolete `watchdog` option with a Docker `HEALTHCHECK` on `/healthz`.
- Drop the redundant `boot: auto` option.
- Upstream CLIProxyAPI releases now arrive automatically, tested in CI first.

## 0.3.1

- Promote upstream's web management panel as the primary provider login flow.

## 0.3.0

- Pin CLIProxyAPI to [v8.0.4](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v8.0.4).
- Generate a random API key on first boot.
- Only allow the HA ingress proxy to reach the ttyd auth shell.

## 0.2.3

- Build CLIProxyAPI from upstream `main`.

## 0.2.2

- Update CLIProxyAPI to v7.1.22.

## 0.2.1

- Fix `*-login` commands not found in the auth shell.

## 0.2.0

- Add an in-add-on ttyd auth shell for OAuth bootstrap.

## 0.1.1

- Fix `BUILD_FROM` ARG scope, rename the example config, drop deprecated build args.

## 0.1.0

- Initial release.
