# Changelog

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
