# docs

The hub-wide part of the `arikkfir-org` knowledge base: conventions, the hub reference, and the designs and runbooks
that are about no one repository. Every repository keeps the pages about it in its own `docs/<repository>/`, and the
pages here that belong to one are moving there ([docs ownership](hub/designs/docs-ownership.md)). Every meaningful unit
of work gets a visual design document in the repository it changes.

## Start here

- [Hub overview](hub/overview.html): the whole platform on one page
- [Hub reference](hub/reference.md): every name, address, identity and permission (the contract between repositories)
- [Bootstrap runbook](hub/runbooks/bootstrap.md): bringing the hub up from nothing
- [Octomaton rename runbook](octomaton/runbooks/rename.md): the one-off move from Octomatron to Octomaton
- [Contributing](CONTRIBUTING.md): commits, pull requests, Linear, design docs

Designs:

| Phase | Design |
| --- | --- |
| 0 | [Documentation](hub/designs/phase-0-documentation.md) |
| 0 | [Each repository owns its docs](hub/designs/docs-ownership.md) |
| 1 | [Foundations: Terraform, GKE, Argo CD](hub/designs/phase-1-foundations.md) |
| 2 | [Octomaton](octomaton/designs/phase-2-octomaton.md) |
| 2 | [octomaton.dev: domain, webhook and Go module](octomaton/designs/octomaton-dev.md) |
| 3 | [Ingress and authentication](delivery/designs/phase-3-ingress-and-auth.md) |
| 4 | [Docs site](hub/designs/phase-4-docs-site.md), replaced by the composition below |
| 4 | [Docs site composition: one URL space from every repository](hub/designs/docs-site-composition.md) |
| 5 | [Claude Code tooling](tooling/designs/phase-5-tooling.md) |

## Formats

| Format                     | Use for                                                         | Published as                                                   |
|----------------------------|-----------------------------------------------------------------|----------------------------------------------------------------|
| Markdown (`.md`)           | Designs, runbooks, conventions                                  | `page.md.html` (rendered) and `page.md` (original, for agents) |
| HTML (`.html`)             | Rich, self-contained pages such as generated architecture views | `page.html`, unchanged                                         |
| Images (`.svg`, `.png`, …) | Diagrams referenced from pages                                  | unchanged                                                      |

Diagrams in Markdown are Mermaid code blocks; GitHub and the site both render them.

## Publishing

Every push to `main` publishes this repository to `https://docs.dev.kfirs.com/<path>` (behind the hub's sign-in), in one URL space with every other repository's `docs/`, so this page is at [README.md.html](https://docs.dev.kfirs.com/README.md.html). There are no menus or index pages; link to pages directly. How it works: [docs site composition](hub/designs/docs-site-composition.md).
