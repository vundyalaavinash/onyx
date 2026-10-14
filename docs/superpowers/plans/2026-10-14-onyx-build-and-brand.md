# Onyx Build and Brand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A build pipeline in `vundyalaavinash/onyx` that turns upstream VS Code 1.140.0 into a branded, installable Onyx for macOS, Linux, and Windows with the Warp look as shipped defaults.

**Architecture:** Fork VSCodium's build pipeline (MIT, commit `be70704abf84fc6c7721f94478dfcccd2dc6163e`) into the repo root, strip everything Onyx does not ship (insiders, announcements, snap, MSI, Rust CLI, remote host, exotic Linux arches), and brand through environment variables, `product.json`, and icon files. No upstream `src/` patch is added. CI copies VSCodium's proven per-platform jobs with the matrix cut to four targets.

**Tech Stack:** bash, jq, GitHub Actions, Node 24.18.0 (upstream `.nvmrc`), Python 3.11 in CI, librsvg + ImageMagick + libicns + icoutils for icons, `just` for local recipes.

**Spec:** `docs/superpowers/specs/2026-10-14-onyx-build-and-brand-design.md`

## Global Constraints

- Upstream pin: tag `1.140.0`, commit `07f806f999227108933c2e30515b26eecc1fda74` in `upstream/stable.json`.
- Identity env, set in `utils.sh` defaults and every workflow: `APP_NAME=Onyx`, `BINARY_NAME=onyx`, `ORG_NAME=vundyalaavinash`, `GH_REPO_PATH=vundyalaavinash/onyx`, `ASSETS_REPOSITORY=vundyalaavinash/onyx`, `VERSIONS_REPOSITORY=vundyalaavinash/versions`, `VSCODE_QUALITY=stable`.
- Off for v0.1: `SHOULD_BUILD_CLI=no`, `SHOULD_BUILD_REH=no`, `SHOULD_BUILD_REH_WEB=no`. Snap, MSI, insiders, and non-x64 Linux are deleted, not disabled.
- Release version format is VSCodium's: `<upstream tag><4-digit build>`, e.g. `1.140.02465`. `get_repo.sh` computes it. Git tags `v*` are not used for releases; the Publish workflow is run by hand.
- `product.json` at repo root is the single source of identity, URLs, gallery, and configuration defaults. `prepare_vscode.sh` only merges it.
- The repo layout is VSCodium's: scripts at the root, per-OS helpers under `build/`. This supersedes the spec's `build/` for scripts line; Task 1 edits the spec to match.
- Linux builds set `DISABLE_UPDATE=yes` (package managers and AppImage's own updater handle updates), macOS and Windows auto-update through the versions repo.
- Patches keep VSCodium's `!!APP_NAME!!` style placeholders. Never hardcode "Onyx" inside `patches/`.

## Review Focus

1. **Fresh install with no Hack font.** The default font stack must fall back to Menlo or the platform monospace, never to a serif. Pinned by `test/product.sh` asserting the family string contains a fallback.
2. **Windows installer ID collision with VSCodium or VS Code.** All six `win32*AppId` GUIDs and both context menu CLSIDs must differ from VSCodium's. Pinned by `test/product.sh`.
3. **Unsigned macOS build refuses to launch on Apple Silicon.** Without an Apple certificate the app must still carry an ad-hoc signature. Pinned by Task 6's `codesign -dv` check.
4. **Patch drift on upstream bump.** A patch that stops applying must fail the prepare step by name. Pinned by Task 5's integration run and the `ci-patches` workflow.
5. **Leftover VSCodium strings in user-visible places** (desktop entries, release notes, About dialog). Pinned by `test/brand.sh` grepping the tree outside `patches/`, `LICENSE`, and `NOTICE`.

---

### Task 1: Import the VSCodium pipeline

**Files:**
- Create: everything listed in Step 2, copied from VSCodium at commit `be70704abf84fc6c7721f94478dfcccd2dc6163e`
- Create: `NOTICE`
- Modify: `docs/superpowers/specs/2026-10-14-onyx-build-and-brand-design.md` (layout section)
- Test: `test/syntax.sh`

**Interfaces:**
- Produces: `get_repo.sh`, `prepare_vscode.sh`, `build.sh`, `prepare_assets.sh`, `release.sh`, `utils.sh`, `version.sh`, `undo_telemetry.sh`, `prepare_checksums.sh`, `update_version.sh`, `build_cli.sh`, `build/{osx,linux,windows}/*`, `patches/*`, `src/stable/*`, `upstream/stable.json`, `.nvmrc`, `.gitignore`, `.editorconfig`, `LICENSE`.

- [ ] **Step 1: Clone VSCodium at the pinned commit into the scratchpad**

```bash
S=/private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad
rm -rf "$S/vscodium-src" && git clone -q https://github.com/VSCodium/vscodium.git "$S/vscodium-src"
git -C "$S/vscodium-src" checkout -q be70704abf84fc6c7721f94478dfcccd2dc6163e
```

- [ ] **Step 2: Copy only what Onyx keeps**

```bash
S=/private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/vscodium-src
cd /Users/avinashvundyala/Documents/github/onyx
cp "$S"/{get_repo.sh,prepare_vscode.sh,build.sh,build_cli.sh,prepare_assets.sh,prepare_checksums.sh,release.sh,release_notes.md,undo_telemetry.sh,update_version.sh,utils.sh,version.sh,.nvmrc,.gitignore,.editorconfig,.gitattributes,LICENSE} .
mkdir -p build/osx build/linux/anylinux-appimage build/windows patches src upstream icons
cp "$S"/build/osx/{include.gypi,prepare_assets.sh} build/osx/
cp "$S"/build/linux/{deps.sh,install_gh.sh,package_bin.sh,prepare_assets.sh} build/linux/
cp "$S"/build/linux/anylinux-appimage/{build.sh,cli-router.hook,prepare_assets.sh} build/linux/anylinux-appimage/
cp -R "$S"/build/windows/rtf build/windows/
cp "$S"/build/windows/{package.sh,prepare_assets.sh} build/windows/
cp "$S"/patches/*.patch "$S"/patches/*.json patches/
cp -R "$S"/patches/{linux,osx,windows,user,helper} patches/
rm -f patches/00-community-add-announcements.patch patches/00-build-update-sourcemap-url.patch
cp -R "$S"/src/stable src/
cp "$S"/upstream/stable.json upstream/
cp "$S"/icons/template_macos.png "$S"/icons/corner_512.png icons/
```

- [ ] **Step 3: Write NOTICE and extend LICENSE**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > NOTICE <<'EOF'
Onyx is built on the VSCodium build pipeline
(https://github.com/VSCodium/vscodium, MIT), imported at commit
be70704abf84fc6c7721f94478dfcccd2dc6163e, and on Code - OSS
(https://github.com/microsoft/vscode, MIT). See LICENSE.
EOF
sed -i '' '3i\
Copyright (c) 2026-present Avinash Vundyala and the Onyx contributors
' LICENSE
head -6 LICENSE
```

Expected: the four copyright lines, Onyx first.

- [ ] **Step 4: Write the syntax check**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
mkdir -p test
cat > test/syntax.sh <<'EOF'
#!/usr/bin/env bash
# Every shell script in the pipeline must parse.
set -e
cd "$(dirname "$0")/.."
fail=0
while IFS= read -r f; do
  bash -n "$f" || { echo "syntax error: $f"; fail=1; }
done < <(find . -name '*.sh' -not -path './vscode/*' -not -path './node_modules/*')
[[ $fail == 0 ]] && echo "syntax ok"
exit $fail
EOF
chmod +x test/syntax.sh
```

- [ ] **Step 5: Run it**

Run: `./test/syntax.sh`
Expected: `syntax ok`

- [ ] **Step 6: Update the spec's layout section**

In `docs/superpowers/specs/2026-10-14-onyx-build-and-brand-design.md`, replace the `## Repository layout` code block and the paragraph after it with:

```
onyx/
  *.sh              VSCodium pipeline scripts at the root (get_repo, prepare_vscode,
                    build, prepare_assets, release, utils, version)
  build/            per-OS helpers: osx/, linux/, windows/
  patches/          VSCodium's patches we keep, plus ours, applied in name order
  extensions/       Onyx built-in extensions (placeholder README in sub-project 1)
  product.json      Onyx identity, URLs, gallery, and configuration defaults
  upstream/stable.json   pinned VS Code tag and commit
  icons/ src/stable/     icon sources and generated icon files
  test/             shell checks run locally and in CI
  .github/workflows/ ci-patches.yml, ci-build-macos.yml, publish.yml
  docs/superpowers/ specs and plans
```

`get_repo.sh` clones upstream at the pinned tag into `vscode/` (git-ignored). `prepare_vscode.sh` applies `patches/`, merges `product.json`, and copies `extensions/onyx-*` into `vscode/extensions/`. `build.sh` runs the upstream gulp tasks.

Also replace the spec's success criterion sentence "A tag `v0.1.0` produces downloadable builds" with "Running the Publish workflow produces a GitHub release named `1.140.0NNNN` with downloadable builds".

- [ ] **Step 7: Commit**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
git add -A
git commit -m "Import VSCodium build pipeline at be70704

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Brand the scripts and delete what Onyx does not ship

**Files:**
- Modify: `utils.sh`, `prepare_vscode.sh`, `build_cli.sh`, `build/osx/prepare_assets.sh`, `build/linux/prepare_assets.sh`, `build/windows/prepare_assets.sh`, `release_notes.md`, `src/stable/resources/linux/{code.desktop,code-url-handler.desktop,code.appdata.xml}`
- Create: `README.md`, `test/brand.sh`

**Interfaces:**
- Consumes: Task 1 files.
- Produces: `utils.sh` defaults `APP_NAME=Onyx BINARY_NAME=onyx ORG_NAME=vundyalaavinash GH_REPO_PATH=vundyalaavinash/onyx ASSETS_REPOSITORY=vundyalaavinash/onyx`; `prepare_vscode.sh` with no identity `setpath` calls (Task 3 supplies identity via `product.json`).

- [ ] **Step 1: Write the brand check first**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > test/brand.sh <<'EOF'
#!/usr/bin/env bash
# No VSCodium branding may leak into shipped or user-visible files.
# patches/ keep !!APP_NAME!! placeholders and @vscodium/* npm packages; LICENSE and NOTICE credit upstream.
set -e
cd "$(dirname "$0")/.."
hits=$(grep -rniE 'vscodium|codium' \
  --exclude-dir=patches --exclude-dir=.git --exclude-dir=vscode --exclude-dir=docs --exclude-dir=test \
  --exclude=LICENSE --exclude=NOTICE --exclude=README.md . | grep -v 'vscodium-linux-build-agent' || true)
if [[ -n "$hits" ]]; then echo "$hits"; echo "brand leak"; exit 1; fi
if grep -rn 'Onyx' patches/ ; then echo "hardcoded Onyx in patches"; exit 1; fi
echo "brand ok"
EOF
chmod +x test/brand.sh
```

- [ ] **Step 2: Run it to see it fail**

Run: `./test/brand.sh`
Expected: many lines ending in `brand leak`, exit 1.

- [ ] **Step 3: Set identity defaults in utils.sh**

Replace the first seven assignments at the top of `utils.sh` with:

```bash
APP_NAME="${APP_NAME:-Onyx}"
APP_NAME_LC="$( echo "${APP_NAME}" | awk '{print tolower($0)}' )"
ASSETS_REPOSITORY="${ASSETS_REPOSITORY:-vundyalaavinash/onyx}"
BINARY_NAME="${BINARY_NAME:-onyx}"
GH_REPO_PATH="${GH_REPO_PATH:-vundyalaavinash/onyx}"
ORG_NAME="${ORG_NAME:-vundyalaavinash}"
TUNNEL_APP_NAME="${TUNNEL_APP_NAME:-"${BINARY_NAME}-tunnel"}"
GLOBAL_DIRNAME="${GLOBAL_DIRNAME:-"${APP_NAME_LC}"}"
```

Delete the `if [[ "${VSCODE_QUALITY}" == "insider" ]]` block that followed (it only set `GLOBAL_DIRNAME`).

- [ ] **Step 4: Cut prepare_vscode.sh down to merge-only product handling**

Edit `prepare_vscode.sh`:

1. Replace the opening quality branch with the single line `cp -rp src/stable/* vscode/`.
2. Inside the `# {{{ product.json` section, delete every `setpath` and `setpath_json` line from `checksumFailMoreInfoUrl` through `tunnelApplicationConfig`, including the `DISABLE_UPDATE` and quality `if` blocks. Keep the `setpath`/`setpath_json` function definitions, `cp product.json{,.bak}`, the `jq -s '.[0] * .[1]'` merge, and `cat product.json`.
3. After the merge, add the update-disable hook back so Linux can switch updates off:

```bash
if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  jsonTmp=$( jq 'del(.updateUrl) | del(.downloadUrl)' product.json )
  echo "${jsonTmp}" > product.json && unset jsonTmp
fi
```

4. In the patch loop section, delete the `insider` loop (`if [[ "${VSCODE_QUALITY}" == "insider" ]]; then for file in ../patches/insider/*.patch ...`).
5. Delete the announcements line: `replace "s|\\[\\/\\* BUILTIN_ANNOUNCEMENTS \\*\\/\\]|...gettingStarted.ts`.
6. Change `setpath "package" "version" "${RELEASE_VERSION%-insider}"` to `setpath "package" "version" "${RELEASE_VERSION}"`.
7. Replace the manifest quality branch with:

```bash
setpath "resources/server/manifest" "name" "Onyx"
setpath "resources/server/manifest" "short_name" "Onyx"
```

8. Replace every `VSCodium` in `replace` and `sed` lines with `Onyx`, every `https://vscodium.com` with `https://github.com/vundyalaavinash/onyx`, every `https://github.com/VSCodium/vscodium#download-install` with `https://github.com/vundyalaavinash/onyx#install`, `vscode-linux@microsoft.com` author lines with `Onyx contributors https://github.com/vundyalaavinash/onyx/graphs/contributors`, and the Debian postinst quality branch with the single line `sed -i "s/code-oss/onyx/" resources/linux/debian/postinst.template`.

Then run `grep -n 'insider\|VSCodium\|vscodium' prepare_vscode.sh`. Expected: no output.

- [ ] **Step 5: Point build_cli.sh at Onyx endpoints**

Even though the CLI is off, the script is sourced. Replace the endpoint block with:

```bash
export VSCODE_CLI_UPDATE_ENDPOINT="https://raw.githubusercontent.com/vundyalaavinash/versions/refs/heads/master"
export VSCODE_CLI_DOWNLOAD_ENDPOINT="https://github.com/vundyalaavinash/onyx/releases"
```

- [ ] **Step 6: Ad-hoc sign when no certificate is present**

In `build/osx/prepare_assets.sh`, after the first big `if [[ -n "${CERTIFICATE_OSX_P12_DATA}" ]]; then ... fi` block, add:

```bash
if [[ -z "${CERTIFICATE_OSX_P12_DATA}" ]]; then
  echo "+ no certificate: ad-hoc signing so the app launches on Apple Silicon"
  codesign --force --deep --sign - "VSCode-darwin-${VSCODE_ARCH}/${APP_NAME}.app"
fi
```

- [ ] **Step 7: Remove snap and MSI**

In `build/linux/prepare_assets.sh` delete the block:

```bash
if [[ "${CI_BUILD}" == "no" ]]; then
  . ./stores/snapcraft/build.sh
  ...
fi
```

In `build/windows/prepare_assets.sh` delete both `if [[ "${VSCODE_ARCH}" == "ia32" || "${VSCODE_ARCH}" == "x64" ]]; then` blocks (the MSI build and the MSI move).

- [ ] **Step 8: Rewrite release_notes.md for four targets**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > release_notes.md <<'EOF'
Onyx @@VERSION@@ on VS Code @@MS_TAG@@ ([upstream notes](@@MS_URL@@)).

| Platform | Download |
| --- | --- |
| macOS Apple Silicon | [@@APP_NAME@@-darwin-arm64-@@VERSION@@.zip](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@-darwin-arm64-@@VERSION@@.zip) |
| macOS Intel | [@@APP_NAME@@-darwin-x64-@@VERSION@@.zip](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@-darwin-x64-@@VERSION@@.zip) |
| Linux x64 .deb | [@@BINARY_NAME@@_@@VERSION@@_amd64.deb](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@BINARY_NAME@@_@@VERSION@@_amd64.deb) |
| Linux x64 .rpm | [@@BINARY_NAME@@-@@VERSION@@-el8.x86_64.rpm](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@BINARY_NAME@@-@@VERSION@@-el8.x86_64.rpm) |
| Linux x64 .tar.gz | [@@APP_NAME@@-linux-x64-@@VERSION@@.tar.gz](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@-linux-x64-@@VERSION@@.tar.gz) |
| Linux x64 AppImage | [@@APP_NAME@@-@@VERSION@@-anylinux-x86_64.AppImage](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@-@@VERSION@@-anylinux-x86_64.AppImage) |
| Windows x64 installer | [@@APP_NAME@@Setup-x64-@@VERSION@@.exe](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@Setup-x64-@@VERSION@@.exe) |
| Windows x64 user installer | [@@APP_NAME@@UserSetup-x64-@@VERSION@@.exe](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@UserSetup-x64-@@VERSION@@.exe) |
| Windows x64 .zip | [@@APP_NAME@@-win32-x64-@@VERSION@@.zip](https://github.com/@@ASSETS_REPOSITORY@@/releases/download/@@VERSION@@/@@APP_NAME@@-win32-x64-@@VERSION@@.zip) |

Every file has `.sha256` and `.sha1` siblings. macOS builds are ad-hoc signed until an Apple Developer ID is configured: right-click, Open on first launch.

@@RELEASE_NOTES@@
EOF
```

- [ ] **Step 9: Brand the Linux desktop files**

In `src/stable/resources/linux/code.desktop` and `code-url-handler.desktop` change `Keywords=vscodium;codium;vscode;` to `Keywords=onyx;vscode;terminal;` and `Comment=Code Editing. Redefined.` to `Comment=A Warp-styled VS Code`. Replace `src/stable/resources/linux/code.appdata.xml` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop">
	<id>@@NAME@@.desktop</id>
	<metadata_license>@@LICENSE@@</metadata_license>
	<project_license>@@LICENSE@@</project_license>
	<name>@@NAME_LONG@@</name>
	<url type="homepage">https://github.com/vundyalaavinash/onyx</url>
	<summary>Onyx. A Warp-styled VS Code.</summary>
	<description>
		<p>Onyx is an open-source build of Code - OSS with a pure black theme, the terminal in the main area, and an agent pane on the right.</p>
	</description>
</component>
```

- [ ] **Step 10: Write README.md**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > README.md <<'EOF'
# Onyx

A Warp-styled, open-source build of VS Code (Code - OSS). Pure black, Hack font, no left icon rail, terminal in the main area, agent pane on the right. MIT.

## Install

Grab the latest build from [Releases](https://github.com/vundyalaavinash/onyx/releases). macOS builds are ad-hoc signed for now: right-click the app and choose Open the first time. Install the [Hack](https://sourcefoundry.org/hack/) font for the intended look (`brew install --cask font-hack`); without it Onyx falls back to the platform monospace.

## Build locally (macOS)

```
brew install just jq librsvg imagemagick libicns icoutils
nvm install && nvm use
just build      # clones upstream, applies patches, builds ~30 min
just run        # opens the built app
```

`just prepare` stops after patches and product.json, which is the fast check that an upstream bump still applies.

## What cannot ship

Pylance, Remote SSH, Dev Containers, Copilot, and the Microsoft C++ tools are licensed for official VS Code only. Extensions come from [Open VSX](https://open-vsx.org).

## Upstream bump

Edit `upstream/stable.json` to the new tag and commit, run `just prepare`, fix any patch that fails, run `just build`, smoke test, then run the Publish workflow.

Built on the [VSCodium](https://github.com/VSCodium/vscodium) pipeline. See NOTICE.
EOF
```

- [ ] **Step 11: Fix the leftover hits**

Run `./test/brand.sh`. Expected remaining hits and their fixes:

- `.gitignore`: replace the `VS*/*`, `VSCode*`, `VSCodium*` lines with `VSCode-*/` and `Onyx-*/`.
- `build/linux/anylinux-appimage/build.sh`: change the echo to `Extracting Onyx binary...`; replace the quality `if` around `OUTNAME`/`repo` with the two lines `export OUTNAME=${APP_NAME}-${VERSION}-anylinux-"${ARCH}".AppImage` and `repo=${GITHUB_REPOSITORY#*/}`.
- `build/linux/package_bin.sh`: delete the `elif` branches for `ppc64le`, `riscv64`, and `loong64` (keep `arm64`), which removes the `VSCodium/vscode-linux-build-agent` sysroot reference.
- Anything under `build/windows/rtf/`: replace `VSCodium` with `Onyx` in place.

Rerun until it prints `brand ok`, then run `./test/syntax.sh`.
Expected: `brand ok` then `syntax ok`.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "Brand pipeline as Onyx; drop insiders, announcements, snap, MSI

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: product.json

**Files:**
- Create: `product.json` (replaces the VSCodium one from Task 1)
- Test: `test/product.sh`

**Interfaces:**
- Consumes: VSCodium's `product.json` keys `extensionAllowedBadgeProviders`, `extensionAllowedBadgeProvidersRegex`, `extensionsEnabledWithApiProposalVersion`, `extensionEnabledApiProposals`, `extensionKind`, `extensionPointExtensionKind`, `extensionSyncedKeys`, `extensionVirtualWorkspacesSupport` (kept as-is).
- Produces: identity keys read by every build script via `node -p "require('./vscode/product.json').X"`.

- [ ] **Step 1: Write the product check**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > test/product.sh <<'EOF'
#!/usr/bin/env bash
# product.json carries Onyx identity, Open VSX, and the Warp defaults.
set -e
cd "$(dirname "$0")/.."
p=product.json
jq -e . "$p" >/dev/null
eq() { [[ "$(jq -r "$1" "$p")" == "$2" ]] || { echo "FAIL $1 = $(jq -r "$1" "$p"), want $2"; exit 1; }; }
eq .nameShort Onyx
eq .nameLong Onyx
eq .applicationName onyx
eq .dataFolderName .onyx
eq .darwinBundleIdentifier dev.onyx.editor
eq .urlProtocol onyx
eq .linuxIconName onyx
eq .quality stable
eq .extensionsGallery.serviceUrl https://open-vsx.org/vscode/gallery
eq '.configurationDefaults["workbench.colorTheme"]' "Dark Modern"
eq '.configurationDefaults["editor.background"] // "absent"' absent
eq '.configurationDefaults["workbench.colorCustomizations"]["editor.background"]' "#000000"
eq '.configurationDefaults["workbench.activityBar.location"]' top
eq '.configurationDefaults["terminal.integrated.defaultLocation"]' editor
jq -r '.configurationDefaults["editor.fontFamily"]' "$p" | grep -q 'Hack, Menlo, monospace' || { echo "FAIL font fallback"; exit 1; }
# Windows IDs must not collide with VSCodium's
for id in 763CBF88 88DA3577 67DEE444 0FD05EB4 2E1F05D1 57FD70A5 D910D5E6 4852FC55; do
  grep -q "$id" "$p" && { echo "FAIL VSCodium GUID $id present"; exit 1; }
done
# No MS-only extension in the proposal allowlist
jq -e '.extensionsEnabledWithApiProposalVersion | index("GitHub.copilot-chat") | not' "$p" >/dev/null || { echo "FAIL copilot in proposals"; exit 1; }
echo "product ok"
EOF
chmod +x test/product.sh
```

- [ ] **Step 2: Run it to see it fail**

Run: `./test/product.sh`
Expected: `FAIL .nameShort = null, want Onyx`.

- [ ] **Step 3: Build the new product.json from the old one**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cp product.json product.vscodium.json
jq '
  del(.extensionsEnabledWithApiProposalVersion[] | select(. == "GitHub.copilot-chat" or . == "ms-vscode.vscode-copilot-vision" or . == "ms-vscode.vscode-commander"))
  + {
  "nameShort": "Onyx",
  "nameLong": "Onyx",
  "applicationName": "onyx",
  "dataFolderName": ".onyx",
  "serverApplicationName": "onyx-server",
  "serverDataFolderName": ".onyx-server",
  "linuxIconName": "onyx",
  "quality": "stable",
  "urlProtocol": "onyx",
  "darwinBundleIdentifier": "dev.onyx.editor",
  "win32AppUserModelId": "Onyx.Onyx",
  "win32DirName": "Onyx",
  "win32MutexName": "onyx",
  "win32NameVersion": "Onyx",
  "win32RegValueName": "Onyx",
  "win32ShellNameShort": "Onyx",
  "win32AppId": "{{6D57324C-BC32-4DD1-B937-BBD5D6D7E24D}",
  "win32x64AppId": "{{C8654A34-0999-4D04-94F8-26C6A9012183}",
  "win32arm64AppId": "{{6E0CDB90-2084-4B35-9474-ECA723242623}",
  "win32UserAppId": "{{480F8996-1B48-420E-B4BE-9EFDE150F6A9}",
  "win32x64UserAppId": "{{C0E095DC-E60D-4E52-9BC1-4913091EC62E}",
  "win32arm64UserAppId": "{{A9FA5B06-9972-4D07-9756-F3BC426EC00B}",
  "win32ContextMenu": { "x64": { "clsid": "5EA6EC4A-3798-4352-9402-A6A2BC3ECA4D" }, "arm64": { "clsid": "4C7748D3-34F2-428E-BCE4-C5FF111E2113" } },
  "tunnelApplicationName": "onyx-tunnel",
  "tunnelApplicationConfig": {},
  "win32TunnelServiceMutex": "onyx-tunnelservice",
  "win32TunnelMutex": "onyx-tunnel",
  "licenseUrl": "https://github.com/vundyalaavinash/onyx/blob/main/LICENSE",
  "reportIssueUrl": "https://github.com/vundyalaavinash/onyx/issues/new",
  "requestFeatureUrl": "https://github.com/vundyalaavinash/onyx/issues/new",
  "releaseNotesUrl": "https://github.com/vundyalaavinash/onyx/releases",
  "documentationUrl": "https://code.visualstudio.com/docs",
  "keyboardShortcutsUrlMac": "https://go.microsoft.com/fwlink/?linkid=832143",
  "keyboardShortcutsUrlLinux": "https://go.microsoft.com/fwlink/?linkid=832144",
  "keyboardShortcutsUrlWin": "https://go.microsoft.com/fwlink/?linkid=832145",
  "introductoryVideosUrl": "https://go.microsoft.com/fwlink/?linkid=832146",
  "tipsAndTricksUrl": "https://go.microsoft.com/fwlink/?linkid=852118",
  "checksumFailMoreInfoUrl": "https://go.microsoft.com/fwlink/?LinkId=828886",
  "updateUrl": "https://raw.githubusercontent.com/vundyalaavinash/versions/refs/heads/master",
  "downloadUrl": "https://github.com/vundyalaavinash/onyx/releases",
  "extensionsGallery": {
    "serviceUrl": "https://open-vsx.org/vscode/gallery",
    "itemUrl": "https://open-vsx.org/vscode/item",
    "latestUrlTemplate": "https://open-vsx.org/vscode/gallery/{publisher}/{name}/latest",
    "controlUrl": "https://raw.githubusercontent.com/EclipseFdn/publish-extensions/refs/heads/master/extension-control/extensions.json"
  },
  "linkProtectionTrustedDomains": ["https://open-vsx.org", "https://github.com/vundyalaavinash"],
  "configurationDefaults": {
    "workbench.colorTheme": "Dark Modern",
    "workbench.colorCustomizations": {
      "editor.background": "#000000", "terminal.background": "#000000", "panel.background": "#000000",
      "sideBar.background": "#0a0a0a", "activityBar.background": "#0a0a0a", "titleBar.activeBackground": "#0a0a0a",
      "statusBar.background": "#0a0a0a", "editorGroupHeader.tabsBackground": "#0a0a0a", "tab.inactiveBackground": "#0a0a0a",
      "tab.activeBackground": "#000000", "input.background": "#141414", "dropdown.background": "#141414",
      "editorWidget.background": "#0f0f0f", "quickInput.background": "#0f0f0f",
      "editor.foreground": "#ffffff", "terminal.foreground": "#ffffff",
      "focusBorder": "#00c2ff", "tab.activeBorderTop": "#00c2ff", "activityBar.activeBorder": "#00c2ff",
      "progressBar.background": "#00c2ff", "textLink.foreground": "#00c2ff", "button.background": "#00c2ff", "button.foreground": "#000000",
      "editorCursor.foreground": "#00c2ff", "terminalCursor.foreground": "#00c2ff", "statusBarItem.remoteBackground": "#00c2ff",
      "panel.border": "#1a1a1a", "sideBar.border": "#1a1a1a", "editorGroup.border": "#1a1a1a", "tab.border": "#0a0a0a",
      "terminal.ansiBlack": "#616161", "terminal.ansiRed": "#ff8272", "terminal.ansiGreen": "#b4fa72", "terminal.ansiYellow": "#fefdc2",
      "terminal.ansiBlue": "#a5d5fe", "terminal.ansiMagenta": "#ff8ffd", "terminal.ansiCyan": "#d0d1fe", "terminal.ansiWhite": "#f1f1f1",
      "terminal.ansiBrightBlack": "#8e8e8e", "terminal.ansiBrightRed": "#ffc4bd", "terminal.ansiBrightGreen": "#d6fcb9", "terminal.ansiBrightYellow": "#fefdd5",
      "terminal.ansiBrightBlue": "#c1e3fe", "terminal.ansiBrightMagenta": "#ffb1fe", "terminal.ansiBrightCyan": "#e5e6fe", "terminal.ansiBrightWhite": "#feffff"
    },
    "editor.fontFamily": "Hack, Menlo, monospace",
    "editor.fontSize": 13,
    "editor.lineHeight": 1.6,
    "editor.minimap.enabled": false,
    "editor.renderLineHighlight": "gutter",
    "editor.scrollbar.verticalScrollbarSize": 6,
    "editor.scrollbar.horizontalScrollbarSize": 6,
    "breadcrumbs.enabled": false,
    "terminal.integrated.fontFamily": "Hack, Menlo, monospace",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.lineHeight": 1.3,
    "terminal.integrated.cursorStyle": "block",
    "terminal.integrated.defaultLocation": "editor",
    "terminal.integrated.tabs.enabled": true,
    "terminal.integrated.shellIntegration.decorationsEnabled": "both",
    "terminal.integrated.stickyScroll.enabled": true,
    "workbench.activityBar.location": "top",
    "workbench.layoutControl.enabled": false,
    "workbench.editor.tabSizing": "shrink",
    "workbench.editor.empty.hint": "hidden",
    "workbench.startupEditor": "none",
    "workbench.tips.enabled": false,
    "workbench.tree.renderIndentGuides": "none",
    "workbench.tree.indent": 12,
    "workbench.secondarySideBar.defaultVisibility": "visible",
    "window.commandCenter": true,
    "telemetry.telemetryLevel": "off"
  }
}' product.vscodium.json > product.json
rm product.vscodium.json
```

- [ ] **Step 4: Run the check**

Run: `./test/product.sh && ./test/brand.sh`
Expected: `product ok`, `brand ok`.

- [ ] **Step 5: Commit**

```bash
git add product.json test/product.sh
git commit -m "Onyx product.json: identity, Open VSX, Warp defaults

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Icons

**Files:**
- Create: `icons/onyx.svg`, `icons/build_icons.sh`
- Replace generated: `src/stable/resources/darwin/code.icns`, `src/stable/resources/linux/{code.png,code.svg,rpm/code.xpm}`, `src/stable/resources/win32/code.ico`, `src/stable/resources/server/{favicon.ico,code-192.png,code-512.png}`, `src/stable/src/vs/workbench/browser/media/code-icon.svg`, the four `letterpress-*.svg`
- Delete: every other file under `src/stable/resources/darwin/`, `src/stable/resources/win32/` (VSCodium's file-type icons and installer bitmaps; upstream's own ship instead), `icons/template_macos.png`, `icons/corner_512.png`
- Test: `test/icons.sh`

**Interfaces:**
- Produces: the file paths above, consumed by upstream's gulp packaging via `cp -rp src/stable/* vscode/`.

- [ ] **Step 1: Install the icon toolchain**

Run: `brew install librsvg imagemagick libicns icoutils`
Expected: `rsvg-convert`, `magick`, `png2icns`, `icotool` all on PATH (`which` each).

- [ ] **Step 2: Write the icon check**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > test/icons.sh <<'EOF'
#!/usr/bin/env bash
# Every platform icon the build copies into upstream must exist and be the right kind.
set -e
cd "$(dirname "$0")/.."
r=src/stable/resources
for f in $r/darwin/code.icns $r/linux/code.png $r/linux/code.svg $r/linux/rpm/code.xpm $r/win32/code.ico \
         $r/server/favicon.ico $r/server/code-192.png $r/server/code-512.png \
         src/stable/src/vs/workbench/browser/media/code-icon.svg; do
  [[ -s "$f" ]] || { echo "missing $f"; exit 1; }
done
file $r/darwin/code.icns | grep -q 'icon' || { echo "code.icns is not an icns"; exit 1; }
[[ "$(magick identify -format '%w' $r/linux/code.png)" == "1024" ]] || { echo "code.png not 1024px"; exit 1; }
[[ "$(magick identify -format '%w' $r/server/code-512.png)" == "512" ]] || { echo "code-512 not 512px"; exit 1; }
icotool -l $r/win32/code.ico | grep -q 'width=256' || { echo "code.ico lacks 256px"; exit 1; }
[[ -z "$(ls $r/darwin | grep -v '^code.icns$')" ]] || { echo "stray darwin icons"; exit 1; }
echo "icons ok"
EOF
chmod +x test/icons.sh
```

- [ ] **Step 3: Run it to see it fail**

Run: `./test/icons.sh`
Expected: `stray darwin icons` (VSCodium's file-type icons are still there) or a missing-file line.

- [ ] **Step 4: Draw the icon**

Black rounded square, hairline border, cyan prompt chevron and cursor block in Warp's accent. 1024 viewBox.

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > icons/onyx.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect x="64" y="64" width="896" height="896" rx="200" fill="#000000" stroke="#1a1a1a" stroke-width="16"/>
  <path d="M300 352 L484 512 L300 672" fill="none" stroke="#00c2ff" stroke-width="88" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="540" y="596" width="196" height="76" rx="18" fill="#00c2ff"/>
</svg>
EOF
```

- [ ] **Step 5: Write the generator**

Replaces VSCodium's 200-line script. Produces only the files Onyx overrides.

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > icons/build_icons.sh <<'EOF'
#!/usr/bin/env bash
# Generate every platform icon from icons/onyx.svg. Run from the repo root.
# Needs: rsvg-convert (librsvg), magick (imagemagick), png2icns (libicns), icotool (icoutils).
set -e
cd "$(dirname "$0")/.."
for t in rsvg-convert magick png2icns icotool; do command -v "$t" >/dev/null || { echo "need $t"; exit 1; }; done
SVG=icons/onyx.svg
R=src/stable/resources
M=src/stable/src/vs/workbench/browser/media
E=src/stable/src/vs/workbench/browser/parts/editor/media
mkdir -p "$R/darwin" "$R/linux/rpm" "$R/win32" "$R/server" "$M" "$E"
T=$(mktemp -d)
for s in 1024 512 256 192 128 64 48 32 16; do rsvg-convert -w $s -h $s "$SVG" -o "$T/$s.png"; done
# macOS
png2icns "$R/darwin/code.icns" "$T/1024.png" "$T/512.png" "$T/256.png" "$T/128.png" "$T/32.png" "$T/16.png"
# Linux
cp "$T/1024.png" "$R/linux/code.png"
cp "$SVG" "$R/linux/code.svg"
magick "$T/256.png" "$R/linux/rpm/code.xpm"
# Windows
icotool -c -o "$R/win32/code.ico" "$T/256.png" "$T/128.png" "$T/64.png" "$T/48.png" "$T/32.png" "$T/16.png"
# Server / web
icotool -c -o "$R/server/favicon.ico" "$T/64.png" "$T/32.png" "$T/16.png"
cp "$T/192.png" "$R/server/code-192.png"
cp "$T/512.png" "$R/server/code-512.png"
# Workbench letterpress (the faint logo on an empty editor) and title icon
cp "$SVG" "$M/code-icon.svg"
for v in dark light hcDark hcLight; do cp "$SVG" "$E/letterpress-$v.svg"; done
rm -rf "$T"
echo "icons generated"
EOF
chmod +x icons/build_icons.sh
```

- [ ] **Step 6: Clear VSCodium's generated icons and generate ours**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
rm -rf src/stable/resources/darwin src/stable/resources/win32 src/stable/resources/server
rm -f src/stable/resources/linux/code.png src/stable/resources/linux/code.svg src/stable/resources/linux/rpm/code.xpm
rm -f icons/template_macos.png icons/corner_512.png
./icons/build_icons.sh
```

Expected: `icons generated`.

- [ ] **Step 7: Run the checks**

Run: `./test/icons.sh && ./test/brand.sh`
Expected: `icons ok`, `brand ok`.

- [ ] **Step 8: Eyeball it**

Run: `qlmanage -p src/stable/resources/darwin/code.icns` and press space to close.
Expected: black rounded square, cyan chevron and cursor, no white corners.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Onyx icon and generator; drop VSCodium file-type icons

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Extension slot, fast prepare, and the integration run

**Files:**
- Create: `extensions/README.md`, `justfile`
- Modify: `prepare_vscode.sh` (built-in copy step, `SKIP_INSTALL` guard), `.gitignore`

**Interfaces:**
- Produces: `SKIP_INSTALL=yes` env for `prepare_vscode.sh` (skips `npm ci`), `extensions/onyx-*` copied into `vscode/extensions/`. `just` recipes `clone`, `prepare`, `build`, `run`, `test`, `clean`.

- [ ] **Step 1: Placeholder for sub-project 2 onward**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
mkdir -p extensions
cat > extensions/README.md <<'EOF'
Onyx built-in extensions. Every directory named `onyx-*` here is copied into
`vscode/extensions/` by `prepare_vscode.sh` and compiled as a built-in, the
same way upstream ships `git` and `github-authentication`. Empty in
sub-project 1; `onyx-agents` arrives in sub-project 2.
EOF
```

- [ ] **Step 2: Add the copy step and the install guard to prepare_vscode.sh**

After the last patch loop (`for file in ../patches/user/*.patch ... done` and its closing `# }}}`), add:

```bash
# {{{ Onyx built-in extensions
for dir in ../extensions/onyx-*/; do
  if [[ -d "${dir}" ]]; then
    echo "bundling built-in extension: $( basename "${dir}" )"
    cp -R "${dir}" "extensions/$( basename "${dir}" )"
  fi
done
# }}}
```

Wrap the `# {{{ install dependencies` section (from `export ELECTRON_SKIP_BINARY_DOWNLOAD=1` through the end of the `npm ci` retry loop) in:

```bash
if [[ "${SKIP_INSTALL}" != "yes" ]]; then
  ...existing block...
fi
```

- [ ] **Step 3: justfile**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
cat > justfile <<'EOF'
set shell := ["bash", "-euo", "pipefail", "-c"]

export OS_NAME := "osx"
export VSCODE_ARCH := `uname -m | sed 's/x86_64/x64/'`
export VSCODE_QUALITY := "stable"
export CI_BUILD := "no"
export SHOULD_BUILD := "yes"
export SHOULD_BUILD_CLI := "no"
export SHOULD_BUILD_REH := "no"
export SHOULD_BUILD_REH_WEB := "no"

# Clone upstream VS Code at the pinned tag into vscode/
clone:
    rm -rf vscode && . ./get_repo.sh

# Apply patches and product.json without installing node modules (fast drift check)
prepare: clone
    SKIP_INSTALL=yes ./prepare_vscode.sh

# Full local build into VSCode-darwin-<arch>/Onyx.app (~30 min)
build: clone
    ./build.sh && ./prepare_assets.sh

run:
    open "VSCode-darwin-${VSCODE_ARCH}/Onyx.app"

# Upstream watch build, for extension work in sub-projects 2 to 4 (run in one terminal)
watch:
    cd vscode && npm run watch

# Launch Onyx from source against the watch build (run in a second terminal)
dev:
    cd vscode && ./scripts/code.sh

test:
    ./test/syntax.sh && ./test/brand.sh && ./test/product.sh && ./test/icons.sh

clean:
    rm -rf vscode VSCode-darwin-* assets
EOF
grep -q '^assets/$' .gitignore || echo 'assets/' >> .gitignore
```

- [ ] **Step 4: Run the unit checks**

Run: `brew install just && just test`
Expected: four `ok` lines.

- [ ] **Step 5: Integration run: do the patches apply to upstream 1.140.0?**

Run: `just prepare`
Expected: `get_repo.sh` prints `MS_TAG="1.140.0"`, then one `applying patch:` line per file in `patches/` with no `failed to apply patch`, then the merged `product.json` is printed with `"nameShort": "Onyx"`, exit 0. Takes two to five minutes for the shallow clone.

If a patch fails: it names itself. Open it, compare with upstream at the pinned commit, fix the hunk, rerun. Do not skip it silently.

- [ ] **Step 6: Verify the merged product and that no insider path is referenced**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
node -p "const p=require('./vscode/product.json'); [p.nameShort, p.applicationName, p.extensionsGallery.serviceUrl, p.configurationDefaults['workbench.colorTheme']].join(' | ')"
grep -c 'Onyx' vscode/product.json
```

Expected: `Onyx | onyx | https://open-vsx.org/vscode/gallery | Dark Modern`, and a count above 5.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Built-in extension slot, SKIP_INSTALL prepare, justfile

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: First local build and smoke test

**Files:**
- No source changes expected. Any fix found here is committed with a message naming the symptom.

**Interfaces:**
- Consumes: everything above.
- Produces: `VSCode-darwin-arm64/Onyx.app` and `assets/Onyx-darwin-arm64-<version>.zip`.

- [ ] **Step 1: Node version**

Run: `nvm install && nvm use && node -v`
Expected: `v24.18.0`.

- [ ] **Step 2: Build**

Run: `just build 2>&1 | tee /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/onyx-build.log`
Expected: 20 to 40 minutes. Ends with `+ no certificate: ad-hoc signing` and `Building and moving ZIP`. Exit 0.

- [ ] **Step 3: Signature check (Review Focus 3)**

Run: `codesign -dv VSCode-darwin-arm64/Onyx.app 2>&1 | grep -E 'Identifier|Signature'`
Expected: `Identifier=dev.onyx.editor` and `Signature=adhoc`.

- [ ] **Step 4: Smoke test by hand**

Run: `just run`. Check each item and record the result in the commit message of Step 5:

1. The Dock and the menu bar say Onyx, with the black and cyan icon.
2. Onyx, About shows `Version: 1.140.0NNNN` and the upstream commit.
3. The window is black, with no left icon rail; activity icons sit at the top of the sidebar.
4. Terminal, New Terminal opens as an editor tab, black background, and `echo $TERM_PROGRAM` prints `vscode`.
5. The right-hand secondary sidebar is visible on first launch.
6. Extensions view: search `python` returns results from Open VSX; install `ms-python.python` from Open VSX succeeds (this is the open-source Python extension; Pylance is absent as expected).
7. Preferences, Settings, search `fontFamily` shows `Hack, Menlo, monospace` as the default, not a modified value.
8. Help menu contains no links to vscodium.com.

- [ ] **Step 5: Commit any fixes, or an empty marker**

```bash
git commit --allow-empty -m "Local macOS arm64 build smoke-tested: <list what passed; name anything that failed>

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

If anything in Step 4 failed, fix it in the owning task's files, rerun `just test`, rebuild only if the fix touches the build, and commit with the symptom in the message.

---

### Task 7: CI workflows and the versions repo

**Files:**
- Create: `.github/workflows/ci-patches.yml`, `.github/workflows/ci-build-macos.yml`, `.github/workflows/publish.yml`
- Create (GitHub): repo `vundyalaavinash/versions`, secret `VERSIONS_TOKEN`

**Interfaces:**
- Consumes: scripts from Tasks 1 to 5; `update_version.sh` writes `stable/<platform>/<arch>/latest.json` into the versions repo, which `product.json`'s `updateUrl` points at.
- Produces: GitHub Releases named by `RELEASE_VERSION`.

- [ ] **Step 1: Create the versions repo**

```bash
gh repo create vundyalaavinash/versions --public --description "Onyx update manifests" --clone=false
git clone -q git@github.com:vundyalaavinash/versions.git /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/versions
cd /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/versions
git checkout -b master 2>/dev/null || true
echo "Update manifests for Onyx. Written by CI, read by the app's updateUrl." > README.md
git add README.md && git commit -qm "init" && git push -q -u origin master
```

`update_version.sh` pushes to `master`, so the branch is named `master` on purpose.

- [ ] **Step 2: Create the PAT secret**

The user must do this once: create a fine-grained GitHub token with Contents read and write on `vundyalaavinash/versions` only, then:

```bash
gh secret set VERSIONS_TOKEN --repo vundyalaavinash/onyx
```

Until it exists, the Update versions step is skipped and auto-update stays silent. The build still publishes.

- [ ] **Step 3: ci-patches.yml (Review Focus 4)**

```bash
mkdir -p /Users/avinashvundyala/Documents/github/onyx/.github/workflows
cat > /Users/avinashvundyala/Documents/github/onyx/.github/workflows/ci-patches.yml <<'EOF'
name: CI - Patches apply

on:
  pull_request:
  push:
    branches: [main]

permissions: {}

env:
  APP_NAME: Onyx
  BINARY_NAME: onyx
  ORG_NAME: vundyalaavinash
  GH_REPO_PATH: vundyalaavinash/onyx
  ASSETS_REPOSITORY: vundyalaavinash/onyx
  OS_NAME: linux
  VSCODE_ARCH: x64
  VSCODE_QUALITY: stable
  CI_BUILD: "no"

jobs:
  patches:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - name: Unit checks
        run: ./test/syntax.sh && ./test/brand.sh && ./test/product.sh
      - name: Clone upstream
        run: . ./get_repo.sh
      - name: Apply patches without installing
        env:
          SKIP_INSTALL: "yes"
        run: ./prepare_vscode.sh
EOF
```

- [ ] **Step 4: ci-build-macos.yml**

```bash
cat > /Users/avinashvundyala/Documents/github/onyx/.github/workflows/ci-build-macos.yml <<'EOF'
name: CI - Build - macOS arm64

on:
  pull_request:
    paths-ignore: ["**/*.md", "docs/**"]
  push:
    branches: [main]
    paths-ignore: ["**/*.md", "docs/**"]
  workflow_dispatch: {}

permissions: {}

env:
  APP_NAME: Onyx
  BINARY_NAME: onyx
  ORG_NAME: vundyalaavinash
  GH_REPO_PATH: vundyalaavinash/onyx
  ASSETS_REPOSITORY: vundyalaavinash/onyx
  OS_NAME: osx
  VSCODE_ARCH: arm64
  VSCODE_QUALITY: stable
  MAX_OLD_SPACE_SIZE: 12288
  SHOULD_BUILD: "yes"
  SHOULD_BUILD_CLI: "no"
  SHOULD_BUILD_REH: "no"
  SHOULD_BUILD_REH_WEB: "no"

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
      - name: Clone upstream
        run: . ./get_repo.sh
      - name: Build
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build.sh
      - name: Package
        run: ./prepare_assets.sh
      - uses: actions/upload-artifact@v7
        with:
          name: Onyx-darwin-arm64
          path: assets/
          retention-days: 3
EOF
```

- [ ] **Step 5: publish.yml**

One workflow, run by hand, four platform jobs plus AppImage. Lifted from VSCodium's publish and CI workflows with the matrix cut down.

```bash
cat > /Users/avinashvundyala/Documents/github/onyx/.github/workflows/publish.yml <<'EOF'
name: Publish

on:
  workflow_dispatch:
    inputs:
      release_version:
        description: "Override release version (e.g. 1.140.00042). Leave empty to compute."
        type: string
        default: ""

permissions: {}

env:
  APP_NAME: Onyx
  BINARY_NAME: onyx
  ORG_NAME: vundyalaavinash
  GH_REPO_PATH: vundyalaavinash/onyx
  ASSETS_REPOSITORY: vundyalaavinash/onyx
  VERSIONS_REPOSITORY: vundyalaavinash/versions
  VSCODE_QUALITY: stable
  MAX_OLD_SPACE_SIZE: 12288
  SHOULD_BUILD: "yes"
  SHOULD_BUILD_CLI: "no"
  SHOULD_BUILD_REH: "no"
  SHOULD_BUILD_REH_WEB: "no"
  RELEASE_VERSION: ${{ inputs.release_version }}

jobs:
  version:
    # One job computes RELEASE_VERSION so every platform publishes to the same release.
    runs-on: ubuntu-24.04
    outputs:
      RELEASE_VERSION: ${{ env.RELEASE_VERSION }}
      MS_TAG: ${{ env.MS_TAG }}
      MS_COMMIT: ${{ env.MS_COMMIT }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - run: . ./get_repo.sh

  macos:
    needs: version
    runs-on: ${{ matrix.runner }}
    permissions:
      contents: write
    strategy:
      fail-fast: false
      matrix:
        include:
          - runner: macos-14
            vscode_arch: arm64
          - runner: macos-15-intel
            vscode_arch: x64
    env:
      OS_NAME: osx
      VSCODE_ARCH: ${{ matrix.vscode_arch }}
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
      MS_TAG: ${{ needs.version.outputs.MS_TAG }}
      MS_COMMIT: ${{ needs.version.outputs.MS_COMMIT }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
      - uses: actions/setup-python@v7
        with:
          python-version: "3.11"
        if: matrix.vscode_arch == 'x64'
      - run: . ./get_repo.sh
      - name: Build
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build.sh
      - name: Package (signs and notarizes only when CERTIFICATE_OSX_P12_DATA is set)
        env:
          CERTIFICATE_OSX_APP_PASSWORD: ${{ secrets.CERTIFICATE_OSX_APP_PASSWORD }}
          CERTIFICATE_OSX_APPLE_ID: ${{ secrets.CERTIFICATE_OSX_APPLE_ID }}
          CERTIFICATE_OSX_P12_DATA: ${{ secrets.CERTIFICATE_OSX_P12_DATA }}
          CERTIFICATE_OSX_P12_PASSWORD: ${{ secrets.CERTIFICATE_OSX_P12_PASSWORD }}
          CERTIFICATE_OSX_TEAM_ID: ${{ secrets.CERTIFICATE_OSX_TEAM_ID }}
        run: ./prepare_assets.sh
      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./release.sh
      - name: Update versions repo
        env:
          GITHUB_TOKEN: ${{ secrets.VERSIONS_TOKEN }}
          GITHUB_USERNAME: vundyalaavinash
        run: '[[ -z "$GITHUB_TOKEN" ]] && echo "VERSIONS_TOKEN not set, skipping" || ./update_version.sh'
      - name: Clean up keychain
        if: always()
        run: |
          KEYCHAIN=$RUNNER_TEMP/buildagent.keychain
          [[ -f "$KEYCHAIN" ]] && security delete-keychain "$KEYCHAIN" || true

  linux-compile:
    needs: version
    runs-on: ubuntu-22.04
    env:
      OS_NAME: linux
      VSCODE_ARCH: x64
      DISABLE_UPDATE: "yes"
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
      MS_TAG: ${{ needs.version.outputs.MS_TAG }}
      MS_COMMIT: ${{ needs.version.outputs.MS_COMMIT }}
    outputs:
      BUILD_SOURCEVERSION: ${{ env.BUILD_SOURCEVERSION }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: egor-tensin/setup-gcc@v2
        with:
          version: 10
          platform: x64
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
      - uses: actions/setup-python@v7
        with:
          python-version: "3.11"
      - run: sudo apt-get update -y && sudo apt-get install -y libkrb5-dev
      - run: . ./get_repo.sh
      - name: Compile
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build.sh
      - name: Compress vscode artifact
        run: |
          find vscode -type f -not -path "*/node_modules/*" -not -path "vscode/.build/node/*" -not -path "vscode/.git/*" > vscode.txt
          echo "vscode/.build/extensions/node_modules" >> vscode.txt
          echo "vscode/.git" >> vscode.txt
          tar -czf vscode.tar.gz -T vscode.txt
      - uses: actions/upload-artifact@v7
        with:
          name: vscode-linux
          path: ./vscode.tar.gz
          retention-days: 1

  linux:
    needs: [version, linux-compile]
    runs-on: ubuntu-latest
    container:
      image: vscodium/vscodium-linux-build-agent:focal-x64
    permissions:
      contents: write
    env:
      OS_NAME: linux
      VSCODE_ARCH: x64
      DISABLE_UPDATE: "yes"
      CI_BUILD: "yes"
      npm_config_arch: x64
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
      MS_TAG: ${{ needs.version.outputs.MS_TAG }}
      MS_COMMIT: ${{ needs.version.outputs.MS_COMMIT }}
      BUILD_SOURCEVERSION: ${{ needs.linux-compile.outputs.BUILD_SOURCEVERSION }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - run: ./build/linux/install_gh.sh
      - run: ./build/linux/deps.sh
      - uses: actions/download-artifact@v8
        with:
          name: vscode-linux
      - name: Package binary
        id: build
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build/linux/package_bin.sh
      - name: Save binary for AppImage
        run: tar -czf vscode-bin.tar.gz -C "VSCode-linux-x64" .
      - uses: actions/upload-artifact@v7
        with:
          name: vscode-bin-x64
          path: ./vscode-bin.tar.gz
          retention-days: 1
      - name: Prepare assets (tar, deb, rpm)
        env:
          VSCODE_SYSROOT_REPOSITORY: ${{ steps.build.outputs.VSCODE_SYSROOT_REPOSITORY }}
          VSCODE_SYSROOT_VERSION: ${{ steps.build.outputs.VSCODE_SYSROOT_VERSION }}
          VSCODE_SYSROOT_PREFIX: ${{ steps.build.outputs.VSCODE_SYSROOT_PREFIX }}
        run: ./prepare_assets.sh
      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./release.sh

  appimage:
    needs: [version, linux]
    runs-on: ubuntu-latest
    container: ghcr.io/pkgforge-dev/archlinux:v2026.08.31
    permissions:
      contents: write
    env:
      OS_NAME: linux
      VSCODE_ARCH: x64
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: pkgforge-dev/anylinux-setup-action@v5
      - uses: actions/download-artifact@v8
        with:
          name: vscode-bin-x64
      - run: ./build/linux/anylinux-appimage/build.sh
      - run: ./build/linux/anylinux-appimage/prepare_assets.sh
      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./release.sh

  windows-compile:
    needs: version
    runs-on: windows-2022
    defaults:
      run:
        shell: bash
    env:
      OS_NAME: windows
      VSCODE_ARCH: x64
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
      MS_TAG: ${{ needs.version.outputs.MS_TAG }}
      MS_COMMIT: ${{ needs.version.outputs.MS_COMMIT }}
    outputs:
      BUILD_SOURCEVERSION: ${{ env.BUILD_SOURCEVERSION }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
      - uses: actions/setup-python@v7
        with:
          python-version: "3.11"
      - run: . ./get_repo.sh
      - name: Compile
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build.sh
      - name: Compress vscode artifact
        run: |
          find vscode -type f -not -path "*/node_modules/*" -not -path "vscode/.build/node/*" -not -path "vscode/.git/*" > vscode.txt
          echo "vscode/.build/extensions/node_modules" >> vscode.txt
          echo "vscode/.git" >> vscode.txt
          tar -czf vscode.tar.gz -T vscode.txt
      - uses: actions/upload-artifact@v7
        with:
          name: vscode-windows
          path: ./vscode.tar.gz
          retention-days: 1

  windows:
    needs: [version, windows-compile]
    runs-on: windows-2022
    defaults:
      run:
        shell: bash
    permissions:
      contents: write
    env:
      OS_NAME: windows
      VSCODE_ARCH: x64
      CI_BUILD: "yes"
      npm_config_arch: x64
      npm_config_target_arch: x64
      RELEASE_VERSION: ${{ needs.version.outputs.RELEASE_VERSION }}
      MS_TAG: ${{ needs.version.outputs.MS_TAG }}
      MS_COMMIT: ${{ needs.version.outputs.MS_COMMIT }}
      BUILD_SOURCEVERSION: ${{ needs.windows-compile.outputs.BUILD_SOURCEVERSION }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
      - uses: actions/setup-python@v7
        with:
          python-version: "3.11"
      - uses: actions/download-artifact@v8
        with:
          name: vscode-windows
      - name: Package
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./build/windows/package.sh
      - name: Prepare assets (zip, installers)
        run: ./prepare_assets.sh
      - run: ./prepare_checksums.sh
      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./release.sh
      - name: Update versions repo
        env:
          GITHUB_TOKEN: ${{ secrets.VERSIONS_TOKEN }}
          GITHUB_USERNAME: vundyalaavinash
        run: '[[ -z "$GITHUB_TOKEN" ]] && echo "VERSIONS_TOKEN not set, skipping" || ./update_version.sh'
EOF
```

- [ ] **Step 6: Make version.sh run in the compile jobs**

`build.sh` already sources `version.sh`, which exports `BUILD_SOURCEVERSION` into `GITHUB_ENV`. Confirm with:

Run: `grep -n 'version.sh' build.sh`
Expected: `. version.sh` near the top.

- [ ] **Step 7: Lint the workflows**

Run: `brew install actionlint && actionlint`
Expected: no output. Fix anything it reports before committing.

- [ ] **Step 8: Commit and push, then watch the two CI workflows**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
git add -A
git commit -m "CI: patch check, macOS arm64 build, manual publish for four targets

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
gh run watch --exit-status $(gh run list --workflow=ci-patches.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

Expected: `ci-patches` green in under ten minutes. `ci-build-macos` green in under an hour; download its artifact and confirm it contains `Onyx-darwin-arm64-1.140.0NNNN.zip`.

---

### Task 8: First publish

**Files:**
- Modify: `README.md` (download links verified)

**Interfaces:**
- Consumes: `publish.yml`.
- Produces: GitHub release `1.140.0NNNN` with assets for macOS arm64, macOS x64, Linux x64 (tar, deb, rpm, AppImage), Windows x64 (zip, system installer, user installer), each with `.sha256` and `.sha1`.

- [ ] **Step 1: Run Publish**

```bash
cd /Users/avinashvundyala/Documents/github/onyx
gh workflow run publish.yml
sleep 60
gh run watch --exit-status $(gh run list --workflow=publish.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

Expected: all jobs green within about ninety minutes. The Linux and Windows jobs are the ones most likely to need a retry, since they run VSCodium's two-stage flow on fresh runners.

- [ ] **Step 2: Verify the release**

```bash
V=$(gh release list --repo vundyalaavinash/onyx --limit 1 --json tagName -q '.[0].tagName')
gh release view "$V" --repo vundyalaavinash/onyx --json assets -q '.assets[].name' | sort
```

Expected, at minimum:

```
Onyx-1.140.0NNNN-anylinux-x86_64.AppImage
Onyx-darwin-arm64-1.140.0NNNN.zip
Onyx-darwin-x64-1.140.0NNNN.zip
Onyx-linux-x64-1.140.0NNNN.tar.gz
Onyx-win32-x64-1.140.0NNNN.zip
OnyxSetup-x64-1.140.0NNNN.exe
OnyxUserSetup-x64-1.140.0NNNN.exe
onyx-1.140.0NNNN-el8.x86_64.rpm
onyx_1.140.0NNNN_amd64.deb
```

plus `.sha1` and `.sha256` for each. If a platform is missing, open that job's log, fix, and rerun only that workflow.

- [ ] **Step 3: Fresh-install check on this Mac (Review Focus 1)**

```bash
cd /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad
rm -rf onyx-fresh && mkdir onyx-fresh && cd onyx-fresh
gh release download "$V" --repo vundyalaavinash/onyx --pattern 'Onyx-darwin-arm64-*.zip'
unzip -q Onyx-darwin-arm64-*.zip
mv ~/.onyx ~/.onyx.bak 2>/dev/null; mv "$HOME/Library/Application Support/Onyx" "$HOME/Library/Application Support/Onyx.bak" 2>/dev/null
open Onyx.app
```

Expected: launches after right-click Open, black window, Hack font (installed on this machine), About shows the release version. Then restore any `.bak` folders.

- [ ] **Step 4: Confirm the update manifest exists if the token was set**

Run: `curl -sf https://raw.githubusercontent.com/vundyalaavinash/versions/refs/heads/master/stable/darwin/arm64/latest.json | jq .name`
Expected: the release version, or a 404 if `VERSIONS_TOKEN` was not configured, which is acceptable for v0.1 and noted in the README.

- [ ] **Step 5: Commit the verified README and mark the spec done**

Change the spec's `Status: draft for review` line to `Status: shipped <release version>`.

```bash
cd /Users/avinashvundyala/Documents/github/onyx
git add -A
git commit -m "First Onyx release <version>: four targets published and verified

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```

---

## Notes for sub-project 2

Upstream 1.140 ships `src/vs/platform/agentHost/` with a Claude agent and a Copilot agent in core, and VSCodium's `patches/52-ext-copilot-remove-it.json` deletes the Copilot half plus some Claude test files. Read that directory before designing `onyx-agents`; the pluggable agent API may be an extension over upstream's agent host rather than a fresh abstraction.
