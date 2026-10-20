# Code - OSS on air/OS (Haiku)

This branch builds Code - OSS as an air/OS app. Chromium does not run on Haiku, so the app runs on [Aurora](https://github.com/jmgasper/aurora), which implements the `electron` module on plain Node.js and draws windows with Summit's WebKit engine. The workbench, the extension host, the shared process and the pty host are the same code as on Linux; the main process and the utility processes are Node.js 22, and the pages are WebKit.

## What differs from Linux

- **Platform:** Aurora reports `linux` as the platform (`AURORA_PLATFORM=linux` in `aurora.json`), so the Linux code paths run. `isHaiku` in `src/vs/base/common/platform.ts` (Aurora's `process.versions.aurora`, or `Haiku` in the user agent in workers) marks the few places that differ:
  - settings live in `~/config/settings/Code - OSS` (`userDataPath.ts`);
  - windows use Haiku's tab and menu bar (`window.titleBarStyle` defaults to `native`);
  - the UI and editor fonts are Noto Sans and Noto Sans Mono;
  - external terminals open in Haiku's Terminal;
  - the user agent leaves out Chrome, so the workbench takes its WebKit paths;
  - the `code-oss` command starts the app through its launcher (`VSCODE_HAIKU_LAUNCHER`);
  - shortcut labels name the keys pressed: the engine gives pages Haiku's Command key (Alt) as Control and its Control key as Alt, so Alt+Shift+P opens the command palette;
  - Haiku's single user (uid 0) is not a superuser, and buttons have no mnemonics.
- **No ASAR:** dependencies are plain `node_modules`; `node_modules.asar` and `node_modules.asar.unpacked` are links to it, for the places that name them.
- **Native modules** are built on Haiku (`native.sh`): `@vscode/sqlite3`, `@vscode/spdlog`, `@vscode/native-watchdog`, `node-pty` (with `patches/node-pty.patch`: libbsd's pty functions) and `@parcel/watcher` (with `patches/parcel-watcher.patch`: a backend on Haiku's node monitor). `native-keymap` is a JavaScript stand-in with the US layout (`keymapping.ts`). Search uses Haiku's `ripgrep`.
- **Extensions** come from [Open VSX](https://open-vsx.org) (`product.ts`). Extensions with native code for Linux do not load.

## Building

On Linux, with the Node.js version in `.nvmrc` and the dependencies installed (`npm ci`):

```sh
build/haiku/build.sh [stage]        # gulp vscode-haiku-x64-min, then the stage (default ../VSCode-haiku-stage)
```

On Haiku, in the stage (gcc, make, python3, `nodejs22_devel` and `devel:libuv` installed):

```sh
./native.sh                          # the native modules, into app/node_modules
./package.sh <output directory>      # code_oss-<version>-<revision>-x86_64.hpkg
```

`package.sh` makes the launcher from the installed `aurora` package's `aurora-host` (or `AURORA_HOST_BINARY`). Raise `REVISION` in it for a new package of the same version. The package needs `aurora` 0.3 or later (utility processes and message ports) and HaikuPorts' `nodejs22`.

## Webviews

The engine has no service workers for the `vscode-webview` scheme, which webviews use to load an extension's resources. On Haiku the webview's host page (`src/vs/workbench/contrib/webview/browser/pre/index.html`) loads them itself, with the same `load-resource` messages, and gives the content `blob:` URLs: in its elements and style sheets, in elements it adds later, and through `fetch()`. Markdown previews and most extension webviews work that way; JavaScript modules that import other files of the extension, and workers started from them, do not.

## Not working yet

- Extensions with Linux binaries, and Copilot's agent features that run its native runtime.
- Signature verification of extensions (`vsce-sign` has no Haiku build), automatic type acquisition in TypeScript (it does not know Haiku's platform).
- Printing, and anything that reads `/proc`.
