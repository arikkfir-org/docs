# docs

Knowledge base of the `arikkfir-org` hub, published to `https://docs.dev.kfirs.com/<path>` (behind the hub's sign-in).

## Rules

- Changes go through pull requests, like in every other repository. Direct pushes to `main` are reserved for
  automation: publishing the site, and syncing other repositories' branch and pull-request docs into a directory per
  repository and branch.
- `hub/reference.md` is the contract between `infra`, `delivery`, `octomaton` and CI configs. When a name, address,
  identity or permission changes anywhere, update it here in the same unit of work.
- Every meaningful unit of work gets a visual design doc under `<area>/designs/` (see `CONTRIBUTING.md`).
- Markdown: one `#` heading per file (it becomes the page title), GitHub-flavoured Markdown, Mermaid code blocks for
  diagrams, relative links to other `.md` files (the site rewrites them to `.html`), kebab-case file names.
- Never commit an HTML file next to a Markdown file of the same name; the publish pipeline refuses it.
- No navigation, menus or generated index pages. Pages are reached by direct links.
- Hidden paths (`.site/`, `.tekton/`, dotfiles) are never published.
- Lead with the decision; facts in tables; flows as diagrams; no filler.

## Site mechanics

- `.site/template.html` + `.site/site.lua` (pandoc) render Markdown; `.site/plan.sh`, `.site/render.sh` and
  `.site/sync.sh` are the publish steps run by `.tekton/publish.yaml`, triggered by Octomaton (`.octomaton.yaml`).
- Any change under `.site/` re-renders every page on the next publish.
- `.tekton/ci.yaml` is the required `ci` check on pull requests and merge groups: Markdown files a change adds or
  modifies must render, and relative links in its Markdown and HTML files must resolve (`.ci/`). Run it before pushing:
  `sh .ci/changed.sh origin/main HEAD > /tmp/changed.txt && sh .ci/validate.sh /tmp/changed.txt`
- Preview a page locally:
  `pandoc --from=gfm --standalone --template=.site/template.html --lua-filter=.site/site.lua --syntax-highlighting=none -o /tmp/page.html page.md`
