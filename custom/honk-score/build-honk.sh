#!/usr/bin/env bash
set -euo pipefail
repo=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}
source "$repo/custom/honk-score/pins.env"
export HONK_FEED_COMMIT HONK_COMMIT HONK_GIT_TAG HONK_VERSION
cd "${SDK_DIR:?SDK_DIR is required}"
# Use the package recipe's own checked-in build script and kernel dependencies.
printf 'src-link honk %s\n' "${HONK_FEED_DIR:?HONK_FEED_DIR is required}" > feeds.conf
./scripts/feeds update honk
./scripts/feeds install -p honk honk
printf '\nCONFIG_PACKAGE_honk=m\n' >> .config
make defconfig
grep -q '^CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"$' .config || { echo 'SDK is not aarch64_cortex-a53' >&2; exit 1; }
HONK_VERSION="$HONK_VERSION" HONK_GIT_TAG="$HONK_GIT_TAG" \
    make -j2 package/honk/compile V=s CONFIG_PACKAGE_vmlinux-btf=
mapfile -t packages < <(find bin/packages -type f -name 'honk-*.apk')
[[ ${#packages[@]} == 1 ]] || { echo "Expected one honk APK, found ${#packages[@]}" >&2; exit 1; }
mkdir -p "$repo/dist/honk"
cp "${packages[0]}" "$repo/dist/honk/"

# Same recipe as daeuniverse/openwrt-packages build-vmlinux-btf.yml: the feed is
# already linked, so install the empty package and let the SDK package it.
# CONFIG_PACKAGE_vmlinux-btf= keeps the real per-kernel blob from being built.
./scripts/feeds install -p honk vmlinux-btf-builtin
make -j2 package/vmlinux-btf-builtin/compile V=s \
    CONFIG_PACKAGE_vmlinux-btf-builtin=m \
    CONFIG_PACKAGE_vmlinux-btf=
mapfile -t builtin < <(find bin/packages -type f -name 'vmlinux-btf-builtin-*.apk')
[[ ${#builtin[@]} == 1 ]] || { echo "Expected one vmlinux-btf-builtin APK, found ${#builtin[@]}" >&2; find bin/packages -type f | head; exit 1; }
cp "${builtin[0]}" "$repo/dist/honk/"
info="$(staging_dir/host/bin/apk --allow-untrusted adbdump "${builtin[0]}")"
grep -Eq '^ +- vmlinux-btf$' <<< "$info" \
  && grep -Eq '^  provider-priority: [1-9]' <<< "$info" \
  && grep -Eq '^  arch: noarch$' <<< "$info" \
  && grep -Eq '^  pre-install: ' <<< "$info" \
  || { echo "vmlinux-btf-builtin lacks its provide, priority, noarch or pre-install" >&2; printf '%s\n' "$info" | head -40; exit 1; }
staging_dir/host/bin/apk --allow-untrusted adbdump "${packages[0]}" > "$repo/dist/honk/honk-metadata.txt"
grep -q 'arch: aarch64_cortex-a53' "$repo/dist/honk/honk-metadata.txt"
python3 - "$repo/dist/honk/build-honk.json" <<'PY'
import json, os, sys
keys=('OPENWRT_VERSION','SDK_URL','SDK_SHA256','HONK_FEED_COMMIT','HONK_COMMIT','HONK_GIT_TAG','GITHUB_SHA')
json.dump({k:os.environ.get(k) for k in keys},open(sys.argv[1],'w'),indent=2)
PY
