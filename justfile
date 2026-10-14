# no -u: the upstream build scripts read unset vars (get_repo.sh RELEASE_VERSION)
set shell := ["bash", "-eo", "pipefail", "-c"]

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

# Apply patches and product.json without npm install: the fast drift check. Skips the telemetry rewrite (needs node_modules); `just build` runs it.
prepare: clone
    SKIP_INSTALL=yes ./prepare_vscode.sh

# Full local build into VSCode-darwin-<arch>/Onyx.app (~30 min)
build:
    set -a; rm -rf vscode; . ./get_repo.sh; . ./utils.sh; set +a; ./build.sh && ./prepare_assets.sh

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
