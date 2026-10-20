#!/usr/bin/env bash
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.

# Builds Code - OSS for air/OS (Haiku) on Linux and stages it for packaging:
#   build/haiku/build.sh [stage directory]      (default: ../VSCode-haiku-stage)
# The stage holds the app (gulp's vscode-haiku-x64-min, without source maps),
# the sources of its native modules and the packaging files. On Haiku,
# native.sh builds the native modules and package.sh makes the package; see
# build/haiku/README.md. SKIP_COMPILE=1 packages the last bundle again.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STAGE=${1:-$(dirname "$ROOT")/VSCode-haiku-stage}
APP=$(dirname "$ROOT")/VSCode-haiku-x64

cd "$ROOT"
if [[ ${SKIP_COMPILE:-0} == 1 ]]; then
	npm run gulp vscode-haiku-x64-min-ci
else
	npm run gulp vscode-haiku-x64-min
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/native/node_modules"
cp -a "$APP" "$STAGE/app"
find "$STAGE/app" -name '*.map' -delete

# native-keymap reads X11's keyboard: the stand-in has Haiku's default layout.
node build/haiku/keymapping.ts "$STAGE/app/node_modules/native-keymap/build/Release/keymapping.js"
# The extensions gallery: Open VSX.
node build/haiku/product.ts "$STAGE/app/product.json"

# The native modules, built on Haiku by native.sh, and what building them needs.
NATIVE=(@vscode/sqlite3 @vscode/spdlog @vscode/native-watchdog node-pty @parcel/watcher
	node-addon-api bindings file-uri-to-path nan tar @isaacs/fs-minipass minipass chownr minizlib)
tar -C node_modules --exclude='*/prebuilds' --exclude='*/build' -cf - "${NATIVE[@]}" | tar -C "$STAGE/native/node_modules" -xf -
cp -a build/haiku/patches "$STAGE/native/"
cp build/haiku/native.sh build/haiku/package.sh build/haiku/files/* "$STAGE/"
cp LICENSE.txt "$STAGE/LICENSE"
node -p 'require("./package.json").version' > "$STAGE/VERSION"
echo "Staged $(cat "$STAGE/VERSION") in $STAGE"
