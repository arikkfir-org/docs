# Linear projects

**Decision**: a task too large for one issue gets a Linear project. Agents suggest it to their person and create it only once they agree. Each slice of the work gets its own issue in the project, slices are preferably self-contained and deployable on their own, and the project's status and updates stay current as slices land. The rules are in [CONTRIBUTING.md](../../CONTRIBUTING.md) ("Projects"). Ticket: [ENG-166](https://linear.app/arikkfir/issue/ENG-166). Pull request: [docs#63](https://github.com/arikkfir-org/docs/pull/63).

## Context

- `CONTRIBUTING.md` covered issues only: one pull request per issue, and sub-issues for a large one. It said nothing about projects.
- ENG already runs projects (Fin's ledger as a tree, Replace Descope with Keycloak, Institutions and others), but each session decided for itself whether to create one, how to cut its issues and whether to report progress on it.

## Design

```mermaid
flowchart LR
  T[Large task] -->|agent suggests| A{Person agrees?}
  A -->|yes| P[Linear project]
  A -->|no| I[One issue,<br/>sub-issues if needed]
  P --> S1[Issue: slice 1] --> PR1[Pull requests:<br/>Part of, then Closes] --> M[main, deployed]
  P --> S2[Issue: slice 2] --> PR2[Pull requests] --> M
  M -->|slice lands| U[Project status<br/>and update]
  U -.-> P
```

## Decisions

| Decision                                                                                  | Why                                                                                                                                                                            | Rejected                                                                                                                                                      |
|-------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A task too large for one issue gets a project                                             | A project holds the goal, its slices and their progress in one place, across repositories and over many sessions                                                               | One large issue with sub-issues: no status or updates of its own, and it reads as one change                                                                  |
| Agents suggest a project; they create it only once their person agrees                    | A project sets the plan its person will follow for weeks; they decide whether the task is that large and how to cut it                                                         | Agents creating projects unasked: projects nobody planned would fill the workspace                                                                            |
| One issue per slice, however many pull requests it takes                                  | A slice is one logical change, so its issue is the unit of progress: its pull requests say `Part of` it, the last `Closes` it, and the project shows the slice done when it is | An issue per pull request: it splits one change into issues that mean nothing alone. Issues per repository or per layer: they finish without anything working |
| Slices are preferably self-contained and deployable on their own                          | Every merge to `main` releases, so a slice that stands on its own can ship, be reviewed and be rolled back on its own; each of its pull requests still leaves `main` working   | Slices that only work together: half-done work sits on `main` or in long-lived branches                                                                       |
| The project's status stays current; an update posts at milestones and significant changes | The person reads progress without opening each issue; a health of on track, at risk or off track says when to step in                                                          | An update per pull request: noise that buries the milestones                                                                                                  |

## Failure modes

Nothing checks these rules: Linear accepts any project and any slice. They hold only as long as whoever plans the work follows `CONTRIBUTING.md`. A slice that can't stand on its own is allowed ("preferably"), and its pull request says why.

## Rollout

None: guidance only. Existing projects keep their shape; the rules apply from the next large task.
