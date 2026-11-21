#!/usr/bin/env bash
# AeroStem LightShow firmware - reproducible build
#
# Fetches the pinned upstream source (upstream.env), applies the AeroStem
# patches in patches/, builds ArduCopter for each board and writes the
# firmware plus a complete source archive to dist/.
#
# Needs: git, python3 (empy 3.3.4, pymavlink, future, intelhex) and
# arm-none-eabi-gcc 10 (Ubuntu 22.04: apt install gcc-arm-none-eabi).
# The AeroStem H743 V1 bootloader is only proven with GCC 10.

set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
source ./upstream.env

BOARDS=${BOARDS:-AeroStemH743V1}
WORK=${WORK:-$ROOT/.work/src}
DIST=$ROOT/dist

GCC_MAJOR=$(arm-none-eabi-gcc -dumpversion | cut -d. -f1)
if [ "$GCC_MAJOR" != "10" ]; then
    echo "ERROR: arm-none-eabi-gcc 10 required (found $(arm-none-eabi-gcc -dumpversion))." >&2
    exit 1
fi

# 1. pinned upstream source
if [ ! -d "$WORK/.git" ]; then
    git init -q "$WORK"
    git -C "$WORK" remote add origin "$UPSTREAM_URL"
fi
git -C "$WORK" fetch -q --depth 1 origin "$UPSTREAM_COMMIT"
git -C "$WORK" checkout -q -f FETCH_HEAD
git -C "$WORK" clean -fdxq -e build
git -C "$WORK" submodule update --init --recursive --depth 1 -q

# 2. AeroStem patches
for p in "$ROOT"/patches/*.patch; do
    echo "applying $(basename "$p")"
    git -C "$WORK" apply --whitespace=nowarn "$p"
done

# bootloader: the patch carries the .hex; derive the identical .bin
python3 - "$WORK/Tools/bootloaders" <<'EOF'
import sys, glob, os
from intelhex import IntelHex
for h in glob.glob(os.path.join(sys.argv[1], "AeroStem*_bl.hex")):
    open(h[:-4] + ".bin", "wb").write(IntelHex(h).tobinstr())
EOF
if [ -n "${BL_SHA256_AeroStemH743V1:-}" ]; then
    echo "$BL_SHA256_AeroStemH743V1  $WORK/Tools/bootloaders/AeroStemH743V1_bl.bin" | sha256sum -c -
fi

# 3. build
VERSION=$(sed -n 's/.*THISFIRMWARE "AeroStem LightShow V\([0-9.]*\)".*/\1/p' "$WORK/ArduCopter/version.h")
mkdir -p "$DIST"
for b in $BOARDS; do
    (cd "$WORK" && ./waf configure --board "$b" && ./waf copter)
    bin="$WORK/build/$b/bin"
    cp "$bin/arducopter.apj"         "$DIST/${b}_lightshow_${VERSION}.apj"
    cp "$bin/arducopter_with_bl.hex" "$DIST/${b}_lightshow_${VERSION}_with_bl.hex"
    cp "$bin/arducopter.bin"         "$DIST/${b}_lightshow_${VERSION}.bin"
done

# 4. complete corresponding source (GPL-3.0), exactly as built
SRC_NAME="aerostem-lightshow-${VERSION}-source"
tar --exclude=.git --exclude=./build --exclude=./.venv \
    --transform "s,^\.,${SRC_NAME}," -C "$WORK" -cJf "$DIST/${SRC_NAME}.tar.xz" .

(cd "$DIST" && sha256sum ./*.apj ./*.hex ./*.bin ./*.tar.xz > SHA256SUMS)
echo "done: $DIST"
ls -la "$DIST"
