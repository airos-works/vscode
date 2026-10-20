/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

// Writes the stand-in for native-keymap's native part on air/OS (Haiku):
//   node build/haiku/keymapping.ts <output .js file>
// native-keymap reads X11's keyboard on Linux, which Haiku does not have. The
// stand-in reports the US layout (the keymap VS Code's own tests use for
// Linux), which is what Haiku's default keymap produces.

import * as fs from 'fs';
import * as path from 'path';
import * as vm from 'vm';

const root = path.dirname(path.dirname(import.meta.dirname));
const fixture = path.join(root, 'src/vs/workbench/services/keybinding/test/node/linux_en_us.js');

let keyMap: unknown;
vm.runInNewContext(fs.readFileSync(fixture, 'utf8'), { define: (value: unknown) => { keyMap = value; } });

const output = process.argv[2];
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `'use strict';

// native-keymap on air/OS (Haiku), written by build/haiku/keymapping.ts:
// the US layout, which Haiku's default keymap produces.

const keyMap = ${JSON.stringify(keyMap)};

exports.getKeyMap = () => keyMap;
exports.getCurrentKeyboardLayout = () => ({ model: 'pc105', group: 0, layout: 'us', variant: '', options: '', rules: 'evdev' });
exports.onDidChangeKeyboardLayout = () => { };
exports.isISOKeyboard = () => false;
`);
