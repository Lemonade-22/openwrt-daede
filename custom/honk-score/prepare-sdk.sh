#!/usr/bin/env bash
# Resolve one published A53 SDK, verify its checksum, and export its directory.
set -euo pipefail
version=${OPENWRT_VERSION:?OPENWRT_VERSION is required}
[[ "$version" =~ ^([0-9]{2})\.([0-9]{2})\.([0-9]+)$ ]] || { echo 'Use a stable release such as 25.12.6' >&2; exit 1; }
(( 10#${BASH_REMATCH[1]} * 100 + 10#${BASH_REMATCH[2]} >= 2512 )) || { echo 'OpenWrt 25.12 or newer is required' >&2; exit 1; }
root=${RUNNER_TEMP:?RUNNER_TEMP is required}/honk-score-sdk
mkdir -p "$root"
base="https://downloads.openwrt.org/releases/$version/targets/mediatek/filogic"
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
sdk=${directories[0]}
grep -q '^CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"$' "$sdk/.config" || { echo 'SDK is not aarch64_cortex-a53' >&2; exit 1; }
{
    echo "SDK_DIR=$sdk"
    echo "SDK_URL=$base/$name"
    echo "SDK_SHA256=$checksum"
} >> "${GITHUB_ENV:?GITHUB_ENV is required}"
