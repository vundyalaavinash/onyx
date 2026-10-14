#!/usr/bin/env bash
# product.json carries Onyx identity and Open VSX; extensions/onyx-defaults carries the Warp defaults.
set -e
cd "$(dirname "$0")/.."
p=product.json
d=extensions/onyx-defaults/package.json
jq -e . "$p" >/dev/null
jq -e . "$d" >/dev/null
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
# Code OSS ignores product.json configurationDefaults; the built-in extension ships them
eq 'has("configurationDefaults")' false
p=$d
c=.contributes.configurationDefaults
eq "$c"'["workbench.colorTheme"]' "Dark Modern"
eq "$c"'["editor.background"] // "absent"' absent
eq "$c"'["workbench.colorCustomizations"]["editor.background"]' "#000000"
eq "$c"'["workbench.activityBar.location"]' top
eq "$c"'["terminal.integrated.defaultLocation"]' editor
jq -r "$c"'["editor.fontFamily"]' "$p" | grep -q 'Hack, Menlo, monospace' || { echo "FAIL font fallback"; exit 1; }
p=product.json
# Windows IDs must not collide with VSCodium's
for id in 763CBF88 88DA3577 67DEE444 0FD05EB4 2E1F05D1 57FD70A5 D910D5E6 4852FC55; do
  grep -q "$id" "$p" && { echo "FAIL VSCodium GUID $id present"; exit 1; }
done
# No MS-only extension in the proposal allowlist
jq -e '.extensionsEnabledWithApiProposalVersion | index("GitHub.copilot-chat") | not' "$p" >/dev/null || { echo "FAIL copilot in proposals"; exit 1; }
echo "product ok"
