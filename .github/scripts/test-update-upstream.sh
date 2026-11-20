#!/usr/bin/env bash
# Offline tests for update-upstream.sh. Each case runs the script on a scratch
# copy of the repo with generated release data, relative to the current pin.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$here/update-upstream.sh"

current="$(sed -nE 's/^ARG CLIPROXYAPI_VERSION=(.*)$/\1/p' "$repo/cliproxyapi/Dockerfile")"
addon="$(sed -nE 's/^version: "?([0-9.]+)"?$/\1/p' "$repo/cliproxyapi/config.yaml")"
IFS=. read -r M m p <<< "${current#v}"
IFS=. read -r aM am ap <<< "$addon"
next_addon="$aM.$am.$((ap + 1))"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

# release TAG [prerelease] [draft] ARCH... -> one release object
release() {
    local tag="$1" pre="$2" draft="$3"; shift 3
    local v="${tag#v}" names=()
    for a in "$@"; do names+=("CLIProxyAPI_${v}_linux_${a}.tar.gz" "CLIProxyAPI_${v}_linux_${a}_no-plugin.tar.gz"); done
    names+=("CLIProxyAPI_${v}_windows_amd64.zip" "checksums.txt")
    jq -n --arg tag "$tag" --argjson pre "$pre" --argjson draft "$draft" \
        '{tag_name: $tag, prerelease: $pre, draft: $draft, assets: ($ARGS.positional | map({name: .}))}' \
        --args "${names[@]}"
}

# run_case NAME EXPECT_UPDATED EXPECT_LATEST RELEASE_JSON...
run_case() {
    local name="$1" want_updated="$2" want_latest="$3"; shift 3
    local dir="$work/$name"
    mkdir -p "$dir/repo"
    cp -r "$repo/cliproxyapi" "$repo/README.md" "$repo/repository.yaml" "$dir/repo/"
    printf '%s\n' "$@" | jq -s . > "$dir/releases.json"
    local out="$dir/github_output" log="$dir/log"
    : > "$out"
    if ! REPO_ROOT="$dir/repo" UPSTREAM_RELEASES_FILE="$dir/releases.json" GITHUB_OUTPUT="$out" \
        bash "$script" > "$log" 2>&1; then
        echo "FAIL $name: script exited non-zero"; sed 's/^/    /' "$log"; fail=1; return
    fi
    local got_updated got_latest
    got_updated="$(sed -n 's/^updated=//p' "$out")"
    got_latest="$(sed -n 's/^latest=//p' "$out")"
    if [ "$got_updated" != "$want_updated" ] || [ "$got_latest" != "$want_latest" ]; then
        echo "FAIL $name: updated=$got_updated latest=$got_latest (want $want_updated $want_latest)"
        sed 's/^/    /' "$log"; fail=1; return
    fi
    local r="$dir/repo"
    if [ "$want_updated" = true ]; then
        if ! grep -qxF "ARG CLIPROXYAPI_VERSION=$want_latest" "$r/cliproxyapi/Dockerfile" ||
            ! grep -qxF "version: \"$next_addon\"" "$r/cliproxyapi/config.yaml" ||
            ! grep -qxF "## $next_addon" "$r/cliproxyapi/CHANGELOG.md" ||
            ! grep -qF "/compare/$current...$want_latest)" "$r/cliproxyapi/CHANGELOG.md" ||
            grep -rqwF --exclude=CHANGELOG.md -- "$current" "$r"; then
            echo "FAIL $name: files not updated as expected"; fail=1; return
        fi
    elif ! diff -r "$repo/cliproxyapi" "$r/cliproxyapi" > /dev/null; then
        echo "FAIL $name: files changed without an update"; fail=1; return
    fi
    echo "ok   $name (updated=$got_updated latest=$got_latest)"
}

newer="v$M.$m.$((p + 1))"
newer2="v$M.$m.$((p + 2))"
minor="v$M.$((m + 1)).0"
major="v$((M + 1)).0.0"

run_case newer true "$newer2" \
    "$(release "$newer2" false false amd64 aarch64)" \
    "$(release "$newer" false false amd64 aarch64)" \
    "$(release "$current" false false amd64 aarch64)"

run_case same-version false "$current" \
    "$(release "$current" false false amd64 aarch64)" \
    "$(release "v$M.$m.$((p > 0 ? p - 1 : 0))" false false amd64 aarch64)"

run_case pre-release true "$newer" \
    "$(release "$minor" true false amd64 aarch64)" \
    "$(release "${major}-rc1" false false amd64 aarch64)" \
    "$(release "$newer2-0" false false amd64 aarch64)" \
    "$(release "$newer" false false amd64 aarch64)" \
    "$(release "$current" false false amd64 aarch64)"

run_case draft false "$current" \
    "$(release "$newer" false true amd64 aarch64)" \
    "$(release "$current" false false amd64 aarch64)"

run_case single-arch-falls-back true "$newer" \
    "$(release "$newer2" false false amd64)" \
    "$(release "$newer" false false amd64 aarch64)" \
    "$(release "$current" false false amd64 aarch64)"

run_case single-arch-only false "$current" \
    "$(release "$newer" false false aarch64)" \
    "$(release "$current" false false amd64 aarch64)"

# A pin the script doesn't know about must fail loudly.
dir="$work/unknown-pin"; mkdir -p "$dir/repo"
cp -r "$repo/cliproxyapi" "$repo/README.md" "$repo/repository.yaml" "$dir/repo/"
echo "Pinned to $current here too." >> "$dir/repo/README.md"
release "$newer" false false amd64 aarch64 | jq -s . > "$dir/releases.json"
if REPO_ROOT="$dir/repo" UPSTREAM_RELEASES_FILE="$dir/releases.json" bash "$script" > "$dir/log" 2>&1; then
    echo "FAIL unknown-pin: script succeeded"; fail=1
elif grep -q "still referenced" "$dir/log"; then
    echo "ok   unknown-pin (failed loudly)"
else
    echo "FAIL unknown-pin: wrong error"; sed 's/^/    /' "$dir/log"; fail=1
fi

exit "$fail"
