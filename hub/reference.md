# Hub reference

The authoritative list of every name, identifier, address and permission in the development hub. Terraform
(`arikkfir-org/infra`), GitOps manifests (`arikkfir-org/delivery`), Octomaton (`arikkfir-org/octomaton`) and every
repository's CI configuration must agree with this page. Change it here first, then in code.

## Identity and placement

| Item | Value |
| --- | --- |
| GitHub organization | `arikkfir-org` |
| GCP project | `arikkfir` (number `8909046976`, organization `468825984716`) |
| Region / cluster zone | `me-west1` / `me-west1-a` |
| DNS domain | `kfirs.com` (Cloud DNS zone `kfirs-com`): hub tools under `dev.kfirs.com`, sign-in at `auth.kfirs.com`. `octomaton.dev` (zone `octomaton-dev`): Octomaton's webhook and Go module path. `kfirfamily.com` (zone `kfirfamily-com`) is imported but unused. |
| Identity provider | Descope company `KFIRS`, project `development` (`P3JyPV2qsSrMLUpVPTGcBNRHlSkv`), issuer `https://api.descope.com/P3JyPV2qsSrMLUpVPTGcBNRHlSkv` |
| Label/annotation prefix | `kfirs.com/` for hub-wide labels, `octomaton.dev/` for Octomaton bookkeeping |
| Terraform state | GCS bucket `arikkfir-devops` (created by hand, versioned), prefixes `github`, `gcp`, `argocd` |

## Repositories

| Repository | Purpose | Default-branch rules | Required checks |
| --- | --- | --- | --- |
| `.github` | Org profile, org-wide GitHub defaults | PR + 1 approval + merge queue | `Continuous Integration` |
| `docs` | Knowledge base, published to `arikkfir-docs` and served at `docs.dev.kfirs.com` | PR + 1 approval + merge queue; direct pushes to `main` only from automation | `Continuous Integration` |
| `infra` | Terraform: GitHub, GCP, Argo CD bootstrap | PR + 1 approval + merge queue | `Continuous Integration` |
| `delivery` | Argo CD applications (GitOps) | PR + 1 approval + merge queue | `Continuous Integration` |
| `octomaton` | CI orchestrator (GitHub App + Tekton) | PR + 1 approval + merge queue | `Continuous Integration` |
| `tooling` | Claude Code web bundle | PR + 1 approval + merge queue | `Continuous Integration` |

