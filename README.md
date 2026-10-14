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
