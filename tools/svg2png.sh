#!/usr/bin/env bash
# SVG → PNG 批量渲染，用于掘金 / 知乎等不认 SVG 的平台。
#
# 约定：所有插图按 2x 渲染（viewBox 尺寸 × 2 像素），保证高分屏不糊。
# 依赖：本机已装 Edge 或 Chrome，用无头模式截图，不需要额外安装渲染库。
#
# 用法：  bash tools/svg2png.sh
# 产出：  images/png/<同名>.png

set -euo pipefail
cd "$(dirname "$0")/.."

SCALE=2

BROWSER=""
for c in \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "$(command -v msedge 2>/dev/null || true)" \
  "$(command -v google-chrome 2>/dev/null || true)" ; do
  if [ -n "$c" ] && [ -x "$c" ]; then BROWSER="$c"; break; fi
done

if [ -z "$BROWSER" ]; then
  echo "找不到 Edge / Chrome，无法渲染。" >&2
  exit 1
fi
echo "浏览器: $BROWSER"

mkdir -p images/png
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for svg in images/*.svg; do
  name="$(basename "$svg" .svg)"

  vb="$(sed -n 's/.*viewBox="\([^"]*\)".*/\1/p' "$svg" | head -1)"
  if [ -z "$vb" ]; then
    echo "跳过 $name（没有 viewBox）" >&2
    continue
  fi
  # shellcheck disable=SC2086
  set -- $vb
  w=$(( $3 * SCALE ))
  h=$(( $4 * SCALE ))

  cp "$svg" "$TMP/$name.svg"
  out="$(cygpath -w "$PWD/images/png/$name.png")"
  url="file:///$(cygpath -m "$TMP/$name.svg")"

  printf '→ %-34s %sx%s\n' "$name" "$w" "$h"
  "$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
    --window-size="$w,$h" --user-data-dir="$TMP/profile" \
    --screenshot="$out" "$url" >/dev/null 2>&1 || true

  [ -f "images/png/$name.png" ] || echo "  !! 渲染失败" >&2
done

echo
ls -la images/png/
