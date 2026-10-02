# Pull request walkthrough template

A walkthrough guides a reviewer through a pull request they can't follow from its diff alone: what it builds on, why it's needed, how it works, and the changes in the order they make sense. A diff lists files alphabetically; a walkthrough tells the story.

- **When**: a pull request that changes behaviour across more than one component, or that a reviewer can't follow from its description and diff. Not for a typo, a version bump, a lint fix or a regenerated file.
- **Where**: `walkthroughs/<repository>/pr-<number>.md`, in a repository as visible as the pull request. Link it from the pull request's `## Summary`, and update it when a push changes the story.
  - **A public repository's pull request**: in this repository, pushed to `main` once the pull request exists, like a design for work in flight.
  - **An internal repository's** (`fin`): in that repository's own `docs/`, committed in the pull request it explains. This repository is public, so anything in it is readable by anyone on GitHub.
- **Not a design**: the design doc says why the system is shaped this way and stays; a walkthrough explains one diff and is done when the pull request merges.
- **Visuals**: the [writing toolkit](toolkit.md).

Copy the skeleton and keep its headings, in their order:

````markdown
# <repository>#<number>: <what the pull request does>

**Pull request**: <link> · **Issue**: <ENG-123> · **Design**: <link, or none>

## 🎯 TL;DR

<What changes, for whom, in two sentences.>

## 🧭 Orient me

<What the reader can't be assumed to know: the parts this builds on and how they fit, with a diagram. Assume they know nothing about it.>

## ❓ Why

<The problem this solves, in a paragraph. Link the issue rather than re-arguing it.>

## 🔁 How it works

<The new behaviour end to end: a sequence diagram, then the steps.>

## 🧱 The changes

<In build order, never file by file: each step, what it adds, and the files it touches.>

1. <The first change> (`path/to/file`)

## ✅ What proves it

<The tests and checks that cover it, and what each one pins.>

## ⚠️ Watch out

<What could break, what needs a manual step, and where a reviewer should look hardest.>
````
