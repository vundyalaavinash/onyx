#!/usr/bin/env bash
# The block terminal patch must exist, touch only its own directory plus the
# single import line, and match the prepared checkout when one is present.
set -euo pipefail
cd "$(dirname "$0")/.."

P=patches/onyx-block-terminal.patch
if [[ ! -s "$P" ]]; then
  echo "blocks.sh: $P missing or empty" >&2
  exit 1
fi

if grep '^+++ b/' "$P" \
  | grep -v '^+++ b/src/vs/workbench/contrib/terminalContrib/onyxBlocks/' \
  | grep -v '^+++ b/src/vs/workbench/contrib/terminal/terminal.all.ts$'; then
  echo "blocks.sh: patch touches files outside the allowed set" >&2
  exit 1
fi

if [[ "$(grep -cF "+import '../terminalContrib/onyxBlocks/browser/terminal.onyxBlocks.contribution.js';" "$P" | head -1)" -ne 1 ]]; then
  echo "blocks.sh: patch must add exactly the onyxBlocks contribution import" >&2
  exit 1
fi

if [[ -d vscode/.git ]]; then
  (
    cd vscode
    if [[ -n "$(git diff --cached --stat)" ]]; then
      echo "blocks.sh: vscode/ index is not pristine; run 'just blocks-patch' to drop intent-to-add entries" >&2
      exit 1
    fi
    git apply --check --cached --ignore-whitespace "../$P"
    git apply --check --reverse --ignore-whitespace "../$P"
  )
fi

echo "blocks.sh ok"
