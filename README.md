# Onyx

A Warp-styled, open-source build of VS Code (Code - OSS). Pure black, Hack font, no left icon rail, terminal in the main area, agent pane on the right. MIT.

## Install

Grab the latest build from [Releases](https://github.com/vundyalaavinash/onyx/releases). macOS builds are ad-hoc signed until an Apple Developer ID is configured. On first launch macOS will refuse the app; open System Settings, Privacy & Security, and choose Open Anyway, or run `xattr -dr com.apple.quarantine /Applications/Onyx.app`. Install the [Hack](https://sourcefoundry.org/hack/) font for the intended look (`brew install --cask font-hack`); without it Onyx falls back to the platform monospace.

## Block terminal

Every Onyx terminal has a command input pinned at the bottom and one block per
command above it. Type anywhere in the terminal and the text lands in the input.
Enter runs, Shift+Enter adds a line, Up and Down walk history, Tab completes.
Hover a block for Copy command, Copy output, Re-run and Send to agent. Cmd+Up
and Cmd+Down (Ctrl on Linux and Windows) select blocks; Escape clears the
selection. Full-screen programs such as vim get the classic terminal back
while they run.

Blocks need shell integration, which Onyx injects for zsh, bash, fish and
PowerShell. A shell without it behaves like a stock VS Code terminal. Turn the
feature off with `onyx.terminal.blocks.enabled: false`. Without shell
integration, or with the setting off, the terminal is the stock VS Code terminal.

This is Onyx's one core patch: `patches/onyx-block-terminal.patch`. Its source
is `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/` after
`just prepare`; edit there, then run `just blocks-patch` and commit the patch.
`just test` checks the patch stays inside its allowed files.

## Build locally (macOS)

```
brew install just jq git-lfs librsvg imagemagick libicns icoutils
nvm install && nvm use
just build      # clones upstream, applies patches, builds in about 5 to 10 minutes
just run        # opens the built app
```

`just prepare` stops after patches and product.json, which is the fast check that an upstream bump still applies.

## What cannot ship

Pylance, Remote SSH, Dev Containers, Copilot, and the Microsoft C++ tools are licensed for official VS Code only. Extensions come from [Open VSX](https://open-vsx.org).

## Upstream bump

Edit `upstream/stable.json` to the new tag and commit, run `just prepare`, fix any patch that fails, run `just build`, smoke test, then run the Publish workflow.

Built on the [VSCodium](https://github.com/VSCodium/vscodium) pipeline. See NOTICE.
