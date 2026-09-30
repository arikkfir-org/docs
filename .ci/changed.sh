#!/bin/sh
# Lists the published Markdown and HTML files that REVISION adds or modifies since its merge base with BASE, one per
# line. Hidden files and directories are never published, so they are left out.
#
# Usage: changed.sh BASE REVISION   (run from the repository root)
set -eu

git diff --name-only --no-renames --diff-filter=AM "$1...$2" -- '*.md' '*.html' | grep -Ev '(^|/)\.' || true
