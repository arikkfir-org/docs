# docs

Knowledge base of the `arikkfir-org` hub, served with every other repository's `docs/` at `https://docs.dev.kfirs.com` (behind the hub's sign-in): `<path>.md` raw, `<path>.md.html` rendered.

## Rules

- Changes go through pull requests and the merge queue, like every repository's (`CONTRIBUTING.md`).
- A name, address, identity or permission is documented by the repository that creates it, in its pages under `docs/<repository>/`, and changes there with its code; a page here links that page rather than repeat it ([design](hub/designs/docs-ownership.md)).
- Every meaningful unit of work gets a visual design doc under `<area>/designs/` (see `CONTRIBUTING.md`).
- A page about one repository belongs in that repository, under `docs/<repository>/`; a page about several is split into a part per repository, or kept whole in the leading one only when it loses its value in parts. This repository keeps only what is about no one repository, and its other pages move out ([design](hub/designs/docs-ownership.md)): never add one here.
- Test application code only, in every repository: never write tests for CI/CD code or scripts, Kustomize, Helm, shell scripts, infrastructure code or developer-experience scripts (`CONTRIBUTING.md`, "Code and configuration").
- Markdown: one `#` heading per file (it becomes the page title), GitHub-flavoured Markdown, Mermaid code blocks for diagrams, relative links to other `.md` files (the site links them to their `.md.html` pages), kebab-case file names.
- Never name a file `*.md.html`: that name belongs to a rendered page, and the `Docs` check refuses it.
- No navigation, menus or generated index pages. Pages are reached by direct links.
- Hidden paths (any file or directory name starting with `.`) are never published.
- Lead with the decision; facts in tables; flows as diagrams; no filler.
- Link a page by its place on the site, never as "file X in repository Y": a relative link inside a page, `https://docs.dev.kfirs.com/<path>.md` anywhere else.
- Read another repository's page from the site's bucket rather than cloning it: `curl -fsS https://storage.googleapis.com/arikkfir-docs/.layers/<repository>/<path>`, where `<repository>` is the path's first segment when it names a repository (`infra/terraform/gcp.md` is `infra`'s) and `docs` otherwise.
- Large tasks run as Linear projects (`CONTRIBUTING.md`, "Projects"): suggest one to your person and create it once they agree; one issue per slice, however many pull requests it takes; slices preferably self-contained and deployable on their own; keep the project's status current, with an update at each milestone or significant change.

## Site mechanics

- The site is composed from every repository ([design](hub/designs/docs-site-composition.md)): this repository's whole tree and each other repository's `docs/`, in one URL space. A path belongs to the first repository that publishes it.
- The organization pipelines in `tooling` (`docs-site/`) check and publish every repository. `docs` (check `Docs`) runs on pull requests and merge groups: relative links must resolve against the composed site, and no path may collide with another repository's. `docs-publish` mirrors `main` to this repository's layer.
- `delivery` (`platform/docs`) serves the layers with Caddy and renders Markdown on request.
- `.tekton/ci.yaml` (pipeline `ci`) checks nothing; it reports the required `Continuous Integration` check.
