# Writing toolkit for investigations and walkthroughs

Root-cause write-ups and pull request walkthroughs are read by someone with ninety seconds who doesn't know the code. This page is the visual vocabulary they share; the templates are [root-cause write-up](root-cause.md) and [pull request walkthrough](walkthrough.md).

## Prefer the left

| Instead of                                        | Use                                         |
|---------------------------------------------------|---------------------------------------------|
| A paragraph tracing how something flows           | A diagram                                   |
| A paragraph narrating a chain of events           | A sequence diagram, or a numbered list      |
| Parallel bullet lists under headings              | A table, one row per thing compared         |
| Numbers in a sentence                             | A chart or a table                          |
| Status words: broken, fixed, partly, new, changed | A status marker                             |
| A wall of logs or code in the text                | A drill-down                                |
| An abstract description                           | A worked example with real values           |
| Jargon                                            | Plain words, with the term in brackets once |

Three rules keep this from backfiring:

- A diagram earns its place by showing a mechanism: order, branching, who talks to whom. A box with one arrow is a sentence in a rectangle.
- A table needs at least two rows and two columns that differ. One row is a sentence in a costume.
- Never a chart without real numbers.

## Diagrams

Mermaid code blocks, which GitHub and the docs site both render (the site loads Mermaid 11).

| To show                     | Use                                  |
|-----------------------------|--------------------------------------|
| Who talks to whom, in order | `sequenceDiagram`, with `autonumber` |
| Where the path branches     | `flowchart LR`                       |
| When things happened        | `timeline`                           |
| How much                    | `xychart-beta`                       |
| A state that got stuck      | `stateDiagram-v2`                    |
| Which commit                | `gitGraph`                           |

Give the step at fault a class of its own, with a text colour so it reads in dark mode too:

```mermaid
flowchart LR
  A[Pull request] --> B[ci] --> C{Docs check}
  C -->|links resolve| D[Merge queue]
  C -->|a link is broken| E[Red check]
  classDef bad fill:#ffe4e6,stroke:#e11d48,color:#881337
  class E bad
```

## Status markers

Emoji, because they look the same on GitHub, on the docs site and in a terminal. GitHub strips inline styles, so coloured labels don't survive.

| Marker | Means                                         |
|--------|-----------------------------------------------|
| 🔴     | Broken, still on `main`                       |
| 🟢     | Fixed and deployed                            |
| 🟡     | Partly, or fixed on `main` but not deployed   |
| ✅     | Proven                                        |
| ❌     | Ruled out                                     |
| ❓     | Not verified                                  |
| ⚠️     | Caution                                       |
| 🆕     | New                                           |
| 🔄     | Changed                                       |

## Drill-downs

Evidence that would turn a section into a wall goes in a `<details>` block, which the reader opens when they want it. Leave a blank line after `</summary>`, or the Markdown inside won't render.

```html
<details>
<summary>🔎 The failing step's log, at the deployed revision</summary>

…a fenced code block, a table or prose…

</details>
```

## Images

A screenshot or any other image of large content opens at full size when clicked. Shrunk to a column, often beside another, its text can't be read.

| Where                    | How                                                                                       |
|--------------------------|-------------------------------------------------------------------------------------------|
| Markdown (GitHub, docs)  | Link the image to itself: `[![Branches tab, dark](branches-dark.png)](branches-dark.png)` |
| An HTML page or Artifact | Paste the snippet below once, at the end of `<body>`                                      |

The snippet marks every image shown smaller than its own size. A click opens it in a dialog, fitted to the window's width; a click on it shows its own pixels; Esc or a click outside closes it. Images inside a link keep the link. It works with `data:` images, which a browser refuses to open in a tab of their own.

<details>
<summary>🔎 Click-to-enlarge snippet for HTML pages and Artifacts</summary>

```html
<style>
img.zoomable { cursor: zoom-in; }
dialog.zoom { box-sizing: border-box; width: 100vw; height: 100vh; max-width: none; max-height: none; margin: 0; padding: 24px; border: 0; background: rgb(0 0 0 / .88); overflow: auto; }
dialog.zoom img { display: block; margin: auto; width: min(100%, var(--width)); height: auto; cursor: zoom-in; }
dialog.zoom.actual img { width: var(--width); max-width: none; cursor: zoom-out; }
</style>
<script>
// Opens a shrunk image at full size: click it, click again for its own pixels, Esc or click outside to close.
(() => {
  const mark = img => img.classList.toggle("zoomable", !img.closest("a, dialog") && img.naturalWidth > img.clientWidth + 1);
  document.addEventListener("load", e => { if (e.target.tagName === "IMG") mark(e.target); }, true);
  document.querySelectorAll("img").forEach(img => { if (img.complete) mark(img); });
  addEventListener("click", e => {
    const img = e.target.closest("img.zoomable");
    if (!img) return;
    const dialog = document.createElement("dialog"), copy = img.cloneNode();
    copy.removeAttribute("class"); copy.removeAttribute("style"); copy.removeAttribute("width"); copy.removeAttribute("height");
    dialog.className = "zoom";
    dialog.style.setProperty("--width", img.naturalWidth + "px");
    dialog.append(copy);
    dialog.addEventListener("click", ev => { if (ev.target === copy) dialog.classList.toggle("actual"); else dialog.close(); });
    dialog.addEventListener("close", () => dialog.remove());
    document.body.append(dialog);
    dialog.showModal();
  });
})();
</script>
```

</details>

## Constraints

- GitHub-flavoured Markdown with one `#` heading and relative links to other `.md` files, like every page here.
- No inline styles, scripts or images from other hosts: GitHub strips the first two, and the docs site sits behind sign-in. The click-to-enlarge snippet is for HTML pages and Artifacts, not Markdown.
- Accuracy over polish: a wrong diagram is worse than none.
