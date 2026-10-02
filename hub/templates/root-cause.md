# Root-cause write-up template

An investigation ends in a write-up, whether or not it leads to a fix or an issue. It is the record the next person reads instead of investigating again. Write it for the person who reported the problem and the one who will fix it, and assume they have ninety seconds.

- **Where**: in this repository, at `root-causes/<YYYY-MM-DD>-<slug>.md`, dated the day the investigation concluded and named for the symptom. It describes what is, so it goes straight to `main`.
- **Not a design for the fix**: it names the code at fault; the fix belongs to an issue and its pull request, which link here.
- **Visuals**: the [writing toolkit](toolkit.md).

Copy the skeleton and keep its headings, in their order:

````markdown
# <The symptom, in the user's terms, as a state: "Docs pages show last week's content">

**Status**: 🔴 still broken on `main` · **Seen in**: <component, environment> · **Since**: <date or commit> · **Issue**: <ENG-123, or none>

## 🎯 TL;DR

<Two sentences someone can act on: what's broken, for whom, and why.>

## 🧭 How it's meant to work

<The mechanism as it should behave, for a reader who has never seen it: a diagram, then a sentence or two.>

## 💥 Root cause

<The defect in one or two sentences, and the code or configuration it lives in, named.>

## 🔍 Evidence

| Claim                | Evidence                                    | Status |
|----------------------|---------------------------------------------|--------|
| <what you concluded> | <the log line, the query, the reproduction> | ✅     |

<details>
<summary>🔎 <Evidence too long for the table></summary>

…

</details>

## 🌍 Blast radius

<Who and what it affects, since when, and how often.>

## 🩺 Still on `main`?

<🔴 yes / 🟢 no: fixed by <commit> and deployed / 🟡 fixed on `main`, not deployed yet. Read the code that was running when it happened, then `main`.>

## 📊 Confidence

<High, medium or low. If not high, what is still unverified.>

## 🏁 Outcome

<What happens next: the issue filed, the fix that shipped, or why nothing will change.>
````
