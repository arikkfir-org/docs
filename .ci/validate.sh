#!/bin/sh
# Validates the files listed in LIST: every Markdown file must render with the site's template and filter without
# warnings, and every relative link in the listed Markdown and HTML files must resolve (see links.lua).
#
# Usage: validate.sh LIST   (run from the repository root; needs pandoc)
set -eu

list="$1"
site=.site
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

failed=0
while IFS= read -r file; do
  case "$file" in
    *.md)
      if ! pandoc --from=gfm --to=html5 --standalone --fail-if-warnings \
        --template="${site}/template.html" --lua-filter="${site}/site.lua" \
        --syntax-highlighting=none --output="$out" "$file"; then
        echo "error: ${file} does not render" >&2
        failed=1
      fi
      ;;
  esac
done < "$list"

pandoc lua "$(dirname "$0")/links.lua" "$list" || failed=1
exit "$failed"
