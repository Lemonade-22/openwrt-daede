#!/usr/bin/env bash
# Build one honk OpenWrt package from the feed recipe, with a chosen feature set.
# native-ui is not built here: upstream already publishes that apk.
#   clash  defaults (clash-api) plus ebpf, no embedded doona
#   bare   ebpf only, no clash-api and no embedded doona
set -euo pipefail
variant=${HONK_VARIANT:?HONK_VARIANT is clash or bare}
repo=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}
feed=${HONK_FEED_DIR:?HONK_FEED_DIR is required}
arch=${OPENWRT_ARCH:?OPENWRT_ARCH is required}
cd "${SDK_DIR:?SDK_DIR is required}"
orig="$feed/honk/build.sh.orig"
if [[ ! -f "$orig" ]]; then cp "$feed/honk/build.sh" "$orig"; fi
cp "$orig" "$feed/honk/build.sh"
python3 - "$feed/honk/build.sh" "$variant" <<'PY'
import pathlib, sys
path, variant = sys.argv[1:]
file = pathlib.Path(path)
file_text = file.read_text()
token = "--features ebpf,native-ui"
if token not in file_text:
    raise SystemExit("cargo feature token not found")
replacement = {
    "clash": "--features ebpf",
    "bare": "--no-default-features --features ebpf",
}[variant]
file_text = file_text.replace(token, replacement, 1)
old = """if ! grep -aq 'index.html' \"${binary}\"; then
  echo \"honk: ${binary} does not contain the embedded doona UI\" >&2
  exit 1
fi
echo \"honk: ${binary} contains the embedded doona UI\""""
fetch = """if [ ! -f \"ci/fetch-doona.sh\" ]; then
  echo \"honk: ci/fetch-doona.sh is missing, native-ui cannot be built\" >&2
  exit 1
fi
HONK_DOONA_DIR=\"$(bash ci/fetch-doona.sh \"${HONK_SRC}/.doona\")\"
export HONK_DOONA_DIR
if [ ! -f \"${HONK_DOONA_DIR}/index.html\" ]; then
  echo \"honk: ${HONK_DOONA_DIR} has no index.html\" >&2
  exit 1
fi
echo \"honk: embedding the doona UI from ${HONK_DOONA_DIR}\""""
if fetch not in file_text:
    raise SystemExit("doona fetch block not found")
file_text = file_text.replace(fetch, 'unset HONK_DOONA_DIR\necho "honk: not embedding a UI"', 1)
new = 'echo "honk: ${binary} built without native-ui"'
if old not in file_text:
    raise SystemExit("embedded-UI check not found")
file.write_text(file_text.replace(old, new, 1))
PY
make package/honk/clean V=s || true
rm -f "$feed/honk/src/honk-core"
if [[ -d bin/packages ]]; then find bin/packages -type f -name 'honk-*.apk' -delete; fi
make -j2 package/honk/compile V=s CONFIG_PACKAGE_honk=m CONFIG_PACKAGE_vmlinux-btf=
mapfile -t packages < <(find bin/packages -type f -name 'honk-*.apk')
[[ ${#packages[@]} == 1 ]] || { echo "Expected one honk APK for $variant, found ${#packages[@]}" >&2; exit 1; }
out="$repo/dist/cores/$arch"
mkdir -p "$out"
base=$(basename "${packages[0]}")
cp "${packages[0]}" "$out/${arch}-honk-${variant}-${base}"
staging_dir/host/bin/apk --allow-untrusted adbdump "${packages[0]}" > "$out/${arch}-honk-${variant}.txt"
grep -q "arch: $arch" "$out/${arch}-honk-${variant}.txt"
