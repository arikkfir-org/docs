# Phase 0: Documentation

**Goal**: one shared, durable place where designs, decisions and knowledge accumulate, readable by people in a
browser and by coding agents as plain Markdown.

## Design

```mermaid
flowchart LR
  subgraph Authors
    H[People]
    A[Coding agents]
  end
  subgraph repo[arikkfir-org/docs, main]
    MD[Markdown<br/>designs, runbooks]
    HTML[HTML<br/>rich visuals]
    IMG[Images]
  end
  H -- push to main --> repo
  A -- push to main --> repo
  repo -- push event --> SB[Switchboard]
  SB --> TK[Tekton: render changed Markdown,<br/>rsync to bucket]
  TK --> GCS[(gs://arikkfir-docs<br/>public objects, no listing)]
  GCS -- page.html --> B[Browsers]
  GCS -- page.md --> AG[Agents]
```

| Source in Git | Served as | Consumer |
| --- | --- | --- |
| `path/page.md` | `path/page.html` (rendered) and `path/page.md` (original) | browsers; agents |
| `path/page.html` | `path/page.html` (unchanged) | browsers |
| `path/image.svg` | `path/image.svg` | pages |

URLs are `https://storage.googleapis.com/arikkfir-docs/<path>`.

## Decisions

| Decision | Why | Rejected |
| --- | --- | --- |
| Direct pushes to `main`, no pull requests | Knowledge sharing must be frictionless; designs are discussed in the pull requests they accompany | Review gate on docs: slows the habit of writing things down |
| Markdown + Mermaid by default | Diffable, renders on GitHub and on the site, agents read it natively | Wiki (not in Git), Google Docs (not agent-friendly) |
| HTML allowed as-is | AI-generated architecture pages are often richer than Markdown | Forcing everything through Markdown |
| Serve the Markdown source next to the HTML | Agents fetch `.md` directly without scraping HTML | HTML only |
| Public bucket, direct links only, no navigation | Simplest thing that works; navigation can come later | Static-site generator with menus and search |
| `hub/reference.md` as the single source of facts | Five repositories must agree on names, identities and addresses | Repeating values in every design |

## Organization README

`arikkfir-org/.github/README.md` introduces the organization and points at `docs` for everything else.

## Conventions

[CONTRIBUTING.md](../../CONTRIBUTING.md) defines commits, pull requests, Linear keys and design-document expectations
for every repository. Each repository adds a `CLAUDE.md` with its own agent rules.

## Open questions

- A landing page or search, once the number of pages makes direct links impractical.
- A custom domain (for example `docs.kfirs.com`) would need a load balancer or a proxy for HTTPS.
