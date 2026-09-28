#!/bin/sh
# Decides which Markdown files must be rendered for this publication.
#
# Usage: plan.sh STATE_DIR   (run from the repository root, at the revision being published)
#   BASE      last published revision, empty when unknown
#   REVISION  revision being published
#
# Writes to STATE_DIR:
#   all.txt     every publishable Markdown file
#   render.txt  Markdown files changed since BASE (all of them when BASE is unusable or the site templates changed)
#   keep.txt    HTML pages of the remaining Markdown files: already published, left untouched by the sync
set -eu

state="$1"
mkdir -p "$state"

# Hidden files and directories are never published.
git ls-files -- '*.md' | grep -Ev '(^|/)\.' > "$state/all.txt" || true

while IFS= read -r md; do
  if git ls-files --error-unmatch -- "${md%.md}.html" > /dev/null 2>&1; then
    echo "error: ${md} and ${md%.md}.html both exist; the rendered page would overwrite the committed one" >&2
    exit 1
  fi
done < "$state/all.txt"

reason=""
if [ -z "${BASE:-}" ]; then
  reason="no previous publication recorded"
elif ! git cat-file -e "${BASE}^{commit}" 2> /dev/null; then
  reason="previous revision ${BASE} is not in the history"
elif ! git diff --quiet "$BASE" "$REVISION" -- .site; then
  reason="site templates changed"
fi

if [ -n "$reason" ]; then
  echo "Rendering every page: ${reason}"
  cp "$state/all.txt" "$state/render.txt"
else
  echo "Rendering pages changed since ${BASE}"
  git diff --name-only --no-renames --diff-filter=AM "$BASE" "$REVISION" -- '*.md' \
    | grep -Ev '(^|/)\.' > "$state/render.txt" || true
fi

grep -vxF -f "$state/render.txt" "$state/all.txt" | sed 's/\.md$/.html/' > "$state/keep.txt" || true
echo "$(wc -l < "$state/render.txt") page(s) to render, $(wc -l < "$state/keep.txt") unchanged"
