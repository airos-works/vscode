#!/bin/sh
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.

# Builds the native Node.js modules of Code - OSS on Haiku, in a stage that
# build/haiku/build.sh made, and puts them into the stage's app: ./native.sh
# Needs gcc, make, python3, nodejs22_devel and devel:libuv (Haiku's Node.js
# uses the system's libuv, whose headers are not among Node.js's).
set -eu
STAGE=$(cd -- "$(dirname -- "$0")" && pwd)
MODULES=$STAGE/native/node_modules
APP=$STAGE/app/node_modules
NODE_HEADERS=${NODE_HEADERS:-/boot/system/develop/headers/node}
PYTHON=${PYTHON:-$(command -v python3 || command -v python3.12 || command -v python3.10)}
GYP=${GYP:-/boot/system/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js}
export PYTHON npm_config_python=$PYTHON

# node-gyp wants a Node.js tree: include/node is the installed headers.
NODEDIR=$STAGE/native/nodedir
mkdir -p "$NODEDIR/include"
ln -sfn "$NODE_HEADERS" "$NODEDIR/include/node"

# Haiku support for node-pty (libbsd's pty functions) and @parcel/watcher (a
# backend on the node monitor).
for module in node-pty parcel-watcher; do
	directory=$MODULES/$(echo "$module" | sed 's|^parcel-|@parcel/|')
	if [ ! -f "$directory/.haiku-patched" ]; then
		patch -d "$directory" -p1 -s < "$STAGE/native/patches/$module.patch"
		touch "$directory/.haiku-patched"
	fi
done

build() {
	module=$1 file=$2
	echo "== $module"
	(cd "$MODULES/$module" && node "$GYP" rebuild --nodedir="$NODEDIR" -j "$(nproc 2>/dev/null || echo 4)" > build.log 2>&1) || {
		tail -30 "$MODULES/$module/build.log"
		exit 1
	}
	mkdir -p "$APP/$module/build/Release"
	cp "$MODULES/$module/build/Release/$file.node" "$APP/$module/build/Release/"
	strip --strip-debug "$APP/$module/build/Release/$file.node"
}

build @vscode/sqlite3 vscode-sqlite3
build @vscode/spdlog spdlog
build @vscode/native-watchdog watchdog
build node-pty pty
build @parcel/watcher watcher
echo "Native modules are in $APP"
