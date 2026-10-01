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
| Label/annotation prefix | `kfirs.com/` for hub-wide labels, `octomaton.dev/` for Octomaton bookkeeping and the [ServiceAccount branch restriction](#serviceaccount-branches) |
| Terraform state | GCS bucket `arikkfir-devops` (created by hand, versioned), prefixes `github`, `gcp`, `argocd` |

## Repositories

| Repository | Purpose | Default-branch rules | Required checks |
| --- | --- | --- | --- |
| `.github` | The organization's welcome page on GitHub: `profile/README.md`, nothing else | PR + 1 approval + merge queue | `Continuous Integration` (none runs: merged with the admin bypass) |
| `docs` | Hub-wide knowledge base; with every repository's `docs/`, served at `docs.dev.kfirs.com` ([docs site](#docs-site)) | PR + 1 approval + merge queue | `Continuous Integration` |
| `infra` | Terraform: GitHub, GCP, Argo CD bootstrap; [plans and applies](#terraform-applies) `gcp` and `github` | PR + 1 approval + merge queue of one | `Continuous Integration` (fmt, validate, plans) |
| `delivery` | Argo CD applications (GitOps) | PR + 1 approval + merge queue | `Continuous Integration` |
| `octomaton` | CI orchestrator (GitHub App + Tekton) | PR + 1 approval + merge queue | `Continuous Integration` |
| `tooling` | Org-wide tooling: the Claude Code web bundle, the [pull request reviewer](#pull-request-reviewer), and the organization pipelines every repository runs (`.octomaton.yaml`) | PR + 1 approval + merge queue | `Continuous Integration` |
| `fin` | Personal finance manager and assistant. Internal: visible only to members of the organization's enterprise | PR + 1 approval + merge queue | `Continuous Integration` (none runs until `fin` has a `ci` pipeline: until then, merged with the admin bypass) |

Every repository gets the same settings and the same `Default branch` ruleset. `terraform/github` in `infra` applies
all but the last two rows:

| Item | Value |
| --- | --- |
| Visibility | Public, except `fin` (internal) |
| Forking | Public repositories only: the organization forbids forking private and internal ones, so `fin` can't be forked |
| Features | Discussions on; issues, wiki and projects off |
| Merging | Merge commits, squash and rebase allowed (the ruleset narrows pull requests to merge commits); default commit message: the pull request's title and description; always suggest updating branches; auto-merge on; head branches deleted after merge |
| Autolink | `ENG-<num>` (alphanumeric) links to `https://linear.app/arikkfir/issue/ENG-<num>` |
| Ruleset `Default branch` | Targets the default branch. No deletion, no force-push. Pull request: one approval, stale approvals dismissed, last push approved by someone else, conversations resolved, merge commits only. Required checks: `Continuous Integration` and `Docs` from the Octomaton App only (`integration_id`), plus any the repository adds (`checks` in `local.repositories`), from any source. Merge queue: merge commits, at most 5 entries building, 1 to 5 pull requests per group, a 3-minute wait for the minimum, every entry passing the required checks (`ALLGREEN`), 60-minute check timeout; in `infra`, one entry building and groups of exactly one, so each merge is planned alone. Off: restricted creations and updates, linear history, deployments, signed commits, code owner and team reviews, up-to-date branches, skipping checks on creation |
| Ruleset bypass | Organization admins and repository admins, always |
| Dependabot | Alerts and security updates on; version updates would need a `.github/dependabot.yml` in the repository |
| Set by hand | Sponsorships on and Preserve this repository (GitHub Archive Program) off, in each repository's settings: the provider has no argument for them |
| GitHub's defaults | Outside Terraform, as GitHub sets them: pull requests open to all users, comments on individual commits allowed, review dismissal unrestricted, an additional approval for unattributed Copilot pull requests |

An approval by `arikkfir-reviewer`, the [pull request reviewer](#pull-request-reviewer), counts: it has `push` on every
repository. `Continuous Integration` is each repository's `ci` pipeline under its `displayName`; the ruleset pins it to
the Octomaton App's ID, so a check of that name from any other App counts for nothing. `.github` has no CI (Claude
Code can't clone a repository whose name starts with a dot, so nothing else lives there), and an admin merges its rare
pull requests with the bypass.

## Organization

From arikkfir-org/infra#19 on, `terraform/github` also manages the `arikkfir-org` organization's settings:

| Setting | Value |
| --- | --- |
| Name | `arikkfir-org` |
| Description | A personal development hub: the home of personal projects, and of the platform they are built and run on. |
| Billing email | The owner's address |
| Projects | Off, for the organization and for its repositories |
| Base permission | Read |
| Repository creation by members | Off (public, private and internal): `terraform/github` creates repositories |
| Pages sites by members | Off |
| Forking private and internal repositories | Off: `members_can_fork_private_repositories`, which GitHub applies to internal repositories too (it refused `fin`'s `allow_forking` with "This organization does not allow private repository forking"). Each repository's `allow_forking` is public-only as well (see Repositories) |
| Web commit sign-off | Not required |
| Set by hand | The rest of the profile: links, company, location, public email |
| Left as they are | Security defaults for new repositories: GitHub replaced them with code security configurations, and `terraform/github` turns on Dependabot alerts and security updates per repository |

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
| Node pool `ci` | `e2-standard-4`, on-demand from arikkfir-org/infra#20 on (Spot before it: preemptions failed most runs on 2026-10-01), `me-west1-a` (the cluster's zone) from arikkfir-org/infra#21 on (`me-west1-a/b/c` before it: a run's zonal disk mounts only on nodes in its own zone), autoscaling 0-4, label `kfirs.com/pool=ci`, taint `kfirs.com/pool=ci:NoSchedule` |

Tekton runs land on the `ci` pool through Tekton's default pod template (node selector plus toleration).

## Artifact Registry and buckets

| Resource | Name | Access |
| --- | --- | --- |
| Docker repository | `me-west1-docker.pkg.dev/arikkfir/images` | nodes read; `ci-octomaton/pipeline` writes |
| Bucket | `arikkfir-docs` (`ME-WEST1`, uniform access, public access prevention enforced) | private, one layer per repository under `.layers/<repository>/` ([docs site](#docs-site)): `docs/docs` reads and serves it at `https://docs.dev.kfirs.com`; each tenant's `docs-publisher` writes its own layer, and `docs-reader` lists names |
| Bucket | `arikkfir-claude` (`ME-WEST1`, uniform access) | public object reads (no listing); `ci-tooling/pipeline` writes |

Public URLs (`arikkfir-claude` only) are `https://storage.googleapis.com/<bucket>/<path>`.

## Secret Manager

Terraform creates the secret containers; values are added by hand (`gcloud secrets versions add`). External Secrets
Operator reads all but `infra`'s two GitHub tokens, which only `infra`'s pipelines read, so no Kubernetes Secret ever
holds them.

| Secret | Content | Consumed by |
| --- | --- | --- |
| `octomaton-github-app-id` | GitHub App ID (number) | `octomaton/octomaton-github` key `app-id` |
| `octomaton-github-private-key` | GitHub App private key (PEM) | `octomaton/octomaton-github` key `private-key` |
| `octomaton-github-webhook-secret` | GitHub App webhook secret | `octomaton/octomaton-github` key `webhook-secret` |
| `oidc-client-secret` | Descope access key (OIDC client secret) | `auth/oauth2-proxy` key `client-secret`; `argocd/argocd-oidc` key `clientSecret` |
| `oauth2-proxy-cookie-secret` | 32 random bytes, base64 | `auth/oauth2-proxy` key `cookie-secret` |
| `grafana-postgres-admin-password` | Password of the superuser `postgres` on Grafana's PostgreSQL, which people sign in with | `grafana/postgres-admin` key `password` |
| `reviewer-deepseek-api-key` | DeepSeek API key | `ci-*/reviewer-deepseek-api-key` key `api-key` (the [reviewer](#pull-request-reviewer)'s `review` task) |
| `reviewer-github-pat` | `arikkfir-reviewer`'s fine-grained personal access token | `ci-*/reviewer-github-pat` key `token` (the [reviewer](#pull-request-reviewer)'s `report` task) |
| `infra-plan-github-pat` | Fine-grained personal access token that reads the organization's repositories and settings and writes contents (see [Terraform applies](#terraform-applies)) | `ci-infra/ci-infra-plan`, read at run time by `infra`'s `ci` pipeline |
| `infra-apply-github-pat` | Fine-grained personal access token that administers the organization's repositories and settings (see [Terraform applies](#terraform-applies)) | `ci-infra/ci-infra-apply`, read at run time by `infra`'s `apply` pipeline |

## GCP identities and permissions

Kubernetes workloads use GKE Workload Identity Federation with direct principal bindings (no Google service accounts):
`principal://iam.googleapis.com/projects/8909046976/locations/global/workloadIdentityPools/arikkfir.svc.id.goog/subject/ns/<namespace>/sa/<service-account>`.

| Principal (namespace/KSA) | Role | Scope |
| --- | --- | --- |
| `external-secrets/external-secrets` | `roles/secretmanager.secretAccessor` | each secret above but `infra-plan-github-pat` and `infra-apply-github-pat` |
| `cert-manager/cert-manager` | `roles/dns.admin` | managed zones `kfirs-com` and `octomaton-dev` |
| `grafana/grafana` | `roles/monitoring.viewer` | project |
| `octomaton/octomaton` | `roles/telemetry.metricsWriter`, `roles/telemetry.tracesWriter`, `roles/serviceusage.serviceUsageConsumer` | project |
| `docs/docs` | `roles/storage.objectViewer` | bucket `arikkfir-docs` |
| `ci-<repository>/docs-publisher` | `roles/storage.objectUser` on objects under `.layers/<repository>/` (IAM condition), `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-<repository>/docs-reader` | `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-tooling/pipeline` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-claude` |
| `ci-octomaton/pipeline` | `roles/artifactregistry.writer` | repository `images` |
| `ci-infra/ci-infra-plan` | `roles/iam.securityReviewer`, `roles/serviceusage.serviceUsageViewer`, `roles/compute.networkViewer`, `roles/container.clusterViewer`, `roles/artifactregistry.reader`, `roles/secretmanager.viewer`, `roles/dns.reader`, `roles/iam.serviceAccountViewer` | project |
| `ci-infra/ci-infra-plan` | `roles/storage.legacyBucketReader` | each bucket `terraform/gcp` manages |
| `ci-infra/ci-infra-plan` | `roles/storage.objectViewer` | bucket `arikkfir-devops` |
| `ci-infra/ci-infra-plan` | `roles/secretmanager.secretAccessor` | secret `infra-plan-github-pat` |
| `ci-infra/ci-infra-apply` | `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`, `roles/container.admin`, `roles/artifactregistry.admin`, `roles/storage.admin`, `roles/secretmanager.admin`, `roles/dns.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.securityAdmin` | project |
| `ci-infra/ci-infra-apply` | `roles/iam.serviceAccountUser` | service account `gke-hub-nodes@` |
| `gke-hub-nodes@` (GSA) | `roles/container.defaultNodeServiceAccount` | project |
| `gke-hub-nodes@` (GSA) | `roles/artifactregistry.reader` | repository `images` |

There is no Workload Identity Federation pool for workloads outside GCP: no GitHub Actions run, and CI runs in the
cluster. The pre-existing `github-actions`, `greenstar` and `arikkfir.svc.id.goog` pools belong to other projects or
to GKE and are not managed here.

## Terraform applies

`infra` plans and applies through Octomaton ([design](designs/terraform-plan-apply.md)):

| Item | Value |
| --- | --- |
| Pull requests and merge queue | Pipeline `ci` (`Continuous Integration`) as `ci-infra/ci-infra-plan`: `fmt`, `validate` in every root, `plan -lock=false` in `gcp` and `github` |
| Merge to `main` | Pipeline `apply` (`Apply`) as `ci-infra/ci-infra-apply`: plans `gcp` and `github`; stops if either plan deletes or replaces anything; otherwise applies both, `gcp` first |
| Concurrency | The merge queue's `ci` runs and `apply` share the group `terraform` (policy `queue`) |
| By hand (`make terraform <root>`) | `argocd` (bootstrap only), applies the pipeline stopped, and the first apply of new roles or tokens |
| `infra-plan-github-pat` | Fine-grained, resource owner `arikkfir-org`, all repositories: repository Administration and Metadata read, Contents read and write; organization Administration and Members read |
| `infra-apply-github-pat` | Fine-grained, resource owner `arikkfir-org`, all repositories: repository Administration and Contents read and write, Metadata read; organization Administration and Members read and write |

Both tokens have Contents read and write because GitHub shows a repository's merge settings only to tokens with it
([design](designs/terraform-plan-apply.md#github-tokens)). The owner creates both tokens, adds them with
`gcloud secrets versions add` and renews them within a year.

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
| `grafana` | PostgreSQL for Grafana: StatefulSet `postgres`, one replica, a 10Gi volume | `docker.io/library/postgres` | `18.6-trixie` |
| `tekton-operator` | Tekton Operator | `tektoncd/operator` release manifest from `infra.tekton.dev` (Tekton's release host since v0.78) | `v0.81.1` |
| `tekton-pipelines` | Pipelines, Triggers, Dashboard (via `TektonConfig`; Results, Chains, Pipelines-as-Code and the operator's NetworkPolicies off) | operator-managed | operator default |
| `octomaton` | Octomaton | `me-west1-docker.pkg.dev/arikkfir/images/octomaton` | The short SHA of the `main` commit Argo CD deploys (`${ARGOCD_APP_REVISION_SHORT}`, see [Octomaton](#octomaton)). There are no version tags; every push to `main` publishes one, which is also the version the binary and its telemetry report |
| `octomaton` | `go-import`: Caddy answering for `octomaton.dev` | `docker.io/library/caddy` | `2.11.4-alpine` |
| `docs` | Docs site: Caddy overlaying the layers of `arikkfir-docs` (Cloud Storage FUSE mount) and rendering Markdown ([docs site](#docs-site)) | `docker.io/library/caddy` | `2.11.4-alpine` |
| `ci-<repo>` | CI tenants (one per repository) | `delivery` | n/a |

NATS clients, NACK included, connect to `nats://nats.nats.svc.cluster.local:4222`. JetStream streams may keep up to
three replicas. The servers spread across system-pool nodes when there are several, but don't make the pool grow.

Availability ([design](designs/disruption-budgets.md)): Traefik, oauth2-proxy, the docs site, Grafana, Octomaton,
`go-import` and KEDA's operator, metrics server and webhooks run two replicas each. NATS runs three servers. Each has a
PodDisruptionBudget of `maxUnavailable: 1` and spreads its pods over nodes when the pool has several
(`whenUnsatisfiable: ScheduleAnyway`). Grafana keeps its state in database `grafana` on StatefulSet `postgres` in its
namespace, at `postgres.grafana.svc.cluster.local:5432` without TLS, and NetworkPolicy `postgres` admits only Grafana's
pods. Role `grafana`'s password is generated in the cluster: an ESO `Password` generator with
`refreshPolicy: CreatedOnce` creates Secret `grafana/grafana-db`. People sign in as the superuser `postgres` through
`kubectl port-forward -n grafana svc/postgres 5432`, with the password from Secret Manager
`grafana-postgres-admin-password`. Every TCP connection needs a password; only the local socket is trusted. PostgreSQL
runs one replica without a budget. Grafana's replicas share alert state through Service `grafana-headless` on port 9094.

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
| GitHub App | `octomaton-dev`, App ID `5114814` (created by hand; `Octomaton` is taken on GitHub), homepage `https://github.com/arikkfir-org/octomaton`, installed on all `arikkfir-org` repositories. Octomaton and the rulesets' required check identify it by its App ID, never by name |
| App permissions | Checks: read and write; Contents: read; Metadata: read; Pull requests: read and write; Merge queues: read |
| App events | `push`, `pull_request`, `issue_comment`, `check_suite`, `check_run`, `merge_group`; also `pull_request_review`, `pull_request_review_comment` and `pull_request_review_thread`, which Octomaton ignores |
| Webhook URL | `https://octomaton.dev/github/hooks` |
| Go module | `octomaton.dev`; repository `arikkfir-org/octomaton` |
| Commands | `octomaton`, the server (no arguments); `octomaton-lint [-render] PATH...` validates `.octomaton.yaml` (`go install octomaton.dev/cmd/octomaton-lint@latest`; `-version`) |
| Go import page | `https://octomaton.dev/<path>?go-get=1` returns `<meta name="go-import" content="octomaton.dev git https://github.com/arikkfir-org/octomaton">`; any other request is redirected (302) to the repository |
| Kubernetes | namespace `octomaton`, Deployment/ServiceAccount/Service `octomaton` (Service port 80 → container 8080); Deployment/Service/ConfigMap `go-import` for the import page (Service port 80 → container 8080); two replicas of each Deployment, with PodDisruptionBudgets `octomaton` and `go-import` (`maxUnavailable: 1`) |
| Deployment | `deploy/` in `arikkfir-org/octomaton` (Kustomize), applied by the Argo CD Application `octomaton` (defined in `delivery`) from `main`, with the image tagged `${ARGOCD_APP_REVISION_SHORT}`: the synced commit's short SHA ([design](designs/octomaton-deployment.md)) |
| Config | Environment variables only ([server configuration](#server-configuration)): ConfigMap `octomaton` through `envFrom`; `OCTOMATON_POD_NAME` and `OCTOMATON_POD_NAMESPACE` from the downward API; `OTEL_RESOURCE_ATTRIBUTES` with the pod, namespace and container names; `enableServiceLinks: false` |
| GitHub secret | Secret `octomaton-github`: keys `app-id`, `private-key`, `webhook-secret` as `OCTOMATON_GITHUB_APP_ID`, `OCTOMATON_GITHUB_PRIVATE_KEY`, `OCTOMATON_GITHUB_WEBHOOK_SECRET` |
| Endpoints | `POST /github/hooks`, `GET /healthz`, `GET /readyz` (all on 8080) |
| Telemetry | On GKE: JSON logs on stdout to Cloud Logging; metrics to Cloud Monitoring and traces to Cloud Trace through the Telemetry API (`telemetry.googleapis.com`), as `octomaton/octomaton`. Elsewhere: text logs, nothing exported |
| Check links | `https://tekton.dev.kfirs.com/#/namespaces/<namespace>/pipelineruns/<name>` |
| Tenant namespaces | `ci-<repository>` for every repository but `.github`, which has no CI; each has ServiceAccounts `pipeline`, `docs-reader` and `docs-publisher` (annotated `octomaton.dev/branches: main`, see [docs site](#docs-site)) and RoleBinding `octomaton` → ClusterRole `octomaton-tenant`, plus the [reviewer's objects](#pull-request-reviewer). `ci-infra` also has ServiceAccounts `ci-infra-plan` and `ci-infra-apply` (annotated `octomaton.dev/branches: main`) |
| Tenant permissions | `octomaton-tenant`: PipelineRuns (create, get, list, watch, patch, update, delete); TaskRuns (get, list, watch); Secrets (create, get, patch, update, delete); Pods (get, list); `pods/log` (get); PersistentVolumeClaims (get, list, delete); ServiceAccounts (get) |

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
| `OCTOMATON_ORGANIZATION_REPOSITORY` | none | the repository, in each owner, whose `.octomaton.yaml` may declare organization pipelines; none disables them |
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
| `OCTOMATON_ORGANIZATION_REPOSITORY` | `tooling` |
| `OCTOMATON_RELAY_URLS` | `http://argocd-server.argocd.svc.cluster.local/api/webhook` (Argo CD refreshes on pushes) |
| `OCTOMATON_RETENTION_FREE_PVCS_AFTER` | `1h` |

### Repository configuration (`.octomaton.yaml`)

The only file Octomaton reads from a repository, always at the root. Octomaton knows nothing else about the
repository. It is parsed as YAML 1.2, so the `on` key needs no quoting. The organization repository's copy may also
declare organization pipelines, which every repository of the owner runs (below).

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
organization:                          # only in the organization repository: pipelines for every repository
  pipelines: []                        # same fields as pipelines; read at its default branch
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

Organization pipelines: the organization repository, which `OCTOMATON_ORGANIZATION_REPOSITORY` names (`tooling` in
the hub), may declare `organization.pipelines` in each owner, with the same fields as `pipelines`. Octomaton adds them
to the pipelines of every repository of that owner, the organization repository included, and always reads them at the
organization repository's default branch, even for its own pull requests. A plain `pipelineRun` path in them names a
file of the organization repository. Their runs belong to the repository: its namespace, checks, template context and
token. A repository pipeline with the name or check name of an organization pipeline is a configuration error of that
repository, so no repository can replace one. Organization pipelines can't use `schedule`, and `secrets` follows the
same rule as for any pipeline. `organization` in any other repository, or when the setting is unset, is a
configuration error. Without the setting, the file or the section, there are no organization pipelines. A repository
without its own `.octomaton.yaml` still runs them, and an unreadable or invalid organization repository configuration
stops every pipeline of the repository, reported on the `octomaton` check.

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

#### ServiceAccount branches

A ServiceAccount in a tenant namespace may carry the annotation `octomaton.dev/branches`: comma-separated branch globs,
as in `on.push.branches`. Before creating a run, Octomaton gets each ServiceAccount its PipelineRun names
(`spec.taskRunTemplate.serviceAccountName`, `spec.taskRunSpecs[].serviceAccountName`: the only fields that name one in a
`tekton.dev/v1` PipelineRun, the one version Octomaton accepts). When one carries the annotation
and the run's branch matches none of its globs, the run is refused: no PipelineRun, and its check fails with the
reason. The run's branch is the branch whose code runs: the pushed branch (`push`), the head branch (`pull_request`,
`comment`, `review_request`), the merge group's branch (`merge_group`) or the default branch (`schedule`); a tag push
has none and matches nothing. Without the annotation, every branch may use the ServiceAccount. The check fails closed:
a named ServiceAccount Octomaton can't read (other than one that doesn't exist, which Tekton fails), an empty or
invalid annotation, or a name that isn't a string refuses the run too. A PipelineRun that names no ServiceAccount runs
as Tekton's default, which is never checked and must never carry the annotation. This is the one Octomaton setting
outside `.octomaton.yaml`: it sits on the identity, which the repository can't change
([design](designs/terraform-plan-apply.md)).

## Pull request reviewer

Requesting a review from `arikkfir-reviewer` runs the reviewer on the pull request ([design](designs/pr-reviewer.md)).

| Item | Value |
| --- | --- |
| GitHub user | `arikkfir-reviewer`, a member of `arikkfir-org` |
| Team | `reviewers` (closed): `arikkfir-reviewer`, with `push` on every repository (resolving threads takes write access) |
| Token | Fine-grained personal access token of `arikkfir-reviewer`: resource owner `arikkfir-org`, all repositories, contents and pull requests read and write (GitHub resolves a review thread only for a token with contents write); expires within a year; Secret Manager `reviewer-github-pat` |
| Model | DeepSeek V4 Pro (`deepseek-v4-pro`), through opencode `1.18.33` (`ghcr.io/anomalyco/opencode`) as `deepseek/deepseek-v4-pro`; key in Secret Manager `reviewer-deepseek-api-key` |
| Definitions | `arikkfir-org/tooling`, `reviewer/`: the PipelineRun `reviewer/pipelinerun.yaml`, its scripts, the prompt and `opencode.json`, all read at `tooling`'s default branch |
| Findings | Each a thread, marked 🔴 blocking (must fix), 🟡 non-blocking (should fix) or 🔵 nit (could fix), with a severity (`low`, `medium`, `high`, `urgent`) and a likelihood (`low`, `medium`, `high`). The review approves when there are none or only nits, and requests changes otherwise |
| Trigger | Pipeline `review`, display name `AI Review`: an organization pipeline in `arikkfir-org/tooling`'s `.octomaton.yaml` (the organization repository), so every repository has it. `on.review_request.reviewers: [arikkfir-reviewer]`, `secrets: [reviewer-deepseek-api-key, reviewer-github-pat]`, `githubToken` with contents and pull requests read |
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

## Docs site

One URL space at `https://docs.dev.kfirs.com`, composed from every repository ([design](designs/docs-site-composition.md)).

| Item | Value |
| --- | --- |
| Sources | `docs`: its whole tree. Every other repository: its `docs/` directory, at the site root. Hidden paths are never published; a source named `*.md.html` is refused |
| Layers | `gs://arikkfir-docs/.layers/<repository>/`, mirrored from the repository's `main` on every push |
| URLs | `X.md`: the Markdown (`text/markdown; charset=utf-8`). `X.md.html`: rendered on request. Other files: as they are. A missing `X.html` redirects to `X.md.html`. Hidden paths and directories: 404 |
| Overlay order | `docs`, then every other repository alphabetically; Caddy serves a path from the first layer that has it |
| Collisions | A file path belongs to the first repository that publishes it. The `Docs` check fails a change that publishes a path another layer has; after a race, both repositories' checks fail until one renames |
| Check | Organization pipeline `docs`, check `Docs`, on pull requests and merge groups, as `docs-reader`: no `*.md.html` sources, relative links resolve against the composed site, no collisions |
| Publish | Organization pipeline `docs-publish`, on pushes to `main`, as `docs-publisher`: mirror the layer, then the same checks |
| Definitions | `tooling`: `.octomaton.yaml` (`organization.pipelines`) and `docs-site/` |
| Serving | `delivery`, `platform/docs`: the Caddyfile and page template; its layer list is the overlay order |
