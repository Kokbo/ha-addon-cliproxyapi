#!/usr/bin/env bash
# Bump the pinned CLIProxyAPI upstream release to the newest stable one.
#
# The add-on builds upstream from source: the Dockerfile clones the git tag in
# `ARG CLIPROXYAPI_VERSION=` and cross-compiles it for every add-on arch.
#
# A release qualifies when it is published (not a draft, not a pre-release),
# its tag is plain vX.Y.Z, and upstream attached a linux binary for every
# add-on arch that upstream ships binaries for (aarch64, amd64). That proves
# upstream's own builds finished for the release. Upstream ships nothing for
# armv7; that arch is proven only by CI compiling it (.github/workflows/ci.yaml).
#
# If the newest qualifying release is newer than the pin, the script updates
# every pin, bumps the add-on patch version in config.yaml and adds a
# CHANGELOG.md entry. It does not commit.
#
# Environment:
#   REPO_ROOT               repo checkout to edit (default: git toplevel)
#   UPSTREAM_REPO           owner/name on GitHub (default router-for-me/CLIProxyAPI)
#   UPSTREAM_RELEASES_FILE  read releases JSON (shape of GET /repos/{repo}/releases)
#                           from this file instead of the GitHub API
#   GITHUB_TOKEN / GH_TOKEN optional, raises the API rate limit
#   DRY_RUN=1               report what would change, edit nothing
#   GITHUB_OUTPUT           if set, updated/current/latest/addon_version are
#                           appended to it
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
UPSTREAM_REPO="${UPSTREAM_REPO:-router-for-me/CLIProxyAPI}"
UPSTREAM_RELEASES_FILE="${UPSTREAM_RELEASES_FILE:-}"
DRY_RUN="${DRY_RUN:-0}"

ADDON_DIR="$REPO_ROOT/cliproxyapi"
DOCKERFILE="$ADDON_DIR/Dockerfile"
CONFIG="$ADDON_DIR/config.yaml"
README="$ADDON_DIR/README.md"
CHANGELOG="$ADDON_DIR/CHANGELOG.md"
UPSTREAM_URL="https://github.com/$UPSTREAM_REPO"

die() { echo "::error::$*" >&2; exit 1; }
note() { echo "$*" >&2; }

