#!/usr/bin/env bash
# Only the disposable build checkout is patched; upstream files stay pristine
# in the published fork. Can also be used manually on a clean source checkout.
set -euo pipefail
repo=${1:-$(git rev-parse --show-toplevel)}
overlay=$(cd -- "$(dirname -- "$0")" && pwd)
for patch in "$overlay"/patches/*.patch; do
    git -C "$repo" apply --check "$patch"
    git -C "$repo" apply "$patch"
done
python3 - "$repo/luci-app-daede/Makefile" <<'PY'
from pathlib import Path
import re, sys
path=Path(sys.argv[1])
text=path.read_text()
# apk (OpenWrt 25.12+) validates the package version: the -r part must be
# plain digits and only _alpha/_beta/_pre/_rc/_cvs/_svn/_git/_hg/_p may follow
# the numeric part, so the old '.honk1' release suffix cannot be published.
# Bump the version with the patch suffix instead; a dotted digit version is
# required so that a re-run cannot stack a second suffix.
text,count=re.subn(r'^PKG_VERSION:=(\d+(?:\.\d+)*)$',r'PKG_VERSION:=\1_p1',text,count=1,flags=re.M)
if count != 1:
    raise SystemExit('cannot locate upstream PKG_VERSION')
path.write_text(text)
PY
echo 'Applied honk/Score overlay to build checkout.'
