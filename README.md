# docs

The knowledge base of the `arikkfir-org` development hub: designs, architecture, runbooks and conventions. Every
meaningful unit of work lands here as a visual design document.

## Start here

- [Hub overview](hub/overview.html): the whole platform on one page
- [Hub reference](hub/reference.md): every name, address, identity and permission (the contract between repositories)
- [Bootstrap runbook](hub/runbooks/bootstrap.md): bringing the hub up from nothing
- [Contributing](CONTRIBUTING.md): commits, pull requests, Linear, design docs

Designs:

| Phase | Design |
| --- | --- |
| 0 | [Documentation](hub/designs/phase-0-documentation.md) |
| 1 | [Foundations: Terraform, GKE, Argo CD](hub/designs/phase-1-foundations.md) |
| 2 | [Octomatron](hub/designs/phase-2-octomatron.md) |
| 3 | [Ingress and authentication](hub/designs/phase-3-ingress-and-auth.md) |
| 4 | [Docs site](hub/designs/phase-4-docs-site.md) |
| 5 | [Claude Code tooling](hub/designs/phase-5-tooling.md) |

## Formats

| Format | Use for | Published as |
| --- | --- | --- |
| Markdown (`.md`) | Designs, runbooks, conventions | `page.html` (rendered) and `page.md` (original, for agents) |
| HTML (`.html`) | Rich, self-contained pages such as generated architecture views | `page.html`, unchanged |
| Images (`.svg`, `.png`, …) | Diagrams referenced from pages | unchanged |

Diagrams in Markdown are Mermaid code blocks; GitHub and the site both render them.

## Publishing

Every push to `main` publishes the repository to `https://docs.dev.kfirs.com/<path>` (behind the hub's sign-in), so
this page is at [README.html](https://docs.dev.kfirs.com/README.html). No pull request is needed: push to `main`.
There are no menus or index pages; link to pages directly. How it works: [phase 4](hub/designs/phase-4-docs-site.md).
