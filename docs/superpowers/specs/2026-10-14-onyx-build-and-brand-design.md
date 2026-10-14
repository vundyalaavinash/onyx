# Onyx: build and brand (sub-project 1)

Date: 2026-10-14
Status: shipped 1.140.06892

## What Onyx is

Onyx is an open-source fork of VS Code (Code OSS) that looks and works like Warp:
a pure black Warp Dark palette, the Hack font, no left icon rail, the terminal in
the main editor area, and an AI agent in a right-hand pane. Over four sub-projects
it gains a pluggable agent layer (Claude Code and Devin first), a native PR review
panel, and a block-based terminal.

This spec covers sub-project 1 only: a build pipeline that produces a branded,
installable Onyx for macOS, Linux, and Windows, with the Warp look baked in as
defaults and the built-in extension slots ready for later sub-projects.

Sub-projects and order:

1. **Build and brand** (this spec). Gate for everything else.
2. **Agent API** with Claude Code (local) and Devin (remote) providers.
3. **Review panel** as a built-in extension.
4. **Block terminal** as the single core patch.

## Decisions already made

- **Base:** VSCodium's build pipeline, forked. It is MIT, builds from a pinned
  upstream VS Code tag, applies a `patches/` folder, and has working CI for all
  three platforms with Open VSX as the extension gallery. We reuse it rather
  than maintain a divergent VS Code branch.
- **One core patch rule:** only the block terminal (sub-project 4) touches VS
  Code's `src/`. Everything else is a built-in extension under `extensions/`.
  Built-in extensions do not conflict with upstream merges.
- **Agent API shape** (recorded here so sub-projects 2 to 4 build on it, built in
  sub-project 2): a built-in extension `onyx-agents` exports `registerProvider`
  and `getActiveProvider`. A provider has `id`, `name`, `kind: 'local' |
  'remote'`, and a session lifecycle `create`, `send`, `events`, `close`.
  Local providers stream text and diffs. Remote providers report status and a
  link to the resulting branch or PR. Credentials go in VS Code secret storage.
  A status bar item shows and switches the active agent.
- **Not shippable:** Pylance, Remote SSH, Dev Containers, Copilot, and the
  Microsoft C++ tools are licensed only for official VS Code. Python support
  ships via an open-source Pyright-based server from Open VSX.
- **Audience:** public, open source, MIT. Signed macOS builds need an Apple
  Developer ID (99 USD/year). Until one exists, macOS builds are ad-hoc signed.

## Repository layout

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

`get_repo.sh` clones upstream at the pinned tag into `vscode/` (git-ignored).
`prepare_vscode.sh` applies `patches/`, merges `product.json`, and copies
`extensions/onyx-*` into `vscode/extensions/`. `build.sh` runs the upstream gulp
tasks.

## Patches

Keep from VSCodium, unchanged: everything under `patches/00-*` through
`patches/81-*` that removes telemetry, Microsoft branding, the Microsoft
gallery, Copilot, and the cloud/tunnel recommendations, and that wires updates
to GitHub releases.

Drop from VSCodium: `00-community-add-announcements.patch` and the
announcements JSON files. Onyx has no announcements feed.

Add for Onyx: none in sub-project 1. Branding is done through `product.json`
and `resources/`, not patches. If the VSCodium brand patch hardcodes the string
"VSCodium" anywhere that `product.json` does not cover, we edit that patch in
place rather than add a second one.

## product.json

Fields that matter:

- `nameShort: "Onyx"`, `nameLong: "Onyx"`, `applicationName: "onyx"`,
  `dataFolderName: ".onyx"`, `win32MutexName`, `darwinBundleIdentifier:
  "dev.onyx.editor"`, `urlProtocol: "onyx"`.
- `extensionsGallery`: Open VSX service, item, and control URLs, as VSCodium
  sets them.
