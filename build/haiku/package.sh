#!/bin/bash
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.

# Makes the code_oss package on Haiku from a stage that build/haiku/build.sh
# made and native.sh completed:
#   ./package.sh <output directory>
# The app's launcher is Aurora's aurora-host (AURORA_HOST_BINARY, or the
# installed aurora package's) with Code - OSS's name, icon and signature.
set -euo pipefail
STAGE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUT=${1:?output directory}
VERSION=$(cat "$STAGE/VERSION")
# The package's revision: raise it for a new package of the same version
# (pkgman does not replace an installed package with an equal version).
REVISION=1
ARCH=$(uname -m)
HOST_BINARY=${AURORA_HOST_BINARY:-/boot/system/data/aurora/aurora-host}
NAME="Code - OSS"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/code-oss-package.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
PKG=$WORK/package
APP=$PKG/apps/CodeOSS

for module in @vscode/sqlite3/build/Release/vscode-sqlite3 @vscode/spdlog/build/Release/spdlog node-pty/build/Release/pty \
	@parcel/watcher/build/Release/watcher; do
	[ -f "$STAGE/app/node_modules/$module.node" ] || { echo "No $module.node: run native.sh first" >&2; exit 1; }
done

mkdir -p "$APP" "$PKG/bin" "$PKG/data/deskbar/menu/Applications" "$PKG/data/licenses"
cp -a "$STAGE/app" "$APP/app"
cp "$STAGE/aurora.json" "$APP/aurora.json"

echo "== App"
# Built apps look for their modules in node_modules.asar (amdX, the agent
# host): on Haiku they are plain files.
ln -s node_modules "$APP/app/node_modules.asar"
ln -s node_modules "$APP/app/node_modules.asar.unpacked"
# Search runs Haiku's ripgrep where the ripgrep package keeps Linux's.
mkdir -p "$APP/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64"
ln -s /boot/system/bin/rg "$APP/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg"
ln -s ../apps/CodeOSS/app/bin/code-oss "$PKG/bin/code-oss"

echo "== Launcher"
cp "$HOST_BINARY" "$APP/$NAME"
strip --strip-debug "$APP/$NAME"
rc -I "$STAGE" -o "$WORK/launcher.rsrc" "$STAGE/CodeOSS.rdef"
xres -o "$APP/$NAME" "$WORK/launcher.rsrc"
mimeset -f "$APP/$NAME"
ln -s "../../../../apps/CodeOSS/$NAME" "$PKG/data/deskbar/menu/Applications/$NAME"
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
	cmd:rg
	cmd:git
}
INFO
mkdir -p "$OUT"
FILE=$OUT/code_oss-$VERSION-$REVISION-$ARCH.hpkg
rm -f "$FILE"
package create -C "$PKG" "$FILE"
echo "$FILE"
