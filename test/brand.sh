#!/usr/bin/env bash
# No VSCodium branding may leak into shipped or user-visible files.
# patches/ keep !!APP_NAME!! placeholders and @vscodium/* npm packages; LICENSE and NOTICE credit upstream.
set -e
cd "$(dirname "$0")/.."
hits=$(grep -rniE 'vscodium|codium' \
  --exclude-dir=patches --exclude-dir=.git --exclude-dir=vscode --exclude-dir=docs --exclude-dir=test --exclude-dir=.superpowers --exclude-dir=assets --exclude-dir='VSCode-*' --exclude-dir='Onyx-*' \
  --exclude=LICENSE --exclude=NOTICE --exclude=README.md . | grep -v 'vscodium-linux-build-agent' || true)
if [[ -n "$hits" ]]; then echo "$hits"; echo "brand leak"; exit 1; fi
if grep -rn 'Onyx' patches/ --exclude=onyx-block-terminal.patch ; then echo "hardcoded Onyx in patches"; exit 1; fi
echo "brand ok"