- `updateUrl`: GitHub releases of `vundyalaavinash/onyx`.
- `configurationDefaults`: the Warp look, lifted from the user's working
  `settings.json` in `vundyalaavinash/vs-code-setup`:
  - theme `Dark Modern` plus the full `workbench.colorCustomizations` block
    (black editor and terminal, near-black chrome, cyan `#00c2ff` accent, Warp
    Dark's sixteen ANSI colors);
  - `editor.fontFamily: "Hack, Menlo, monospace"`, size 13, line height 1.6;
    terminal font Hack, size 13, line height 1.3, block cursor;
  - `workbench.activityBar.location: "top"`, minimap off, breadcrumbs off,
    layout control off, tab sizing shrink, empty hint hidden, startup editor
    none, tree indent guides none;
  - `terminal.integrated.defaultLocation: "editor"`, shell integration
    decorations both, sticky scroll on;
  - `workbench.secondarySideBar.defaultVisibility: "visible"`.
- `builtInExtensions`: empty in sub-project 1. Built-ins are copied into the
  tree instead (see layout).

The Hack font is not bundled in sub-project 1. The default font stack falls back
to Menlo on macOS and the platform monospace elsewhere when Hack is absent. An
"install Hack" first-run hint is deferred to a later sub-project.

## Upstream tracking

`upstream/stable.json` pins the VS Code tag. Sub-project 1 pins the tag
VSCodium currently builds so every VSCodium patch applies cleanly. A monthly
bump is: update the tag, run `build/prepare_vscode.sh`, fix any patch that
fails to apply, build, smoke test, tag a release.

## CI and release

Lift VSCodium's `ci-build-*.yml` and `publish-stable-*.yml`, rename for Onyx,
and trim to: build on pull request for macOS arm64 only (fast feedback), and
build and publish all platforms on a `v*` tag. Artifacts: `.dmg` and `.zip`
for macOS arm64 and x64, `.deb`, `.rpm`, `.tar.gz`, and AppImage for Linux
x64, `.exe` installer and `.zip` for Windows x64. Releases carry SHA256 sums.

macOS signing and notarization steps stay in the workflow behind a secret
check: if `APPLE_ID` secrets are absent, the step is skipped and the build is
ad-hoc signed. Adding the secrets later turns signing on with no code change.

## Local development loop

```
nvm use                     # .nvmrc copied from upstream
./build/get_repo.sh         # clone upstream at pinned tag
./build/prepare_vscode.sh   # patches, product.json, built-ins
./build/build.sh            # full build, 20 to 40 minutes on M-series
open VSCode-darwin-arm64/Onyx.app
```

A `just dev` recipe runs upstream's watch build and launches Onyx from source
with `extensions/` linked, for sub-projects 2 to 4.

## Error handling

- `prepare_vscode.sh` stops on the first patch that fails to apply and prints
  the patch name. No partial application.
- `build.sh` fails fast on any gulp error. CI surfaces the log.
- A missing `product.json` field that upstream requires fails the prepare
  step with the field name, not at runtime.

## Testing

- **Patch apply test** in CI: `prepare_vscode.sh` on a clean clone must exit
  zero. This is the cheapest guard against upstream drift.
- **Smoke test** per release, manual in sub-project 1: the app launches, the
  title shows Onyx, a new terminal opens as an editor tab in black with Hack or
  the fallback font, the Extensions view searches Open VSX, and Help > About
  shows the Onyx version and upstream commit.
- Upstream's own unit tests are not run in Onyx CI. We change no `src/` in
  this sub-project, so they add cost without signal.

## Out of scope for sub-project 1

Agent API, Devin, review panel, block terminal, bundled Hack font, first-run
onboarding, Windows arm64 and Linux arm64 builds, insiders channel, a website.

## Success criteria

Running the Publish workflow produces a GitHub release named `1.140.0NNNN` with downloadable builds for macOS arm64, macOS x64, Linux
x64, and Windows x64. A fresh install on a Mac with no settings opens looking
like the user's current VS Code with the Warp look, installs an extension from
Open VSX, and reports its version in About.
