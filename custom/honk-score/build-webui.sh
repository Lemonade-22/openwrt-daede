#!/usr/bin/env bash
# Build a separate static honk flavour; the upstream daed binary stays intact.
set -euo pipefail
repo=$(cd "${1:-.}" && pwd)
source "$repo/custom/honk-score/pins.env"
work=$(mktemp -d "${RUNNER_TEMP:-/tmp}/daede-honk-web.XXXXXX")
git clone --no-checkout https://github.com/daeuniverse/daed.git "$work/source"
git -C "$work/source" checkout --detach "$WEBUI_COMMIT"
for patch in "$repo"/custom/honk-score/webui-patches/*.patch; do
    git -C "$work/source" apply --check "$patch"
    git -C "$work/source" apply "$patch"
done
cd "$work/source"
npm install --global pnpm@10.24.0
pnpm install --frozen-lockfile --ignore-scripts
pnpm --filter @daeuniverse/dae-lang-core build
pnpm --filter @daeuniverse/dae-node-parser build
pnpm --filter @daeuniverse/dae-editor build
pnpm --filter @daeuniverse/dae-lsp build
pnpm --filter daed check-types
pnpm --filter daed exec vitest run src/honk/client.test.ts
VITE_HONK=1 pnpm --filter daed build
VITE_HONK=1 pnpm --filter daed exec vite build --config vite.honk-client.config.ts
dest="$repo/luci-app-daede/webui-dist"
mkdir -p "$dest/licenses"
cp -a apps/web/dist/. "$dest/"
cp LICENSE "$dest/licenses/daed-LICENSE"
cp apps/web/src/honk/dae/LICENSE "$dest/licenses/doona-GPL-3.0"
cat > "$dest/SOURCE.txt" <<EOF
daed WebUI: https://github.com/daeuniverse/daed/tree/$WEBUI_COMMIT
honk adaptation patch: https://github.com/Lemonade-22/openwrt-daede/tree/${GITHUB_SHA:-main}/custom/honk-score/webui-patches
doona text editors: https://github.com/Zakkaus/doona/tree/3b7845b076bfe9f55bb87694ab48b16a76ad3ca2/src/dae
Build: custom/honk-score/build-webui.sh; pnpm-lock.yaml in the pinned upstream.
No dae-wing or daed service is required for this honk flavour.
EOF
test -s "$dest/index.html"
test -s "$dest/honk-client.js"
