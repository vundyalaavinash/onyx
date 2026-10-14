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
