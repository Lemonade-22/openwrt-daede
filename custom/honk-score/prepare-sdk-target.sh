#!/usr/bin/env bash
# Resolve one published SDK for SDK_TARGET (for example mediatek/filogic).
set -euo pipefail
version=${OPENWRT_VERSION:?OPENWRT_VERSION is required}
target=${SDK_TARGET:?SDK_TARGET is required}
[[ "$version" =~ ^([0-9]{2})\.([0-9]{2})\.([0-9]+)$ ]] || { echo 'Use a stable release such as 25.12.6' >&2; exit 1; }
root=${RUNNER_TEMP:?RUNNER_TEMP is required}/honk-score-sdk
mkdir -p "$root"
base="https://downloads.openwrt.org/releases/$version/targets/$target"
curl -fsSL --retry 3 "$base/sha256sums" -o "$root/sha256sums"
mapfile -t entries < <(awk '$2 ~ /openwrt-sdk-.*Linux-x86_64\.tar\.(zst|xz)$/ { print }' "$root/sha256sums")
[[ ${#entries[@]} == 1 ]] || { echo "Expected one Linux x86_64 SDK, found ${#entries[@]}" >&2; exit 1; }
read -r checksum name <<< "${entries[0]}"
name=${name#\*}
curl -fL --retry 3 "$base/$name" -o "$root/$name"
printf '%s  %s\n' "$checksum" "$root/$name" | sha256sum -c -
mkdir -p "$root/unpacked"
tar -xf "$root/$name" -C "$root/unpacked"
mapfile -t directories < <(find "$root/unpacked" -mindepth 1 -maxdepth 1 -type d -name 'openwrt-sdk-*')
[[ ${#directories[@]} == 1 ]] || { echo 'Unexpected SDK layout' >&2; exit 1; }
{
  echo "SDK_DIR=${directories[0]}"
  echo "SDK_URL=$base/$name"
  echo "SDK_SHA256=$checksum"
} >> "${GITHUB_ENV:?GITHUB_ENV is required}"
