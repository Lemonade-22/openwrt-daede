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
HONK_VERSION="$HONK_VERSION" HONK_GIT_TAG="$HONK_GIT_TAG" \
    make -j2 package/honk/compile V=s CONFIG_PACKAGE_vmlinux-btf=
mapfile -t packages < <(find bin/packages -type f -name 'honk-*.apk')
[[ ${#packages[@]} == 1 ]] || { echo "Expected one honk APK, found ${#packages[@]}" >&2; exit 1; }
mkdir -p "$repo/dist/honk"
cp "${packages[0]}" "$repo/dist/honk/"
staging_dir/host/bin/apk --allow-untrusted adbdump "${packages[0]}" > "$repo/dist/honk/honk-metadata.txt"
grep -q 'arch: aarch64_cortex-a53' "$repo/dist/honk/honk-metadata.txt"
python3 - "$repo/dist/honk/build-honk.json" <<'PY'
import json, os, sys
keys=('OPENWRT_VERSION','SDK_URL','SDK_SHA256','HONK_FEED_COMMIT','HONK_COMMIT','HONK_GIT_TAG','GITHUB_SHA')
json.dump({k:os.environ.get(k) for k in keys},open(sys.argv[1],'w'),indent=2)
PY
