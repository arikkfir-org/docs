#!/bin/sh
# Renders every Markdown file listed in LIST to an HTML page next to it.
#
# Usage: render.sh LIST   (run from the repository root)
set -eu

list="$1"
site="$(dirname "$0")"
count=0
while IFS= read -r md; do
  [ -n "$md" ] || continue
  pandoc --from=gfm --to=html5 --standalone \
    --template="${site}/template.html" --lua-filter="${site}/site.lua" \
    --syntax-highlighting=none \
    --output="${md%.md}.html" "$md"
  count=$((count + 1))
done < "$list"
echo "Rendered ${count} page(s)"
