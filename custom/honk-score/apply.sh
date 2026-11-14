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
text,count=re.subn(r'^PKG_RELEASE:=(\S+)$',r'PKG_RELEASE:=\1.honk1',text,count=1,flags=re.M)
if count != 1:
    raise SystemExit('cannot locate upstream PKG_RELEASE')
path.write_text(text)
PY
echo 'Applied honk/Score overlay to build checkout.'
