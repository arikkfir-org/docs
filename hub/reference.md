# Hub reference

The authoritative list of every name, identifier, address and permission in the development hub. Terraform
(`arikkfir-org/infra`), GitOps manifests (`arikkfir-org/delivery`), Octomatron (`arikkfir-org/octomatron`) and every
repository's CI configuration must agree with this page. Change it here first, then in code.

## Identity and placement

| Item | Value |
| --- | --- |
| GitHub organization | `arikkfir-org` |
| GCP project | `arikkfir` (number `8909046976`, organization `468825984716`) |
| Region / cluster zone | `me-west1` / `me-west1-a` |
| DNS domain | `kfirs.com` (Cloud DNS zone `kfirs-com`): hub tools under `dev.kfirs.com`, sign-in at `auth.kfirs.com`. `kfirfamily.com` (zone `kfirfamily-com`) is imported but unused. |
| Identity provider | Descope company `KFIRS`, project `development` (`P3JyPV2qsSrMLUpVPTGcBNRHlSkv`), issuer `https://api.descope.com/P3JyPV2qsSrMLUpVPTGcBNRHlSkv` |
| Label/annotation prefix | `kfirs.com/` for hub-wide labels, `octomatron.kfirs.com/` for Octomatron bookkeeping |
| Terraform state | GCS bucket `arikkfir-tfstate` (created once by hand, versioned), prefixes `github`, `gcp`, `argocd` |

## Repositories

| Repository | Purpose | Default-branch rules | Required checks |
| --- | --- | --- | --- |
| `.github` | Org profile, org-wide GitHub defaults | PR + 1 approval + merge queue | `ci` |
| `docs` | Knowledge base, published to `arikkfir-docs` and served at `docs.dev.kfirs.com` | Direct pushes to `main` allowed (no deletion, no force-push) | none |
| `infra` | Terraform: GitHub, GCP, Argo CD bootstrap | PR + 1 approval + merge queue | `ci` |
| `delivery` | Argo CD applications (GitOps) | PR + 1 approval + merge queue | `ci` |
| `octomatron` | CI orchestrator (GitHub App + Tekton) | PR + 1 approval + merge queue | `ci` |
| `tooling` | Claude Code web bundle | PR + 1 approval + merge queue | `ci` |

