#!/bin/sh
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.

# The command line of @@NAME@@ on air/OS (Haiku). The app runs on Aurora: the
# CLI runs on Node.js, and starts the app through its launcher, which sits
# beside the app folder.
VSCODE_PATH="$(dirname "$(readlink -f "$0")")/.."
VSCODE_HAIKU_LAUNCHER="$(cd "$VSCODE_PATH/.." && pwd)/@@NAME@@"
NODE="${VSCODE_NODE:-/boot/system/bin/node}"
# As in the app (Aurora): Linux's platform name, and Aurora's mark.
SETUP="data:text/javascript,import os from 'node:os';Object.defineProperty(process,'platform',{value:'linux'});os.platform=()=>'linux';process.versions.aurora='cli';"
ELECTRON_RUN_AS_NODE=1 VSCODE_HAIKU_LAUNCHER="$VSCODE_HAIKU_LAUNCHER" exec "$NODE" --import "$SETUP" "$VSCODE_PATH/out/cli.js" "$@"
