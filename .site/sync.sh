#!/usr/bin/env bash
# Mirrors the working tree to the bucket, uploading only differences and deleting objects whose files are gone.
# Hidden paths are never published. Pages listed in STATE_DIR/keep.txt (HTML of Markdown files that were not
# re-rendered) are excluded, which makes gcloud neither upload nor delete them. Records REVISION as published.
#
# Usage: sync.sh STATE_DIR   (run from the repository root)
#   BUCKET    destination bucket name
#   REVISION  revision being published
set -euo pipefail

state="$1"

# Exclusions are Python regular expressions matched from the start of each relative path. gcloud splits --exclude
# on commas, so commas in file names are written as \x2c.
escape() { sed -e 's/[][\.*^$+?(){}|]/\\&/g' -e 's/,/\\x2c/g'; }

hidden='(.*/)?\.'
keep=""
while IFS= read -r page; do
  [ -n "$page" ] || continue
  keep="${keep}|$(printf '%s' "$page" | escape)\$"
done < "${state}/keep.txt"

common=(--recursive --delete-unmatched-destination-objects --checksums-only --cache-control="public, max-age=300")

# Markdown sources, served as-is with an explicit charset.
gcloud storage rsync . "gs://${BUCKET}" "${common[@]}" \
  --content-type="text/markdown; charset=utf-8" \
  --exclude="${hidden}|(?!.*\.md\$)"

# Everything else: rendered pages, hand-written HTML, images.
gcloud storage rsync . "gs://${BUCKET}" "${common[@]}" \
  --exclude="${hidden}|.*\.md\$${keep}"

printf '%s\n' "$REVISION" > "${state}/published-revision"
gcloud storage cp "${state}/published-revision" "gs://${BUCKET}/.published-revision" --cache-control="no-store"