# Replace a whole line matching $2 (ERE) in file $1 with $3, then prove the
# exact new line is present so a missed pin fails loudly.
replace_line() {
    local file="$1" pattern="$2" new="$3"
    grep -qE "$pattern" "$file" || die "$file: no line matches /$pattern/"
    NEW_LINE="$new" PATTERN="$pattern" awk '
        $0 ~ ENVIRON["PATTERN"] { print ENVIRON["NEW_LINE"]; next } { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    grep -qxF -- "$new" "$file" || die "$file: expected line not found after edit: $new"
}

version_gt() { # true if $1 > $2 (both X.Y.Z, optional leading v)
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "${1#v}" "${2#v}" | sort -V | tail -n1)" = "${1#v}" ]
}

emit() {
    echo "$1=$2"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}

# --- current state ----------------------------------------------------------

current="$(sed -nE 's/^ARG CLIPROXYAPI_VERSION=(.*)$/\1/p' "$DOCKERFILE")"
[ -n "$current" ] || die "$DOCKERFILE: no 'ARG CLIPROXYAPI_VERSION=' line"
[[ "$current" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "$DOCKERFILE: CLIPROXYAPI_VERSION=$current is not a plain vX.Y.Z tag"

addon_version="$(sed -nE 's/^version: "?([0-9]+\.[0-9]+\.[0-9]+)"?$/\1/p' "$CONFIG")"
[ -n "$addon_version" ] || die "$CONFIG: no 'version: \"X.Y.Z\"' line"

# Add-on arches from config.yaml's `arch:` list.
mapfile -t arches < <(awk '
    /^arch:/ { in_arch = 1; next }
    in_arch && /^[[:space:]]+-[[:space:]]/ { sub(/^[[:space:]]+-[[:space:]]+/, ""); gsub(/["'\'']/, ""); print; next }
    in_arch { exit }
' "$CONFIG")
[ "${#arches[@]}" -gt 0 ] || die "$CONFIG: empty or missing arch list"

# Release asset suffix that proves upstream built each arch.
required_assets=()
for arch in "${arches[@]}"; do
    case "$arch" in
        amd64)   required_assets+=("_linux_amd64.tar.gz") ;;
        aarch64) required_assets+=("_linux_aarch64.tar.gz") ;;
        armv7)   note "armv7: upstream ships no binary; compiled from source and verified by CI" ;;
        *)       die "unknown add-on arch '$arch': map it to an upstream asset in $0" ;;
    esac
done

# --- upstream releases --------------------------------------------------------

if [ -n "$UPSTREAM_RELEASES_FILE" ]; then
    releases="$(cat "$UPSTREAM_RELEASES_FILE")"
else
    token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    auth=()
    if [ -n "$token" ]; then auth=(-H "Authorization: Bearer $token"); fi
    releases="$(curl -fsSL --retry 3 "${auth[@]}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$UPSTREAM_REPO/releases?per_page=100")" \
        || die "could not fetch releases for $UPSTREAM_REPO"
fi

# Stable, plain vX.Y.Z releases, newest first: "<tag>\t<asset names joined by space>".
mapfile -t candidates < <(jq -r '
    .[] | select(.draft == false and .prerelease == false)
        | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))
        | [.tag_name, ([.assets[].name] | join(" "))] | @tsv
' <<< "$releases" | sort -t$'\t' -k1,1 -V -r)
[ "${#candidates[@]}" -gt 0 ] || die "no stable vX.Y.Z releases found for $UPSTREAM_REPO"

latest=""
newest_stable="${candidates[0]%%$'\t'*}"
for line in "${candidates[@]}"; do
    tag="${line%%$'\t'*}"
    assets=" ${line#*$'\t'} "
    missing=()
    for suffix in "${required_assets[@]}"; do
        [[ "$assets" =~ [^[:space:]]+"$suffix"[[:space:]] ]] || missing+=("$suffix")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        latest="$tag"
        break
    fi
    note "skip $tag: missing release assets ${missing[*]}"
    # Releases older than the pin can't be an update; stop looking.
    version_gt "$tag" "$current" || break
done

if [ -z "$latest" ]; then
    echo "::warning::no release newer than $current has assets for every arch (newest stable: $newest_stable)" >&2
    latest="$current"
elif [ "$latest" != "$newest_stable" ]; then
    echo "::warning::newest stable $newest_stable lacks assets for some arch; using $latest" >&2
fi

emit current "$current"
emit latest "$latest"

if ! version_gt "$latest" "$current"; then
    note "up to date: $current (newest qualifying release: $latest)"
    emit updated false
    exit 0
fi

IFS=. read -r major minor patch <<< "$addon_version"
new_addon_version="$major.$minor.$((patch + 1))"
emit addon_version "$new_addon_version"

if [ "$DRY_RUN" = 1 ] || [ "$DRY_RUN" = true ]; then
    note "dry run: would update $current -> $latest (add-on $addon_version -> $new_addon_version)"
    emit updated false
    exit 0
fi

note "updating CLIProxyAPI $current -> $latest (add-on $addon_version -> $new_addon_version)"

# --- edit every pin ------------------------------------------------------------

replace_line "$DOCKERFILE" '^ARG CLIPROXYAPI_VERSION=' "ARG CLIPROXYAPI_VERSION=$latest"
replace_line "$CONFIG" '^version: ' "version: \"$new_addon_version\""
# shellcheck disable=SC2016  # backticks are literal Markdown
replace_line "$README" '^This add-on release builds upstream CLIProxyAPI `v[0-9.]+` by default\.' \
    "This add-on release builds upstream CLIProxyAPI \`$latest\` by default. To pin a"
# shellcheck disable=SC2016
replace_line "$README" '^The upstream version is pinned by `ARG CLIPROXYAPI_VERSION=v[0-9.]+` in$' \
    "The upstream version is pinned by \`ARG CLIPROXYAPI_VERSION=$latest\` in"

entry_header="## $new_addon_version"
entry_line="- Update CLIProxyAPI to [$latest]($UPSTREAM_URL/releases/tag/$latest) ([changes since $current]($UPSTREAM_URL/compare/$current...$latest))."
if [ ! -f "$CHANGELOG" ]; then printf '# Changelog\n' > "$CHANGELOG"; fi
head -n1 "$CHANGELOG" | grep -qxF '# Changelog' || die "$CHANGELOG: first line must be '# Changelog'"
{
    head -n1 "$CHANGELOG"
    printf '\n%s\n\n%s\n' "$entry_header" "$entry_line"
    tail -n +2 "$CHANGELOG"
} > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
grep -qxF -- "$entry_header" "$CHANGELOG" || die "$CHANGELOG: entry header missing after edit"
grep -qxF -- "$entry_line" "$CHANGELOG" || die "$CHANGELOG: entry line missing after edit"

# Any pin this script doesn't know about would still name the old version.
shopt -s nullglob
scan=("$ADDON_DIR" "$REPO_ROOT"/*.md "$REPO_ROOT"/*.yaml)
shopt -u nullglob
if leftovers="$(grep -rnwF --exclude=CHANGELOG.md -- "$current" "${scan[@]}")"; then
    die "old version $current still referenced (add the pin to $0):"$'\n'"$leftovers"
fi

emit updated true