Merge method is squash only, via the merge queue. Organization admins may bypass rules on pull requests only
(`bypass_mode = pull_request`) so a solo maintainer can merge without a second reviewer; nobody may push directly to a
protected default branch. Required checks are pinned to the Octomatron GitHub App (`integration_id`).

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
| Cluster | `hub`, zonal `me-west1-a`, release channel `REGULAR`, Dataplane V2 |
| Workload Identity pool | `arikkfir.svc.id.goog` |
| Nodes | private (no external IPs), egress through Cloud NAT |
| Control plane access | DNS-based endpoint (IAM-authenticated); no external IP endpoint |
| Gateway API | GKE-managed Gateway API disabled; CRDs and Traefik installed by Argo CD |
| Add-ons | HTTP load balancing (Traefik's load balancers); Cloud Storage FUSE CSI driver (docs site) |
| Node service account | `gke-hub-nodes@arikkfir.iam.gserviceaccount.com` |
| Node pool `system` | `e2-standard-4`, on-demand, `me-west1-a`, autoscaling 1-3, label `kfirs.com/pool=system` |
| Node pool `ci` | `e2-standard-4`, Spot, `me-west1-a/b/c`, autoscaling 0-4, label `kfirs.com/pool=ci`, taint `kfirs.com/pool=ci:NoSchedule` |

Tekton runs land on the `ci` pool through Tekton's default pod template (node selector plus toleration).

## Artifact Registry and buckets

| Resource | Name | Access |
| --- | --- | --- |
| Docker repository | `me-west1-docker.pkg.dev/arikkfir/images` | nodes read; `ci-octomatron/pipeline` writes |
| Bucket | `arikkfir-docs` (`ME-WEST1`, uniform access, public access prevention enforced) | private: `docs/docs` reads and serves it at `https://docs.dev.kfirs.com`; `ci-docs/pipeline` writes |
| Bucket | `arikkfir-claude` (`ME-WEST1`, uniform access) | public object reads (no listing); `ci-tooling/pipeline` writes |

Public URLs (`arikkfir-claude` only) are `https://storage.googleapis.com/<bucket>/<path>`.

## Secret Manager

Terraform creates the secret containers; values are added by hand (`gcloud secrets versions add`). External Secrets
Operator is the only reader.

| Secret | Content | Consumed by |
| --- | --- | --- |
| `octomatron-github-app-id` | GitHub App ID (number) | `octomatron/octomatron-github` key `app-id` |
| `octomatron-github-private-key` | GitHub App private key (PEM) | `octomatron/octomatron-github` key `private-key` |
| `octomatron-github-webhook-secret` | GitHub App webhook secret | `octomatron/octomatron-github` key `webhook-secret` |
| `oidc-client-secret` | Descope access key (OIDC client secret) | `auth/oauth2-proxy` key `client-secret`; `argocd/argocd-oidc` key `clientSecret` |
| `oauth2-proxy-cookie-secret` | 32 random bytes, base64 | `auth/oauth2-proxy` key `cookie-secret` |
| `hub-authorized-emails` | Newline-separated emails allowed through the auth interceptor | `auth/oauth2-proxy-emails` key `emails` |

## GCP identities and permissions

Kubernetes workloads use GKE Workload Identity Federation with direct principal bindings (no Google service accounts):
`principal://iam.googleapis.com/projects/8909046976/locations/global/workloadIdentityPools/arikkfir.svc.id.goog/subject/ns/<namespace>/sa/<service-account>`.

| Principal (namespace/KSA) | Role | Scope |
| --- | --- | --- |
| `external-secrets/external-secrets` | `roles/secretmanager.secretAccessor` | each secret above |
| `cert-manager/cert-manager` | `roles/dns.admin` | managed zone `kfirs-com` |
| `grafana/grafana` | `roles/monitoring.viewer` | project |
| `docs/docs` | `roles/storage.objectViewer` | bucket `arikkfir-docs` |
| `ci-docs/pipeline` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-tooling/pipeline` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-claude` |
| `ci-octomatron/pipeline` | `roles/artifactregistry.writer` | repository `images` |
| `gke-hub-nodes@` (GSA) | `roles/container.defaultNodeServiceAccount` | project |
| `gke-hub-nodes@` (GSA) | `roles/artifactregistry.reader` | repository `images` |

There is no Workload Identity Federation pool for workloads outside GCP: no GitHub Actions run, and CI runs in the
cluster. The pre-existing `github-actions`, `greenstar` and `arikkfir.svc.id.goog` pools belong to other projects or
to GKE and are not managed here.

## Kubernetes platform

| Namespace | Component | Source | Version |
| --- | --- | --- | --- |
| `argocd` | Argo CD (self-managed after bootstrap) | `https://argoproj.github.io/argo-helm` `argo-cd` | `10.9.2` (Argo CD v3.5.3) |
| `cert-manager` | cert-manager | `https://charts.jetstack.io` `cert-manager` | `v1.21.2` |
| `external-secrets` | External Secrets Operator | `https://charts.external-secrets.io` `external-secrets` | `2.11.0` |
| `keda` | KEDA | `https://kedacore.github.io/charts` `keda` | `2.21.0` |
| `nats` | NATS (JetStream) | `https://nats-io.github.io/k8s/helm/charts` `nats` | `2.15.0` |
| `nats` | NACK (JetStream controller) | same repo, `nack` | `0.35.0` |
| `nats` | NUI | `https://nats-nui.github.io/k8s/helm/charts` `nui` | `0.1.6` (image tag pinned) |
| `reloader` | Stakater Reloader | `https://stakater.github.io/stakater-charts` `reloader` | `2.2.17` |
| `traefik` | Gateway API CRDs (standard channel) | `kubernetes-sigs/gateway-api` release | `v1.6.1` |
| `traefik` | Traefik | `https://traefik.github.io/charts` `traefik` | `41.6.0` (Traefik v3.7) |
| `auth` | oauth2-proxy (auth interceptor) | `https://oauth2-proxy.github.io/manifests` `oauth2-proxy` | `10.7.0` |
| `grafana` | Grafana | `https://grafana-community.github.io/helm-charts` `grafana` | `13.2.6` |
| `tekton-operator` | Tekton Operator | `tektoncd/operator` release manifest | `v0.77.0` |
| `tekton-pipelines` | Pipelines, Triggers, Dashboard (via `TektonConfig`) | operator-managed | operator default |
| `octomatron` | Octomatron | `me-west1-docker.pkg.dev/arikkfir/images/octomatron` | `v0.1.0` |
| `docs` | Docs site: nginx serving `arikkfir-docs` (Cloud Storage FUSE mount) | `docker.io/nginxinc/nginx-unprivileged` | `1.30.5-alpine` |
| `ci-<repo>` | CI tenants (one per repository) | `delivery` | n/a |

## Ingress

Traefik runs once with two entry-point pairs, each exposed by its own L4 (passthrough network) load balancer: a
`LoadBalancer` Service with `loadBalancerClass: networking.gke.io/l4-regional-external` that binds the reserved IP by
name (annotation `networking.gke.io/load-balancer-ip-addresses`), which needs GKE 1.33.1+ and the HTTP load-balancing
add-on:

| Gateway | Entry points (container → exposed) | Load balancer IP | Interceptor | Who may attach routes |
| --- | --- | --- | --- | --- |
| `traefik/protected` | `web` 8000→80 (redirect), `websecure` 8443→443 | `ingress-protected` | Entry-point middlewares `strip-auth-headers` + `oidc` on `websecure`, applied to every route | any namespace |
| `traefik/public` | `public-web` 9080→80 (redirect), `public-websecure` 9443→443 | `ingress-public` | `strip-auth-headers` only | namespaces labelled `kfirs.com/public-ingress=true` |

Every listener serves the wildcard certificate for `*.kfirs.com` and `*.dev.kfirs.com` (cert-manager, Let's Encrypt,
DNS-01 through Cloud DNS), stored in secret `traefik/wildcard-kfirs-com-tls`.

| Host | Gateway | Backend |
| --- | --- | --- |
| `argocd.dev.kfirs.com` | protected | `argocd/argocd-server:80` |
| `tekton.dev.kfirs.com` | protected | `tekton-pipelines/tekton-dashboard:9097` |
| `grafana.dev.kfirs.com` | protected | `grafana/grafana:80` |
| `traefik.dev.kfirs.com` | protected | Traefik dashboard (`api@internal`, IngressRoute) |
| `nui.dev.kfirs.com` | protected | `nats/nui` |
| `docs.dev.kfirs.com` | protected | `docs/docs:80` |
| `auth.kfirs.com` | public | `auth/oauth2-proxy:80`, path `/oauth2` |
| `octomatron.dev.kfirs.com` | public | `octomatron/octomatron:80`, path `/github/hooks` |

DNS A records (TTL 300) in zone `kfirs-com` point each host at its gateway's IP.

## Authentication

- Descope authenticates users with Google social login through a sign-in-only flow; only users pre-created in Descope
  can complete it.
- oauth2-proxy (`auth` namespace) is the OIDC client (`client_id` = Descope project ID, `client_secret` = Descope access
  key), keeps a session cookie on `.kfirs.com`, and additionally requires the user's email to be listed in
  `hub-authorized-emails`.
- Traefik's `oidc` ForwardAuth middleware calls `http://oauth2-proxy.auth.svc.cluster.local/` (static `202` upstream)
  for every request on the protected entry point, and copies `X-Auth-Request-User`, `X-Auth-Request-Email` and
  `X-Auth-Request-Preferred-Username` to the upstream request. `strip-auth-headers` removes client-supplied copies first.
- Grafana trusts `X-Auth-Request-Email` (auth proxy mode). Argo CD also logs users in through Descope (OIDC, same
  client) and grants `role:admin` to every authenticated user; Tekton Dashboard, NUI and the Traefik dashboard rely on
  the interceptor alone.
- Protected backends accept traffic only from the `traefik` namespace (NetworkPolicy); Argo CD's server also admits
  its own namespace and Octomatron, which relays GitHub webhooks to `/api/webhook`.
- oauth2-proxy sets `emailDomains: []`: any domain rule would be OR-ed with the allowlist and bypass it.

## Octomatron

| Item | Value |
| --- | --- |
| GitHub App | `octomatron` (created by hand), installed on all `arikkfir-org` repositories |
| App permissions | Checks: read and write; Contents: read; Metadata: read; Pull requests: read and write; Merge queues: read |
| App events | `push`, `pull_request`, `issue_comment`, `check_suite`, `check_run`, `merge_group` |
| Webhook URL | `https://octomatron.dev.kfirs.com/github/hooks` |
| Kubernetes | namespace `octomatron`, Deployment/ServiceAccount/Service `octomatron` (Service port 80 → container 8080) |
| Config | ConfigMap `octomatron` key `config.yaml` mounted at `/etc/octomatron/config.yaml` |
| GitHub secret | Secret `octomatron-github` (keys `app-id`, `private-key`, `webhook-secret`) mounted at `/etc/octomatron/github/` |
| Endpoints | `POST /github/hooks`, `GET /healthz`, `GET /readyz`, `GET /metrics` (all on 8080) |
| Check links | `https://tekton.dev.kfirs.com/#/namespaces/<namespace>/pipelineruns/<name>` |
| Tenant namespaces | `ci-<repository>` (`.github` → `ci-github`); each has ServiceAccount `pipeline` and RoleBinding `octomatron` → ClusterRole `octomatron-tenant` |
| Tenant permissions | `octomatron-tenant`: PipelineRuns (create, get, list, watch, patch, update, delete); TaskRuns (get, list, watch); Secrets (create, get, patch, update, delete); Pods (get, list); `pods/log` (get); PersistentVolumeClaims (get, list, delete) |

### Server configuration (`/etc/octomatron/config.yaml`)

```yaml
github:
  appIDFile: /etc/octomatron/github/app-id
  privateKeyFile: /etc/octomatron/github/private-key
  webhookSecretFile: /etc/octomatron/github/webhook-secret
  allowedOwners: [arikkfir-org]        # installations on other owners are ignored
tekton:
  dashboardURL: https://tekton.dev.kfirs.com
namespaces:
  template: "ci-{{ .Repository.Name }}" # rendered, then sanitized to a DNS label
  overrides:
    arikkfir-org/.github: ci-github
relay:                                  # verified push and pull_request deliveries are forwarded here
  urls: [http://argocd-server.argocd.svc.cluster.local/api/webhook]
retention:
  freePVCsAfter: 1h                     # PVCs of finished runs are deleted after this; runs and pods stay
```

### Repository configuration (`.octomatron.yaml`)

The only file Octomatron reads from a repository, always at the root. Octomatron knows nothing else about the
repository. It is parsed as YAML 1.2, so the `on` key needs no quoting.

```yaml
apiVersion: octomatron.kfirs.com/v1
pipelines:
  - name: ci                           # check-run name; unique; [a-z0-9][a-z0-9-]*
    pipelineRun: .tekton/ci.yaml       # repository-relative file holding exactly one tekton.dev/v1 PipelineRun
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
      schedule:                        # cron, 5 fields, UTC; runs at the default branch head
        - cron: "0 3 * * *"
    params:                            # set/override PipelineRun spec.params; values are Go templates
      repo-url: "{{ .Repository.CloneURL }}"
      revision: "{{ .Revision }}"
    githubToken:                       # optional installation token for this repository, refreshed while the run lives
      workspace: github-token          # bound as a Secret workspace (key: token)
      permissions: {contents: read}    # default
    timeout: 1h                        # optional, sets spec.timeouts.pipeline
    concurrency:                       # optional; default for pull_request: group "pr-<number>", policy supersede
      group: "publish"                 # Go template, scoped to the repository
      policy: latest                   # supersede | queue | latest
    taskChecks: false                  # optional: also report each pipeline task as "<name> / <task>"
```

| Concurrency policy | Behaviour |
| --- | --- |
| `supersede` | The newest commit wins: older live runs in the group are cancelled and their checks concluded `skipped` |
| `queue` (default) | One run at a time, oldest first |
| `latest` | One run at a time; only the newest waiting run survives, older waiting runs are cancelled |

Groups are scoped to the repository: pipelines naming the same group share it (include `{{ .Pipeline }}` to keep them
apart). Without `concurrency`, pull request runs of the same pipeline and pull request supersede each other; other runs
are unconstrained.

Where definitions are read: pull requests, merge groups and pushes read `.octomatron.yaml` and the PipelineRun file
at the commit under test; comment commands and schedules read them from the default branch (and comment commands still
run against the pull request's head commit).

Template context: `.Event` (`push`, `pull_request`, `merge_group`, `comment`, `schedule`), `.Action`, `.Repository`
(`Owner`, `Name`, `FullName`, `CloneURL`, `HTMLURL`, `DefaultBranch`, `Private`), `.Revision` (SHA under test), `.Ref`,
`.Branch`, `.Tag`, `.Sender`, `.Pipeline`, `.Push` (`Before`, `After`), `.PullRequest` (`Number`, `HeadRef`,
`HeadSHA`, `BaseRef`, `BaseSHA`), `.MergeGroup` (`HeadRef`, `HeadSHA`, `BaseRef`, `BaseSHA`), `.Comment` (`ID`,
`Author`, `Command`, `Arguments`), `.Schedule` (`Cron`, `Slot`). Event-specific objects are nil for other events;
referencing a missing value fails the check with the rendering error.

Reporting conventions: a pipeline or task result named `check-title` or `check-summary` replaces the check run's title
or Markdown summary. Runs may mount no Secret other than the token Octomatron binds.
