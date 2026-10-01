# docs

Knowledge base of the `arikkfir-org` hub, served with every other repository's `docs/` at
`https://docs.dev.kfirs.com` (behind the hub's sign-in): `<path>.md` raw, `<path>.md.html` rendered.

## Rules

- Changes go through pull requests, like in every other repository. Nothing pushes to `main` directly.
- `hub/reference.md` is the contract between `infra`, `delivery`, `octomaton` and CI configs. When a name, address,
  identity or permission changes anywhere, update it here in the same unit of work.
- Every meaningful unit of work gets a visual design doc under `<area>/designs/` (see `CONTRIBUTING.md`).
- Markdown: one `#` heading per file (it becomes the page title), GitHub-flavoured Markdown, Mermaid code blocks for
  diagrams, relative links to other `.md` files (the site links them to their `.md.html` pages), kebab-case file
  names.
- Never name a file `*.md.html`: that name belongs to a rendered page, and the `Docs` check refuses it.
- No navigation, menus or generated index pages. Pages are reached by direct links.
- Hidden paths (any file or directory name starting with `.`) are never published.
- Lead with the decision; facts in tables; flows as diagrams; no filler.

## Site mechanics

- The site is composed from every repository ([design](hub/designs/docs-site-composition.md)): this repository's
  whole tree and each other repository's `docs/`, in one URL space. A path belongs to the first repository that
  publishes it.
- The organization pipelines in `tooling` (`docs-site/`) check and publish every repository. `docs` (check `Docs`)
  runs on pull requests and merge groups: relative links must resolve against the composed site, and no path may
  collide with another repository's. `docs-publish` mirrors `main` to this repository's layer.
- `delivery` (`platform/docs`) serves the layers with Caddy and renders Markdown on request.
- `.tekton/ci.yaml` (pipeline `ci`) checks nothing; it reports the required `Continuous Integration` check.
