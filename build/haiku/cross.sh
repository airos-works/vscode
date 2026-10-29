#!/usr/bin/env bash
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# Makes the code_oss package for x86_64 or arm64 on Linux from a stage that
# build.sh made:
#   build/haiku/cross.sh ARCH [stage directory] [output directory]
# The app's JavaScript is the same on every architecture; only the native
# modules differ. This does what native.sh and package.sh do on Haiku, with
# cross tools (arm64 air/OS has no compiler of its own; air/OS CI builds both
# architectures this way):
#   AIROS_SDK          an air/OS cross SDK's env.sh for ARCH (CROSS, SYSROOT),
#                      default /data1/airos/sdk/ARCH/env.sh
#   NODE_SOURCE        a Node.js 22 tree or headers tarball directory
#                      (node-v22.x-headers): node-gyp's include/node and
#                      common.gypi
#   HAIKU_HOST_TOOLS   a Haiku build's host tools (rc, xres, resattr, mimeset,
#                      package) and HAIKU_MIME_DB its MIME database; the
#                      tools keep attributes in that build's own store
#   AURORA_HOST_BINARY aurora-host for ARCH (the aurora package's
#                      data/aurora/aurora-host)
# The package requires aurora and cmd:node 22. x86_64 also requires ripgrep
# and git (HaikuPorts); arm64 has no packages of them, so there search and Git
# need them installed by hand.
set -euo pipefail
ARCH=${1:?usage: cross.sh x86_64|arm64 [stage directory] [output directory]}
case $ARCH in
	arm64) GYP_ARCH=arm64 EXTRA_REQUIRES="" ;;
	x86_64) GYP_ARCH=x64 EXTRA_REQUIRES=$'\tcmd:rg\n\tcmd:git\n' ;;
	*) echo "unknown architecture $ARCH" >&2; exit 1 ;;
