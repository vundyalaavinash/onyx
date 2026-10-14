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