Every repository gets the same `default-branch` ruleset: no deletion, no force-push, pull requests with one approval
(stale approvals dismissed, last push approved, conversations resolved), merge commits only, through the merge queue.
Organization admins may bypass it (`bypass_mode = always`). An approval by `arikkfir-reviewer`, the [pull request
reviewer](#pull-request-reviewer), counts: it has `push` on every repository. The required check, `Continuous
Integration`, is each repository's `ci` pipeline under its `displayName`, pinned to the Octomaton GitHub App
(`integration_id`). In `docs`, direct pushes to `main` are reserved for automation: publishing the site and syncing
other repositories' branch and pull-request docs into a directory per repository and branch. Every repository also has
Dependabot alerts and Dependabot security updates on; version updates would need a `.github/dependabot.yml` in the
repository.

## Network

| Resource | Name | Value |
| --- | --- | --- |
| VPC | `hub` | custom mode |
| Subnet (me-west1) | `hub` | `10.10.0.0/20`, Private Google Access on |
| Secondary range | `pods` | `10.20.0.0/16` |
| Secondary range | `services` | `10.30.0.0/20` |
| Cloud Router / NAT | `hub` / `hub` | auto-allocated egress IPs, all subnet ranges |
| Static IP (regional, external) | `ingress-protected` | Traefik protected load balancer |
| Static IP (regional, external) | `ingress-public` | Traefik public load balancer |

## GKE

| Setting | Value |
| --- | --- |
| Cluster | `hub`, zonal `me-west1-a`, release channel `REGULAR` with minimum version 1.36, Dataplane V2 |
| Workload Identity pool | `arikkfir.svc.id.goog` |
| Nodes | private (no external IPs), egress through Cloud NAT |
| Control plane access | DNS-based endpoint (IAM-authenticated); no external IP endpoint |
| Gateway API | GKE-managed Gateway API disabled; CRDs and Traefik installed by Argo CD |
| Add-ons | Cloud Storage FUSE CSI driver (docs site). HTTP load balancing (GKE Ingress) is disabled |
| Node service account | `gke-hub-nodes@arikkfir.iam.gserviceaccount.com` |
| Node pool `system` | `e2-standard-4`, on-demand, `me-west1-a`, autoscaling 1-3, label `kfirs.com/pool=system` |
| Node pool `ci` | `e2-standard-4`, Spot, `me-west1-a/b/c`, autoscaling 0-4, label `kfirs.com/pool=ci`, taint `kfirs.com/pool=ci:NoSchedule` |

Tekton runs land on the `ci` pool through Tekton's default pod template (node selector plus toleration).

## Artifact Registry and buckets

| Resource | Name | Access |
| --- | --- | --- |
| Docker repository | `me-west1-docker.pkg.dev/arikkfir/images` | nodes read; `ci-octomaton/pipeline` writes |
| Bucket | `arikkfir-docs` (`ME-WEST1`, uniform access, public access prevention enforced) | private: `docs/docs` reads and serves it at `https://docs.dev.kfirs.com`; `ci-docs/pipeline` writes |
| Bucket | `arikkfir-claude` (`ME-WEST1`, uniform access) | public object reads (no listing); `ci-tooling/pipeline` writes |

Public URLs (`arikkfir-claude` only) are `https://storage.googleapis.com/<bucket>/<path>`.

## Secret Manager

Terraform creates the secret containers; values are added by hand (`gcloud secrets versions add`). External Secrets
Operator is the only reader.

| Secret | Content | Consumed by |
| --- | --- | --- |
| `octomaton-github-app-id` | GitHub App ID (number) | `octomaton/octomaton-github` key `app-id` |
| `octomaton-github-private-key` | GitHub App private key (PEM) | `octomaton/octomaton-github` key `private-key` |
| `octomaton-github-webhook-secret` | GitHub App webhook secret | `octomaton/octomaton-github` key `webhook-secret` |
| `oidc-client-secret` | Descope access key (OIDC client secret) | `auth/oauth2-proxy` key `client-secret`; `argocd/argocd-oidc` key `clientSecret` |
| `oauth2-proxy-cookie-secret` | 32 random bytes, base64 | `auth/oauth2-proxy` key `cookie-secret` |
| `reviewer-deepseek-api-key` | DeepSeek API key | `ci-*/reviewer-deepseek-api-key` key `api-key` (the [reviewer](#pull-request-reviewer)'s `review` task) |
| `reviewer-github-pat` | `arikkfir-reviewer`'s fine-grained personal access token | `ci-*/reviewer-github-pat` key `token` (the [reviewer](#pull-request-reviewer)'s `report` task) |

## GCP identities and permissions

Kubernetes workloads use GKE Workload Identity Federation with direct principal bindings (no Google service accounts):
`principal://iam.googleapis.com/projects/8909046976/locations/global/workloadIdentityPools/arikkfir.svc.id.goog/subject/ns/<namespace>/sa/<service-account>`.

| Principal (namespace/KSA) | Role | Scope |
| --- | --- | --- |
| `external-secrets/external-secrets` | `roles/secretmanager.secretAccessor` | each secret above |
| `cert-manager/cert-manager` | `roles/dns.admin` | managed zones `kfirs-com` and `octomaton-dev` |
| `grafana/grafana` | `roles/monitoring.viewer` | project |
| `octomaton/octomaton` | `roles/telemetry.metricsWriter`, `roles/telemetry.tracesWriter`, `roles/serviceusage.serviceUsageConsumer` | project |
| `docs/docs` | `roles/storage.objectViewer` | bucket `arikkfir-docs` |
| `ci-docs/pipeline` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-tooling/pipeline` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-claude` |
| `ci-octomaton/pipeline` | `roles/artifactregistry.writer` | repository `images` |
| `gke-hub-nodes@` (GSA) | `roles/container.defaultNodeServiceAccount` | project |
| `gke-hub-nodes@` (GSA) | `roles/artifactregistry.reader` | repository `images` |

There is no Workload Identity Federation pool for workloads outside GCP: no GitHub Actions run, and CI runs in the
cluster. The pre-existing `github-actions`, `greenstar` and `arikkfir.svc.id.goog` pools belong to other projects or
to GKE and are not managed here.

## Kubernetes platform

| Namespace | Component | Source | Version |
| --- | --- | --- | --- |
| `argocd` | Argo CD (self-managed after bootstrap) | `https://argoproj.github.io/argo-helm` `argo-cd` | `10.9.4` (Argo CD v3.5.3) |
| `cert-manager` | cert-manager | `https://charts.jetstack.io` `cert-manager` | `v1.21.2` |
| `external-secrets` | External Secrets Operator | `https://charts.external-secrets.io` `external-secrets` | `2.11.0` |
| `keda` | KEDA | `https://kedacore.github.io/charts` `keda` | `2.21.0` |
| `nats` | NATS (JetStream): three clustered servers, a 50Gi volume each | `https://nats-io.github.io/k8s/helm/charts` `nats` | `2.15.0` |
| `nats` | NACK (JetStream controller) | same repo, `nack` | `0.35.0` |
| `nats` | NUI | `https://nats-nui.github.io/k8s/helm/charts` `nui` | `0.1.6` (image tag pinned) |
| `reloader` | Stakater Reloader | `https://stakater.github.io/stakater-charts` `reloader` | `2.2.17` |
| `traefik` | Gateway API CRDs (standard channel) | `kubernetes-sigs/gateway-api` release | `v1.6.2` |
| `traefik` | Traefik | `https://traefik.github.io/charts` `traefik` | `41.6.0` (Traefik v3.7) |
| `auth` | oauth2-proxy (auth interceptor) | `https://oauth2-proxy.github.io/manifests` `oauth2-proxy` | `10.7.0` |
| `grafana` | Grafana | `https://grafana-community.github.io/helm-charts` `grafana` | `13.2.7` (Grafana 13.2.3) |
| `tekton-operator` | Tekton Operator | `tektoncd/operator` release manifest from `infra.tekton.dev` (Tekton's release host since v0.78) | `v0.81.1` |
| `tekton-pipelines` | Pipelines, Triggers, Dashboard (via `TektonConfig`; Results, Chains, Pipelines-as-Code and the operator's NetworkPolicies off) | operator-managed | operator default |
| `octomaton` | Octomaton | `me-west1-docker.pkg.dev/arikkfir/images/octomaton` | The short SHA of the `main` commit Argo CD deploys (`${ARGOCD_APP_REVISION_SHORT}`, see [Octomaton](#octomaton)). There are no version tags; every push to `main` publishes one, which is also the version the binary and its telemetry report |
| `octomaton` | `go-import`: Caddy answering for `octomaton.dev` | `docker.io/library/caddy` | `2.11.4-alpine` |
| `docs` | Docs site: Caddy serving `arikkfir-docs` (Cloud Storage FUSE mount) | `docker.io/library/caddy` | `2.11.4-alpine` |
| `ci-<repo>` | CI tenants (one per repository) | `delivery` | n/a |

NATS clients, NACK included, connect to `nats://nats.nats.svc.cluster.local:4222`. JetStream streams may keep up to
three replicas. The servers spread across system-pool nodes when there are several, but don't make the pool grow.

## Ingress

Traefik runs once with two entry-point pairs, each exposed by its own L4 (passthrough network) load balancer: a
`LoadBalancer` Service with `loadBalancerClass: networking.gke.io/l4-regional-external` that binds the reserved IP by
name (annotation `networking.gke.io/load-balancer-ip-addresses`). Without the HTTP load-balancing add-on, these load
balancers need GKE 1.36+:

| Gateway | Entry points (container → exposed) | Load balancer IP | Interceptor | Who may attach routes |
| --- | --- | --- | --- | --- |
| `traefik/protected` | `web` 8000→80 (redirect), `websecure` 8443→443 | `ingress-protected` | Entry-point middlewares `strip-auth-headers` + `oidc` on `websecure`, applied to every route | any namespace |
| `traefik/public` | `public-web` 9080→80 (redirect), `public-websecure` 9443→443 | `ingress-public` | `strip-auth-headers` only | namespaces labelled `kfirs.com/public-ingress=true` |

Certificates come from cert-manager (Let's Encrypt, DNS-01 through Cloud DNS, ClusterIssuer `letsencrypt`):

| Listener | Hostname | Certificate / secret |
| --- | --- | --- |
| `protected/websecure`, `public/public-websecure` | `*.kfirs.com` (which also matches `*.dev.kfirs.com`) | `wildcard-kfirs-com` (`*.kfirs.com`, `*.dev.kfirs.com`) / `traefik/wildcard-kfirs-com-tls` |
| `public/octomaton-dev` (port 9443) | `octomaton.dev` | `octomaton-dev` / `traefik/octomaton-dev-tls` |

The `octomaton-dev` listener accepts routes only from namespace `octomaton` (which also carries
`kfirs.com/public-ingress=true`).

| Host | Gateway | Backend |
| --- | --- | --- |
| `argocd.dev.kfirs.com` | protected | `argocd/argocd-server:80` |
| `tekton.dev.kfirs.com` | protected | `tekton-pipelines/tekton-dashboard:9097` |
| `grafana.dev.kfirs.com` | protected | `grafana/grafana:80` |
| `traefik.dev.kfirs.com` | protected | Traefik dashboard (`api@internal`, IngressRoute) |
| `nui.dev.kfirs.com` | protected | `nats/nui` |
| `docs.dev.kfirs.com` | protected | `docs/docs:80` |
| `auth.kfirs.com` | public | `auth/oauth2-proxy:80`, path `/oauth2` |
| `octomaton.dev` | public (listener `octomaton-dev`) | `octomaton/octomaton:80` for path `/github/hooks`; `octomaton/go-import:80` for everything else |

DNS A records (TTL 300) point each host at its gateway's IP: in zone `kfirs-com` for `kfirs.com` hosts, and the apex
of zone `octomaton-dev` for `octomaton.dev`.

## Authentication

- Descope decides who signs in: every user of the project, and nobody else. Users sign in with Google through a
  sign-in-only flow, and the project blocks self-registration, so users can't register themselves. The project must
  have no SSO tenant or tenant self-provisioning domain: either would admit users by domain.
- oauth2-proxy (`auth` namespace) is the OIDC client (`client_id` = Descope project ID, `client_secret` = Descope access
  key), keeps a session cookie on `.kfirs.com`, and admits every user Descope authenticates (`emailDomains: ["*"]`, no
  email list).
- Traefik's `oidc` ForwardAuth middleware calls `http://oauth2-proxy.auth.svc.cluster.local/` (static `202` upstream)
  for every request on the protected entry point, and copies `X-Auth-Request-User`, `X-Auth-Request-Email` and
  `X-Auth-Request-Preferred-Username` to the upstream request. `strip-auth-headers` removes client-supplied copies first.
- Grafana trusts `X-Auth-Request-Email` (auth proxy mode). Argo CD's route adds the `argocd/descope-token` ForwardAuth
  middleware, which copies oauth2-proxy's `Authorization: Bearer <Descope ID token>` to Argo CD only; Argo CD verifies
  the token against Descope (OIDC, same client), so the Descope session signs the user in, and grants `role:admin` to
  every authenticated user. Its own "Log in via Descope" remains the fallback. Tekton Dashboard, NUI and the Traefik
  dashboard rely on the interceptor alone.
- oauth2-proxy requests `offline_access` and refreshes a session's tokens after 5 minutes (`cookie-refresh`), so the ID
  token it hands to Argo CD stays valid.
- NUI's route adds `nats/strip-cookies`, which removes the `Cookie` header after ForwardAuth: NUI's server (fasthttp)
  refuses request headers over 4 KiB, which oauth2-proxy's session cookies on `.kfirs.com` can exceed.
- Protected backends accept traffic only from the `traefik` namespace (NetworkPolicy); Argo CD's server also admits
  its own namespace and Octomaton, which relays GitHub webhooks to `/api/webhook`.

## Octomaton

| Item | Value |
| --- | --- |
| GitHub App | `octomaton-dev` (created by hand; `Octomaton` is taken on GitHub), homepage `https://github.com/arikkfir-org/octomaton`, installed on all `arikkfir-org` repositories. Octomaton and the rulesets' required check identify it by its App ID, never by name |
| App permissions | Checks: read and write; Contents: read; Metadata: read; Pull requests: read and write; Merge queues: read |
| App events | `push`, `pull_request`, `issue_comment`, `check_suite`, `check_run`, `merge_group`; also `pull_request_review`, `pull_request_review_comment` and `pull_request_review_thread`, which Octomaton ignores |
| Webhook URL | `https://octomaton.dev/github/hooks` |
| Go module | `octomaton.dev`; repository `arikkfir-org/octomaton` |
| Commands | `octomaton`, the server (no arguments); `octomaton-lint [-render] PATH...` validates `.octomaton.yaml` (`go install octomaton.dev/cmd/octomaton-lint@latest`; `-version`) |
| Go import page | `https://octomaton.dev/<path>?go-get=1` returns `<meta name="go-import" content="octomaton.dev git https://github.com/arikkfir-org/octomaton">`; any other request is redirected (302) to the repository |
| Kubernetes | namespace `octomaton`, Deployment/ServiceAccount/Service `octomaton` (Service port 80 → container 8080); Deployment/Service/ConfigMap `go-import` for the import page (Service port 80 → container 8080) |
| Deployment | `deploy/` in `arikkfir-org/octomaton` (Kustomize), applied by the Argo CD Application `octomaton` (defined in `delivery`) from `main`, with the image tagged `${ARGOCD_APP_REVISION_SHORT}`: the synced commit's short SHA ([design](designs/octomaton-deployment.md)) |
| Config | Environment variables only ([server configuration](#server-configuration)): ConfigMap `octomaton` through `envFrom`; `OCTOMATON_POD_NAME` and `OCTOMATON_POD_NAMESPACE` from the downward API; `OTEL_RESOURCE_ATTRIBUTES` with the pod, namespace and container names; `enableServiceLinks: false` |
| GitHub secret | Secret `octomaton-github`: keys `app-id`, `private-key`, `webhook-secret` as `OCTOMATON_GITHUB_APP_ID`, `OCTOMATON_GITHUB_PRIVATE_KEY`, `OCTOMATON_GITHUB_WEBHOOK_SECRET` |
| Endpoints | `POST /github/hooks`, `GET /healthz`, `GET /readyz` (all on 8080) |
| Telemetry | On GKE: JSON logs on stdout to Cloud Logging; metrics to Cloud Monitoring and traces to Cloud Trace through the Telemetry API (`telemetry.googleapis.com`), as `octomaton/octomaton`. Elsewhere: text logs, nothing exported |
| Check links | `https://tekton.dev.kfirs.com/#/namespaces/<namespace>/pipelineruns/<name>` |
| Tenant namespaces | `ci-<repository>` (`.github` → `ci-github`); each has ServiceAccount `pipeline` and RoleBinding `octomaton` → ClusterRole `octomaton-tenant`, plus the [reviewer's objects](#pull-request-reviewer) |
| Tenant permissions | `octomaton-tenant`: PipelineRuns (create, get, list, watch, patch, update, delete); TaskRuns (get, list, watch); Secrets (create, get, patch, update, delete); Pods (get, list); `pods/log` (get); PersistentVolumeClaims (get, list, delete) |

### Server configuration

The server takes no arguments: environment variables configure it, and it exits at startup listing every problem.

| Variable | Default | Meaning |
| --- | --- | --- |
| `OCTOMATON_GITHUB_APP_ID` | required | the GitHub App's ID |
| `OCTOMATON_GITHUB_PRIVATE_KEY` | required | the App's PEM private key (PKCS#1 or PKCS#8) |
| `OCTOMATON_GITHUB_WEBHOOK_SECRET` | required | the App's webhook secret |
| `OCTOMATON_GITHUB_ALLOWED_OWNERS` | every owner | users and organizations whose installations are served, comma-separated |
| `OCTOMATON_TEKTON_DASHBOARD_URL` | none | Tekton Dashboard base URL that check runs link to |
| `OCTOMATON_NAMESPACE_TEMPLATE` | `ci-{{ .Repository.Name }}` | namespace of a repository's runs, rendered then sanitized |
| `OCTOMATON_NAMESPACE_OVERRIDES` | none | `owner/name:namespace` pairs, comma-separated; they win over the template |
| `OCTOMATON_RELAY_URLS` | none | URLs that receive verified `push` and `ping` deliveries, comma-separated |
| `OCTOMATON_RETENTION_FREE_PVCS_AFTER` | `1h` | delay after which the PVCs of finished runs are deleted; runs and pods stay |
| `OCTOMATON_HTTP_ADDRESS` | `:8080` | address of `/github/hooks`, `/healthz` and `/readyz` |
| `OCTOMATON_WEBHOOK_WORKERS`, `OCTOMATON_WEBHOOK_QUEUE_SIZE` | `8`, `256` | webhook worker pool |
| `OCTOMATON_POD_NAME`, `OCTOMATON_POD_NAMESPACE` | host name, service account namespace | holder identity and namespace of the Lease `octomaton` |
| `OCTOMATON_LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error` |
| `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES` | `octomaton` | added to the resource of exported metrics and traces, e.g. `k8s.pod.name=…` |
| `KUBECONFIG` | in-cluster config | used when not running in a cluster |

- `OCTOMATON_NAMESPACE_TEMPLATE` is rendered over `.Repository`, then sanitized: lowercased, leading dots stripped,
  every run of characters outside `[a-z0-9-]` replaced by `-`, leading and trailing `-` trimmed, cut to 63 characters.
  Overrides (`owner/name`, case-insensitive) win. A namespace that does not exist fails the check with "repository not
  onboarded".
- `OCTOMATON_RELAY_URLS` receive the original body and GitHub headers (signatures included), asynchronously, with a
  10 s timeout.

Telemetry follows where the server runs. On GKE (a Kubernetes pod with a GCP metadata server), logs are JSON on stdout
with the fields Cloud Logging reads, including the links to traces, and metrics and traces go to Cloud Monitoring and
Cloud Trace through the Telemetry API (`telemetry.googleapis.com`). They are sent as the pod's Kubernetes
ServiceAccount, which needs `roles/telemetry.metricsWriter`, `roles/telemetry.tracesWriter` and
`roles/serviceusage.serviceUsageConsumer` (the project is the quota project). Anywhere else, logs are text and nothing
is exported.

The hub's ConfigMap `octomaton` sets:

| Variable | Value |
| --- | --- |
| `OCTOMATON_GITHUB_ALLOWED_OWNERS` | `arikkfir-org` |
| `OCTOMATON_TEKTON_DASHBOARD_URL` | `https://tekton.dev.kfirs.com` |
| `OCTOMATON_NAMESPACE_TEMPLATE` | `ci-{{ .Repository.Name }}` |
| `OCTOMATON_NAMESPACE_OVERRIDES` | `arikkfir-org/.github:ci-github` |
| `OCTOMATON_RELAY_URLS` | `http://argocd-server.argocd.svc.cluster.local/api/webhook` (Argo CD refreshes on pushes) |
| `OCTOMATON_RETENTION_FREE_PVCS_AFTER` | `1h` |

### Repository configuration (`.octomaton.yaml`)

The only file Octomaton reads from a repository, always at the root. Octomaton knows nothing else about the
repository. It is parsed as YAML 1.2, so the `on` key needs no quoting.

```yaml
apiVersion: octomaton.dev/v1
pipelines:
  - name: ci                           # identifies the pipeline and its runs; unique; [a-z0-9][a-z0-9-]*
    displayName: Continuous Integration  # optional: the check's name on GitHub (default: name); unique
    pipelineRun: .tekton/ci.yaml       # repository-relative file holding exactly one tekton.dev/v1 PipelineRun
    # pipelineRun:                     # or a file in another repository of the same owner, read at its default branch
    #   repository: tooling
    #   path: reviewer/pipelinerun.yaml
    on:
      pull_request:
        branches: [main]               # base-branch globs; omitted = all
        types: [opened, reopened, synchronize, ready_for_review]  # default
        drafts: true                   # default; false skips draft pull requests
        paths: ["**"]                  # optional globs; no match = check reported as skipped
        pathsIgnore: []                # optional
      merge_group:                     # merge queue; optional base-branch globs
        branches: [main]
      push:
        branches: [main]               # branch globs
        tags: ["v*"]                   # tag globs
        paths: []                      # optional
      comment:                         # pull request comment command, e.g. "/deploy staging"
        pattern: "^/deploy\\b"         # regexp on the comment's first line; commenter needs write access
        branches: [main]               # optional pull request base-branch globs
      review_request:                  # a review is requested from one of these users on a pull request
        reviewers: [arikkfir-reviewer] # GitHub logins, case-insensitive; required
        branches: [main]               # optional pull request base-branch globs
      schedule:                        # cron, 5 fields, UTC; runs at the default branch head
        - cron: "0 3 * * *"
    params:                            # set/override PipelineRun spec.params; values are Go templates
      repo-url: "{{ .Repository.CloneURL }}"
      revision: "{{ .Revision }}"
    githubToken:                       # optional installation token for this repository, refreshed while the run lives
      workspace: github-token          # bound as a Secret workspace (key: token)
      permissions: {contents: read}    # default
    secrets: []                        # optional: Secrets in the run's namespace it may mount; only when every
                                       # trigger reads definitions from the default branch (comment, review_request,
                                       # schedule)
    timeout: 1h                        # optional, sets spec.timeouts.pipeline
    concurrency:                       # optional; default for pull_request and review_request:
                                       # group "pr-<number>", policy supersede
      group: "publish"                 # Go template, scoped to the repository
      policy: latest                   # supersede | queue | latest
    taskChecks: false                  # optional: also report each pipeline task as "<check> / <task>"
```

| Concurrency policy | Behaviour |
| --- | --- |
| `supersede` | The newest commit wins: older live runs in the group are cancelled and their checks concluded `skipped` |
| `queue` (default) | One run at a time, oldest first |
| `latest` | One run at a time; only the newest waiting run survives, older waiting runs are cancelled |

Groups are scoped to the repository: pipelines naming the same group share it (include `{{ .Pipeline }}` to keep them
apart). Without `concurrency`, pull request and review request runs of the same pipeline and pull request supersede each
other; other runs are unconstrained.

Where definitions are read: pull requests, merge groups and pushes read `.octomaton.yaml` and the PipelineRun file
at the commit under test. Comment commands, review requests and schedules read them from the default branch (comment
commands and review requests still run against the pull request's head commit). A `pipelineRun` in another repository
is always read at that repository's default branch.

A review request runs pipelines whose `review_request.reviewers` include the requested user (team requests are
ignored), on open pull requests, drafts included. Each request gets its own run. Requesting a review takes triage or
write access, so the request is the permission check. `review_requested` is not a `pull_request` type, and an invalid
configuration is not reported on review requests: most are for people.

Forks are ignored: every event from a repository that is itself a fork, and every pull request whose head branch lives
in another repository (or in one that no longer exists), whoever opened it. They get no check run and no run; comment
commands on them get no reaction or reply, and reports stored for them are never re-run. Pull requests from the
repository's own branches run automatically.

Template context: `.Event` (`push`, `pull_request`, `merge_group`, `comment`, `review_request`, `schedule`), `.Action`,
`.Repository` (`Owner`, `Name`, `FullName`, `CloneURL`, `HTMLURL`, `DefaultBranch`, `Private`), `.Revision` (SHA under
test), `.Ref`, `.Branch`, `.Tag`, `.Sender`, `.Pipeline`, `.Push` (`Before`, `After`), `.PullRequest` (`Number`,
`HeadRef`, `HeadSHA`, `BaseRef`, `BaseSHA`), `.MergeGroup` (`HeadRef`, `HeadSHA`, `BaseRef`, `BaseSHA`), `.Comment`
(`ID`, `Author`, `Command`, `Arguments`), `.ReviewRequest` (`Reviewer`), `.Schedule` (`Cron`, `Slot`). Event-specific
objects are nil for other events; referencing a missing value fails the check with the rendering error.

Reporting conventions: a pipeline or task result named `check-title` or `check-summary` replaces the check run's title
or Markdown summary.

Secrets: a run may mount the token Octomaton binds and the Secrets its pipeline lists in `secrets`, nothing else. Only a
pipeline whose every trigger reads definitions from the default branch may list any, so definitions at a pull request's
head commit never reach a Secret. Remote Tekton references are refused (`pipelineRef`, `taskRef`, a step's `ref`, any
`resolver` or `bundle`), because Octomaton can only check definitions it can see: a PipelineRun holds its whole
`spec.pipelineSpec`, with a `taskSpec` per task.

## Pull request reviewer

Requesting a review from `arikkfir-reviewer` runs the reviewer on the pull request ([design](designs/pr-reviewer.md)).

| Item | Value |
| --- | --- |
| GitHub user | `arikkfir-reviewer`, a member of `arikkfir-org` |
| Team | `reviewers` (closed): `arikkfir-reviewer`, with `push` on every repository (resolving threads takes write access) |
| Token | Fine-grained personal access token of `arikkfir-reviewer`: resource owner `arikkfir-org`, all repositories, pull requests read and write; expires within a year; Secret Manager `reviewer-github-pat` |
| Model | DeepSeek V4 Pro (`deepseek-v4-pro`), through opencode `1.18.33` (`ghcr.io/anomalyco/opencode`) as `deepseek/deepseek-v4-pro`; key in Secret Manager `reviewer-deepseek-api-key` |
| Definitions | `arikkfir-org/tooling`, `reviewer/`: the PipelineRun `reviewer/pipelinerun.yaml`, its scripts, the prompt and `opencode.json`, all read at `tooling`'s default branch |
| Findings | Each a thread, marked 🔴 blocking (must fix), 🟡 non-blocking (should fix) or 🔵 nit (could fix), with a severity (`low`, `medium`, `high`, `urgent`) and a likelihood (`low`, `medium`, `high`). The review approves when there are none or only nits, and requests changes otherwise |
| Trigger | Pipeline `review`, display name `AI Review`, in every repository's `.octomaton.yaml`: `on.review_request.reviewers: [arikkfir-reviewer]`, `secrets: [reviewer-deepseek-api-key, reviewer-github-pat]`, `githubToken` with contents and pull requests read |
| Tasks | `setup` (clone, state), `review` (opencode, check, fix, recheck), `report`; all as ServiceAccount `reviewer`, all labelled `kfirs.com/sandbox=true` |
| Volume | One per run: 50Gi, `ReadWriteOnce` (`volumeClaimTemplate`), deleted an hour after the run (`OCTOMATON_RETENTION_FREE_PVCS_AFTER`) |
| Files on the volume | `pr.json`, `pr.diff`, `pr.log` (setup), `findings.json` (review), `repos/<repository>/`, `.review/` |
| Markers | A thread's first comment: `<!-- reviewer:<code> -->`. The review body: `<!-- reviewer-run:<PipelineRun> -->` |
| Check | `AI Review` on the reviewed commit; `report` sets its title and summary |

Every `ci-<repository>` namespace has the reviewer's objects (the `ci-tenants` base in `delivery`):

| Object | Spec |
| --- | --- |
| ServiceAccount `reviewer` | `automountServiceAccountToken: false`; no RoleBinding; no IAM role for its principal |
| NetworkPolicy `sandbox` | Pods labelled `kfirs.com/sandbox=true`: no ingress; egress to `0.0.0.0/0` except `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `100.64.0.0/10` and `169.254.0.0/16` (pods, Services, nodes, the metadata server) |
| ExternalSecret `reviewer-deepseek-api-key` | Secret `reviewer-deepseek-api-key`, key `api-key`, from Secret Manager `reviewer-deepseek-api-key` |
| ExternalSecret `reviewer-github-pat` | Secret `reviewer-github-pat`, key `token`, from Secret Manager `reviewer-github-pat` |

Sandboxed pods resolve names through public resolvers (`dnsPolicy: None`, nameservers `8.8.8.8` and `1.1.1.1`),
because cluster DNS is inside the denied ranges.