esac
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STAGE=$(cd -- "${2:-$(dirname "$ROOT")/VSCode-haiku-stage}" && pwd)
OUT=${3:-$STAGE/packages}
# (the SDK's env.sh first: it names its own build's TOOLS and MIMEDB)
. "${AIROS_SDK:-/data1/airos/sdk/$ARCH/env.sh}"
NODE_SOURCE=${NODE_SOURCE:?a Node.js 22 tree or headers directory}
TOOLS=${HAIKU_HOST_TOOLS:?a Haiku build's objects/linux/x86_64/release/tools}
MIMEDB=${HAIKU_MIME_DB:?a Haiku build's objects/common/data/mime_db/mime_db}
HOST_BINARY=${AURORA_HOST_BINARY:?aurora-host for ARCH}
GYP=${GYP:-$(dirname "$(readlink -f "$(command -v npm)")")/../node_modules/node-gyp/bin/node-gyp.js}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/code-oss-$ARCH.XXXXXX")
trap '"$TOOLS/rm_attrs" -rf "$WORK" 2>/dev/null || rm -rf "$WORK"' EXIT

echo "== Native modules"
# (named node_modules: the build scripts require their helpers from it)
cp -a "$STAGE/native/node_modules" "$WORK/node_modules"
patch -d "$WORK/node_modules/node-pty" -p1 -s < "$STAGE/native/patches/node-pty.patch"
patch -d "$WORK/node_modules/@parcel/watcher" -p1 -s < "$STAGE/native/patches/parcel-watcher.patch"
# gyp's OS and the modules' "haiku" switch name the target, not this machine
export CC="${CROSS}gcc --sysroot=$SYSROOT" CXX="${CROSS}g++ --sysroot=$SYSROOT"
export LINK="$CXX" AR=${CROSS}ar RANLIB=${CROSS}ranlib
export CC_host=gcc CXX_host=g++ LINK_host=g++
MODULES=(@vscode/sqlite3/build/Release/vscode-sqlite3 @vscode/spdlog/build/Release/spdlog
	@vscode/native-watchdog/build/Release/watchdog node-pty/build/Release/pty
	@parcel/watcher/build/Release/watcher)
for module in "${MODULES[@]}"; do
	directory=$WORK/node_modules/${module%%/build/*}
	echo "${module%%/build/*}"
	(cd "$directory" && node "$GYP" rebuild --nodedir="$NODE_SOURCE" --arch=$GYP_ARCH -j "$(nproc)" \
		-- -DOS=haiku -Dhost_os=linux -Dhaiku=1 > build.log 2>&1) || {
		tail -30 "$directory/build.log"
		exit 1
	}
done

echo "== App"
VERSION=$(cat "$STAGE/VERSION")
# raise it for a new package of the same version
REVISION=4
NAME="Code - OSS"
PKG=$WORK/package
APP=$PKG/apps/CodeOSS
mkdir -p "$APP" "$PKG/bin" "$PKG/data/deskbar/menu/Developer" "$PKG/data/licenses"
cp -a "$STAGE/app" "$APP/app"
cp "$STAGE/aurora.json" "$APP/aurora.json"
for module in "${MODULES[@]}"; do
	mkdir -p "$(dirname "$APP/app/node_modules/$module")"
	cp "$WORK/node_modules/$module.node" "$APP/app/node_modules/$module.node"
	"${CROSS}strip" --strip-debug "$APP/app/node_modules/$module.node"
done
ln -s node_modules "$APP/app/node_modules.asar"
ln -s node_modules "$APP/app/node_modules.asar.unpacked"
mkdir -p "$APP/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64"
ln -s /boot/system/bin/rg "$APP/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg"
ln -s ../apps/CodeOSS/app/bin/code-oss "$PKG/bin/code-oss"

echo "== Launcher"
cp "$HOST_BINARY" "$APP/$NAME"
"${CROSS}strip" --strip-debug "$APP/$NAME"
"$TOOLS/rc/rc" -I "$STAGE" -o "$WORK/launcher.rsrc" "$STAGE/CodeOSS.rdef"
"$TOOLS/xres" -o "$APP/$NAME" "$WORK/launcher.rsrc"
# on Haiku xres and mimeset give the file its attributes; here resattr does
"$TOOLS/resattr/resattr" -O -o "$APP/$NAME" "$WORK/launcher.rsrc"
(cd "$PKG" && "$TOOLS/mimeset" --all -f --mimedb "$MIMEDB" "apps/CodeOSS/$NAME")
ln -s "../../../../apps/CodeOSS/$NAME" "$PKG/data/deskbar/menu/Developer/$NAME"
cp "$STAGE/LICENSE" "$PKG/data/licenses/Code - OSS"
cat > "$PKG/.PackageInfo" <<INFO
name			code_oss
version			$VERSION-$REVISION
architecture	$ARCH
summary			"Code - OSS, the open source build of Visual Studio Code"
description		"Code - OSS is the open source build of Visual Studio Code: a code \\
editor with debugging, Git, an integrated terminal, search and extensions. \\
This is an unofficial port to air/OS: it runs on Haiku with Aurora, keeps its \\
settings in ~/config/settings/Code - OSS, and installs extensions from Open VSX."
packager		"KunanyiOS contributors"
vendor			"KunanyiOS"
copyrights		{ "2015-2026 Microsoft Corporation" }
licenses		{ "MIT" }
urls			{ "https://github.com/jmgasper/vscode" }
provides {
	code_oss = $VERSION
	app:Code_OSS = $VERSION
	cmd:code_oss = $VERSION
}
requires {
	haiku
	aurora >= 0.3
	cmd:node >= 22
${EXTRA_REQUIRES}}
INFO
mkdir -p "$OUT"
FILE=$OUT/code_oss-$VERSION-$REVISION-$ARCH.hpkg
rm -f "$FILE"
"$TOOLS/package/package" create -q -C "$PKG" "$FILE"
echo "$FILE"
