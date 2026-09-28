# Phase 2: Switchboard

**Goal**: replace GitHub Actions. A GitHub App delivers webhooks to Switchboard in GKE; Switchboard runs the Tekton
`PipelineRun`s that the repository's root `.switchboard.yaml` maps to those events and reports each one as a GitHub
check run. Code: [arikkfir-org/switchboard](https://github.com/arikkfir-org/switchboard). Names and wiring:
[reference](../reference.md#switchboard).

## Principles

1. **Application-agnostic.** Switchboard knows nothing about what a repository builds, its language, layout, CI or CD.
2. **One file.** The only repository file Switchboard reads is the root `.switchboard.yaml`, plus the `PipelineRun`
   files it points to. There are no conventional directories and no configuration in Tekton labels or annotations.
3. **Plain Tekton.** `PipelineRun` files are ordinary Tekton YAML. Switchboard injects event context only through
   `params` (Go templates over a documented context) and an optional token workspace.

Switchboard is derived from an earlier, application-aware implementation; these principles are what changed.

## Flow

```mermaid
sequenceDiagram
  autonumber
  participant GH as GitHub
  participant SB as Switchboard
  participant K8s as Kubernetes / Tekton
  GH->>SB: webhook (push, pull_request, merge_group, check_run, check_suite)
  SB->>SB: verify HMAC signature, dedupe delivery, 202
  SB->>GH: read .switchboard.yaml at the commit under test
  SB->>SB: match events, branches, tags and paths, then apply trust rules
  alt paths don't match
    SB->>GH: check run "completed / skipped"
  else untrusted fork pull request
    SB->>GH: check run "action_required" + "Approve and run" button
  else run
    SB->>GH: read the PipelineRun file at the same commit
    SB->>K8s: Secret with installation token (optional)
    SB->>K8s: create PipelineRun in the repository's ci- namespace
    SB->>GH: check run "queued" (links to Tekton Dashboard)
    loop reconciler (leader only)
      K8s-->>SB: PipelineRun status changes
      SB->>GH: check run in_progress / completed + TaskRun table + failed-step log tail
    end
  end
```

## Configuration

```yaml
apiVersion: switchboard.kfirs.com/v1
pipelines:
  - name: ci                          # check-run name
    pipelineRun: .tekton/ci.yaml      # any path; Switchboard assumes no layout
    on:
      pull_request: {branches: [main]}
      merge_group: {}
      push: {branches: [main], tags: ["v*"], paths: ["src/**"]}
    params:
      repo-url: "{{ .Repository.CloneURL }}"
      revision: "{{ .Revision }}"
    githubToken: {workspace: github-token}
    timeout: 1h
    cancelInProgress: true
```

The full schema and template context are in the [reference](../reference.md#repository-configuration-switchboardyaml)
and the Switchboard README.

## Behaviour

| Situation | Behaviour |
| --- | --- |
| No `.switchboard.yaml` | Nothing happens |
| Invalid `.switchboard.yaml` | One failed check run named `switchboard` explaining the error |
| Event matches, paths don't | Check run reported as `skipped`, which satisfies required checks |
| Changed files can't be determined | Treated as matching (runs rather than silently skipping) |
| Pull request from outside the org (fork) | `action_required` check with an "Approve and run" button for users with write access |
| Repository namespace missing | Failed check: "repository not onboarded" |
| Newer commit on the same pull request or branch | Older runs of the same pipeline are cancelled (`cancelInProgress`, default on for pull requests and the merge queue) |
| Merge group destroyed | Its runs are cancelled |
| "Re-run" in GitHub | The pipeline re-runs with the original context, stored in the check run itself, so it works after pruning |

## Tenancy and identity

```mermaid
flowchart LR
  SB[switchboard/switchboard] -- creates PipelineRuns, token Secrets --> NS1[ci-docs]
  SB --> NS2[ci-switchboard]
  SB --> NS3[ci-...]
  NS1 -- KSA pipeline --> B1[(arikkfir-docs: object user)]
  NS2 -- KSA pipeline --> B2[(Artifact Registry images: writer)]
```

- Each repository runs in its own namespace, `ci-<repository>`, created in `delivery` (onboarding a repository is a
  small change there, plus IAM in `infra` if it needs cloud access).
- Runs use the namespace's `pipeline` service account. GCP permissions attach to that identity through Workload
  Identity, so one repository's pipelines can never use another's permissions.
- Switchboard's own identity can create `PipelineRun`s and token Secrets only in tenant namespaces
  (`ClusterRole switchboard-tenant`, bound per namespace), and watch runs cluster-wide.
- Tekton's default pod template schedules runs onto the Spot `ci` node pool.

## Decisions

| Decision | Why | Rejected |
| --- | --- | --- |
| Check runs (Checks API) rather than commit statuses | Rich output, re-run buttons, requested actions, required-check integration | Commit statuses |
| Params and a token workspace instead of templating inside PipelineRun files | Files stay valid Tekton; no templating collisions with scripts | Pipelines-as-Code style `{{ }}` substitution in YAML |
| Switchboard names runs itself | The token Secret can be created before the run, then owned by it for garbage collection | `generateName` plus pending runs |
| Skipped checks for path-filtered pipelines | Required checks can't deadlock on unrelated changes | Not reporting (blocks merges) |
| Namespace per repository | Isolation of credentials and permissions | Shared CI namespace |
| Unstructured objects + dynamic client | Avoids the heavy Tekton Go module; only a few status fields are read | Tekton typed clients |
| Leader election for the reconciler only | Any replica can take webhooks; one writer updates check runs | Single replica without election |

## Security

- Webhooks are verified (HMAC-SHA256) before anything else; the webhook route is the only public path.
- Fork pull requests never run without approval from someone with write access.
- Installation tokens are minted per run with least permissions (contents read), expire within an hour and are
  garbage-collected with the run.
- Trusted pull requests can change their own pipeline files, so they can use their namespace's permissions; that is
  why namespaces, not pipelines, are the isolation boundary.

## Rollout

1. Create the GitHub App (permissions and events in the [reference](../reference.md#switchboard)); store its ID, key
   and webhook secret in Secret Manager.
2. Build the first image locally with `ko` (see the [bootstrap runbook](../runbooks/bootstrap.md)); afterwards
   Switchboard builds itself on tags `v*`.
3. Argo CD deploys it from `delivery`.
4. Apply the GitHub rulesets once `ci` checks appear on pull requests.
