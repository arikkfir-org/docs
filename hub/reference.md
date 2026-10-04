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
| DNS domain | `kfirs.com` (Cloud DNS zone `kfirs-com`): hub tools under `dev.kfirs.com`, sign-in at `auth.kfirs.com` (oauth2-proxy) and `id.kfirs.com` (Keycloak), [Fin](#fin) under `fin.kfirs.com` (also its Go module path) and its pull requests under `dev.fin.kfirs.com`. `octomaton.dev` (zone `octomaton-dev`): Octomaton's webhook and Go module path. `kfirfamily.com` (zone `kfirfamily-com`) is imported but unused. |
| Identity provider | Keycloak, realm `hub` in namespace `keycloak`, issuer `https://id.kfirs.com/realms/hub` ([Authentication](#authentication)). |
| Label/annotation prefix | `kfirs.com/` for hub-wide labels, `octomaton.dev/` for Octomaton bookkeeping and the [ServiceAccount branch restriction](#serviceaccount-branches) |
| Terraform state | GCS bucket `arikkfir-devops` (created by hand, versioned), prefixes `github`, `gcp`, `argocd`, `keycloak` |

## Repositories

| Repository | Purpose | Default-branch rules | Required checks |
| --- | --- | --- | --- |
| `.github` | The organization's welcome page on GitHub: `profile/README.md`, nothing else | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` (neither runs, since `.github` has no CI tenant: merged with the admin bypass) |
| `docs` | Hub-wide knowledge base; with every repository's `docs/`, served at `docs.dev.kfirs.com` ([docs site](#docs-site)) | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` |
| `infra` | Terraform: GitHub, GCP, Argo CD bootstrap, Keycloak's configuration; [plans and applies](#terraform-applies) `gcp`, `github` and `keycloak` | PR + 1 approval + merge queue of one | `Continuous Integration` (fmt, validate, plans), `Docs` |
| `delivery` | Argo CD applications (GitOps) | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` |
| `octomaton` | CI orchestrator (GitHub App + Tekton) | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` |
| `tooling` | Org-wide tooling: the Claude Code web bundle, the [pull request reviewer](#pull-request-reviewer), and the organization pipelines every repository runs (`.octomaton.yaml`) | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` |
| `fin` | Personal finance manager and assistant. Internal: visible only to members of the organization's enterprise | PR + 1 approval + merge queue | `Continuous Integration`, `Docs` |

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
| Docker repository | `me-west1-docker.pkg.dev/arikkfir/images` | nodes read; `ci-octomaton/ci-octomaton-release` and `ci-fin/ci-fin-release` write. Images: `octomaton` (Octomaton's `release`) and `reviewer` (Octomaton's `reviewer-image`, the [pull request reviewer](#pull-request-reviewer)'s image), each tagged with the commit's short SHA and `main`; `fin-api`, `fin-worker`, `fin-scraper`, `fin-web` and `fin-migrations` ([Fin](#fin)'s `release`), tagged with the commit's short SHA |
| Docker repository | `me-west1-docker.pkg.dev/arikkfir/previews` | nodes read; `ci-fin/ci-fin-preview` writes, from any branch. Images: `fin-api`, `fin-worker`, `fin-scraper`, `fin-web` and `fin-migrations` of [Fin](#fin)'s pull requests (its `preview`), tagged with the commit's short SHA. Versions older than 14 days are deleted, except each image's 20 newest |
| Bucket | `arikkfir-docs` (`ME-WEST1`, uniform access, public access prevention enforced) | private, one layer per repository under `.layers/<repository>/` ([docs site](#docs-site)): `docs/docs` reads and serves it at `https://docs.dev.kfirs.com`; each tenant's `docs-publisher` writes its own layer, and `docs-reader` lists names |
| Bucket | `arikkfir-claude` (`ME-WEST1`, uniform access) | public object reads (no listing); `ci-tooling/ci-tooling-publish` writes |
| Bucket | `arikkfir-fin` (`ME-WEST1`, uniform access, public access prevention enforced; objects deleted after 30 days) | private: [Fin](#fin) production's scrape videos, traces and raw statements, under `runs/<run>/`. `fin/scraper` creates objects; `fin/api` and `fin/worker` read them |
| Bucket | `arikkfir-fin-pull-requests` (`ME-WEST1`, uniform access, public access prevention enforced; objects deleted after 7 days) | private: the same for every [Fin](#fin) pull request's environment, under `pr-<number>/`. Pool `fin-pull-requests` reads and writes objects |

Public URLs (`arikkfir-claude` only) are `https://storage.googleapis.com/<bucket>/<path>`.

## Secret Manager

Terraform (`terraform/gcp`) creates the secret containers. Values are added by hand (`gcloud secrets versions add`), except the three that `terraform/keycloak` generates and writes write-only, so neither its state nor its plans hold them: `keycloak-hub-client-secret`, `infra-plan-keycloak-secret` and `infra-apply-keycloak-secret`. External Secrets Operator reads all but `infra`'s four pipeline secrets (its GitHub tokens and Keycloak credentials), which only `infra`'s pipelines read, so no Kubernetes Secret ever holds them. Its ClusterSecretStore `gcp-secret-manager` serves every namespace but those labelled `kfirs.com/pull-request`, which [Fin](#fin)'s pull requests' deployments carry.

| Secret | Content | Consumed by |
| --- | --- | --- |
| `octomaton-github-app-id` | GitHub App ID (number) | `octomaton/octomaton-github` key `app-id` |
| `octomaton-github-private-key` | GitHub App private key (PEM) | `octomaton/octomaton-github` key `private-key` |
| `octomaton-github-webhook-secret` | GitHub App webhook secret | `octomaton/octomaton-github` key `webhook-secret` |
| `oauth2-proxy-cookie-secret` | 32 random bytes, base64 | `auth/oauth2-proxy` key `cookie-secret` |
| `keycloak-bootstrap-admin` | Secret of Keycloak's temporary bootstrap admin, service account `bootstrap-admin` in realm `master` (`openssl rand -hex 32`), for `terraform/keycloak`'s first apply | `keycloak/keycloak-bootstrap-admin` keys `client-id` (`bootstrap-admin`) and `client-secret` |
| `keycloak-google-client-secret` | Secret of the Google OAuth client of identity provider `google` in realms `hub` and `master` | `keycloak/keycloak-vault` keys `hub_google-client-secret` and `master_google-client-secret` (Keycloak's file vault) |
| `keycloak-hub-client-secret` | Secret of Keycloak client `hub` (realm `hub`), generated by `terraform/keycloak`; a placeholder before its first apply ([bootstrap runbook](runbooks/bootstrap.md)) | `auth/oauth2-proxy` key `client-secret`; `argocd/argocd-oidc` key `clientSecret` |
| `grafana-postgres-admin-password` | Password of the superuser `postgres` on Grafana's PostgreSQL, which people sign in with | `grafana/postgres-admin` key `password` |
| `argocd-github-app-id` | Argo CD's GitHub App ID (number) | `argocd/github-app` key `githubAppID` |
| `argocd-github-app-private-key` | Argo CD's GitHub App private key (PEM) | `argocd/github-app` key `githubAppPrivateKey` |
| `fin-postgres-arik-password` | Password of role `arik`, the superuser people sign in as, on [Fin](#fin) production's PostgreSQL | `fin/db-arik` key `password` |
| `fin-scraper-sealing-key` | 32 random bytes, base64: the seed of the key pair that seals bank credentials and saved browser sessions for [Fin](#fin) production's scraper | `fin/scraper-sealing-key` key `key` |
| `reviewer-deepseek-api-key` | DeepSeek API key | `ci-*/reviewer-deepseek-api-key` key `api-key` (the [reviewer](#pull-request-reviewer)'s `review` task) |
| `reviewer-github-pat` | `arikkfir-reviewer`'s fine-grained personal access token | `ci-*/reviewer-github-pat` key `token` (the [reviewer](#pull-request-reviewer)'s `report` task) |
| `infra-plan-github-pat` | Fine-grained personal access token that reads the organization's repositories and settings and writes contents (see [Terraform applies](#terraform-applies)) | `ci-infra/ci-infra-plan`, read at run time by `infra`'s `ci` pipeline |
| `infra-apply-github-pat` | Fine-grained personal access token that administers the organization's repositories and settings (see [Terraform applies](#terraform-applies)) | `ci-infra/ci-infra-apply`, read at run time by `infra`'s `apply` pipeline |
| `infra-plan-keycloak-secret` | Secret of Keycloak client `terraform-plan` (realm `master`), generated by `terraform/keycloak` | `ci-infra/ci-infra-plan`, read at run time by `infra`'s `ci` pipeline (see [Terraform applies](#terraform-applies)) |
| `infra-apply-keycloak-secret` | Secret of Keycloak client `terraform-apply` (realm `master`), generated by `terraform/keycloak` | `ci-infra/ci-infra-apply`, read at run time by `infra`'s `apply` pipeline |

## GCP identities and permissions

Kubernetes workloads use GKE Workload Identity Federation with direct principal bindings (no Google service accounts):
`principal://iam.googleapis.com/projects/8909046976/locations/global/workloadIdentityPools/arikkfir.svc.id.goog/subject/ns/<namespace>/sa/<service-account>`.

In CI tenants, Tekton's default ServiceAccount `pipeline` holds no role ([design](designs/ci-service-accounts.md)). A pipeline that needs Google Cloud names its own ServiceAccount, and one that publishes is annotated `octomaton.dev/branches: main`. The one exception is `ci-fin/ci-fin-preview`, which publishes pull requests' images, from their branches, to `previews`, which only pull requests' deployments pull from.

| Principal (namespace/KSA) | Role | Scope |
| --- | --- | --- |
| `external-secrets/external-secrets` | `roles/secretmanager.secretAccessor` | each secret above but `infra`'s four pipeline secrets: `infra-plan-github-pat`, `infra-apply-github-pat`, `infra-plan-keycloak-secret` and `infra-apply-keycloak-secret` |
| `cert-manager/cert-manager` | `roles/dns.admin` | managed zones `kfirs-com` and `octomaton-dev` |
| `grafana/grafana` | `roles/monitoring.viewer` | project |
| `octomaton/octomaton` | `roles/telemetry.metricsWriter`, `roles/telemetry.tracesWriter`, `roles/serviceusage.serviceUsageConsumer` | project |
| `docs/docs` | `roles/storage.objectViewer` | bucket `arikkfir-docs` |
| `ci-<repository>/docs-publisher` | `roles/storage.objectUser` on objects under `.layers/<repository>/` (IAM condition), `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-<repository>/docs-reader` | `roles/storage.legacyBucketReader` | bucket `arikkfir-docs` |
| `ci-tooling/ci-tooling-publish` | `roles/storage.objectUser`, `roles/storage.legacyBucketReader` | bucket `arikkfir-claude` |
| `ci-octomaton/ci-octomaton-release` | `roles/artifactregistry.writer` | repository `images` |
| `ci-fin/ci-fin-release` | `roles/artifactregistry.writer` | repository `images` |
| `ci-fin/ci-fin-preview` | `roles/artifactregistry.writer` | repository `previews` |
| `fin/api`, `fin/worker`, `fin/scraper` | `roles/telemetry.tracesWriter`, `roles/telemetry.metricsWriter`, `roles/serviceusage.serviceUsageConsumer` | project |
| `fin/worker` | `roles/aiplatform.user` | project |
| `fin/api`, `fin/worker` | `roles/storage.objectViewer` | bucket `arikkfir-fin` |
| `fin/scraper` | `roles/storage.objectCreator` | bucket `arikkfir-fin` |
| Pool `fin-pull-requests` (every identity in it) | `roles/telemetry.tracesWriter`, `roles/telemetry.metricsWriter`, `roles/serviceusage.serviceUsageConsumer`, `roles/aiplatform.user` | project |
| Pool `fin-pull-requests` (every identity in it) | `roles/storage.objectUser` | bucket `arikkfir-fin-pull-requests` |
| `ci-infra/ci-infra-plan` | `roles/iam.securityReviewer`, `roles/serviceusage.serviceUsageViewer`, `roles/compute.networkViewer`, `roles/container.clusterViewer`, `roles/artifactregistry.reader`, `roles/secretmanager.viewer`, `roles/dns.reader`, `roles/iam.serviceAccountViewer`, `roles/iam.workloadIdentityPoolViewer` | project |
| `ci-infra/ci-infra-plan` | `roles/storage.legacyBucketReader` | each bucket `terraform/gcp` manages |
| `ci-infra/ci-infra-plan` | `roles/storage.objectViewer` | bucket `arikkfir-devops` |
| `ci-infra/ci-infra-plan` | `roles/secretmanager.secretAccessor` | secrets `infra-plan-github-pat` and `infra-plan-keycloak-secret` |
| `ci-infra/ci-infra-apply` | `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`, `roles/container.admin`, `roles/artifactregistry.admin`, `roles/storage.admin`, `roles/secretmanager.admin`, `roles/dns.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.securityAdmin`, `roles/iam.workloadIdentityPoolAdmin` | project |
| `ci-infra/ci-infra-apply` | `roles/iam.serviceAccountUser` | service account `gke-hub-nodes@` |
| `gke-hub-nodes@` (GSA) | `roles/container.defaultNodeServiceAccount` | project |
| `gke-hub-nodes@` (GSA) | `roles/artifactregistry.reader` | repositories `images` and `previews` |
| `claude-code@` (GSA) | `roles/viewer`, `roles/mcp.toolUser` | project |

`claude-code@arikkfir.iam.gserviceaccount.com` is Claude Code on the web's identity, made by hand and adopted by
`terraform/gcp`: the Claude Code environment holds its key, made by hand, and its proxy adds it to requests for
`*.googleapis.com`. Sessions read the hub cluster through GKE's MCP server, `https://container.googleapis.com/mcp`
([design](designs/claude-code-cluster-access.md)).

One Workload Identity Federation pool is managed here, `fin-pull-requests`, for [Fin](#fin)'s pull requests'
environments: their namespaces come and go with the pull requests, and GKE's own pool grants only to namespaces named in
advance. Its OIDC provider `hub` trusts the hub cluster's ServiceAccount tokens (issuer
`https://container.googleapis.com/v1/projects/arikkfir/locations/me-west1-a/clusters/hub`, the provider's default
audience) only from namespaces whose names start with `fin-pr-` (its attribute condition); `google.subject` is the
token's `sub` and `attribute.namespace` its namespace. A pod presents a projected token of that audience through an
`external_account` credential file. The grants above go to
`principalSet://iam.googleapis.com/projects/8909046976/locations/global/workloadIdentityPools/fin-pull-requests/*`.
There is no pool for workloads outside GCP: no GitHub Actions run, and CI runs in the cluster. The pre-existing
`github-actions`, `greenstar` and `arikkfir.svc.id.goog` pools belong to other projects or to GKE and are not managed
here.

## Terraform applies

`infra` plans and applies through Octomaton ([design](designs/terraform-plan-apply.md)):

| Item | Value |
| --- | --- |
| Pull requests and merge queue | Pipeline `ci` (`Continuous Integration`) as `ci-infra/ci-infra-plan`: `fmt`, `validate` in every root, `plan -lock=false` in `gcp`, `github` and `keycloak`, `keycloak` with `-refresh=false`; a task per root, all at once |
| Merge to `main` | Pipeline `apply` (`Apply`) as `ci-infra/ci-infra-apply`: plans `gcp`, `github` and `keycloak` and applies them in full, deletions and replacements included, a task per root: `gcp` and `github` at once, `keycloak` after `gcp` |
| Concurrency | The merge queue's `ci` runs and `apply` share the group `terraform` (policy `queue`) |
| Checks | Each task of `ci` and `apply` is also its own check (`taskChecks`): `Continuous Integration / gcp`, `Apply / gcp` and so on |
| By hand (`make terraform <root>`) | `argocd` (bootstrap only), `keycloak`'s first apply, and the first apply of new roles or tokens |
| `infra-plan-github-pat` | Fine-grained, resource owner `arikkfir-org`, all repositories: repository Administration and Metadata read, Contents read and write; organization Administration and Members read |
| `infra-apply-github-pat` | Fine-grained, resource owner `arikkfir-org`, all repositories: repository Administration and Contents read and write, Metadata read; organization Administration and Members read and write |
| `keycloak` | Root `terraform/keycloak`, state prefix `keycloak`: realm `hub` with its flows, identity provider, client and users, and the pipelines' clients in realm `master` ([Authentication](#authentication)). `ci` plans it and `apply` applies it, after `gcp`, which creates the secrets it writes. The first apply runs as the bootstrap admin through `kubectl -n keycloak port-forward svc/keycloak-service 8080`; the pipelines reach `http://keycloak-service.keycloak.svc.cluster.local:8080` |
| Keycloak credentials | `ci-infra-plan` signs in as client `terraform-plan` (secret `infra-plan-keycloak-secret`): roles `view-realm` and `view-clients` of client `master-realm`, which the root's data sources read. `ci`'s plans of `keycloak` don't refresh: Keycloak 26.8 shows a client's secret only to administrators who can manage clients, and the provider reads the secret to refresh a client. `ci-infra-apply` signs in as `terraform-apply` (`infra-apply-keycloak-secret`): realm role `admin`. Both are service accounts in realm `master`, and the provider reads them from `KEYCLOAK_CLIENT_ID` and `KEYCLOAK_CLIENT_SECRET` |

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
| `keycloak` | Keycloak Operator, watching its own namespace | `keycloak/keycloak-k8s-resources` release kustomization (`kubernetes/`) | `26.8.0` |
| `keycloak` | Keycloak (identity provider): resource `keycloak`, two pods, Service `keycloak-service` (port 8080) | `quay.io/keycloak/keycloak` | `26.8.0` |
| `keycloak` | PostgreSQL for Keycloak: StatefulSet `postgres`, one replica, a 10Gi volume | `docker.io/library/postgres` | `18.6-trixie` |
| `grafana` | Grafana | `https://grafana-community.github.io/helm-charts` `grafana` | `13.2.7` (Grafana 13.2.3) |
| `grafana` | PostgreSQL for Grafana: StatefulSet `postgres`, one replica, a 10Gi volume | `docker.io/library/postgres` | `18.6-trixie` |
| `tekton-operator` | Tekton Operator | `tektoncd/operator` release manifest from `infra.tekton.dev` (Tekton's release host since v0.78) | `v0.81.1` |
| `tekton-pipelines` | Pipelines, Triggers, Dashboard (via `TektonConfig`; Results, Chains, Pipelines-as-Code and the operator's NetworkPolicies off) | operator-managed | operator default |
| `octomaton` | Octomaton | `me-west1-docker.pkg.dev/arikkfir/images/octomaton` | The short SHA of the `main` commit Argo CD deploys (`${ARGOCD_APP_REVISION_SHORT}`, see [Octomaton](#octomaton)). There are no version tags; every push to `main` publishes one, which is also the version the binary and its telemetry report |
| `octomaton` | `go-import`: Caddy answering for `octomaton.dev` | `docker.io/library/caddy` | `2.11.4-alpine` |
| `docs` | Docs site: Caddy overlaying the layers of `arikkfir-docs` (Cloud Storage FUSE mount) and rendering Markdown ([docs site](#docs-site)) | `docker.io/library/caddy` | `2.11.4-alpine` |
| `go-import` | `go-import`: Caddy answering for `fin.kfirs.com`, [Fin](#fin)'s Go module path | `docker.io/library/caddy` | `2.11.4-alpine` |
| `ci-<repo>` | CI tenants (one per repository) | `delivery` | n/a |
| `fin`, `fin-pr-<number>` | [Fin](#fin): production and each pull request's deployment, PostgreSQL with pgvector, fin-worker, fin-scraper and their NATS streams included | `deploy/` in `fin` (Kustomize), deployed by `delivery` | The images of the deployed commit; PostgreSQL `docker.io/pgvector/pgvector:0.8.7-pg18-trixie` |

NATS clients, NACK included, connect to `nats://nats.nats.svc.cluster.local:4222`. JetStream streams may keep up to
three replicas. The servers spread across system-pool nodes when there are several, but don't make the pool grow.

Availability ([design](designs/disruption-budgets.md)): Traefik, oauth2-proxy, Keycloak, the docs site, Grafana, Octomaton,
both `go-import`s (namespaces `octomaton` and `go-import`) and KEDA's operator, metrics server and webhooks run two replicas each. NATS runs three servers. Each has a
PodDisruptionBudget of `maxUnavailable: 1` and spreads its pods over nodes when the pool has several
(`whenUnsatisfiable: ScheduleAnyway`). Grafana keeps its state in database `grafana` on StatefulSet `postgres` in its
namespace, at `postgres.grafana.svc.cluster.local:5432` without TLS, and NetworkPolicy `postgres` admits only Grafana's
pods. Role `grafana`'s password is generated in the cluster: an ESO `Password` generator with
`refreshPolicy: CreatedOnce` creates Secret `grafana/grafana-db`. People sign in as the superuser `postgres` through
`kubectl port-forward -n grafana svc/postgres 5432`, with the password from Secret Manager
`grafana-postgres-admin-password`. Every TCP connection needs a password; only the local socket is trusted. PostgreSQL
runs one replica without a budget. Grafana's replicas share alert state through Service `grafana-headless` on port 9094.

Keycloak keeps its state, sessions included, in database `keycloak` on StatefulSet `postgres` in namespace `keycloak`, at `postgres.keycloak.svc.cluster.local:5432` without TLS, and NetworkPolicy `postgres` admits only Keycloak's pods. Role `keycloak`, the image's superuser and the database's owner, has a password generated in the cluster: an ESO `Password` generator with `refreshPolicy: CreatedOnce` creates Secret `keycloak/keycloak-db` (keys `username` and `password`). People connect with `kubectl exec -n keycloak postgres-0 -- psql -U keycloak`. Every TCP connection needs a password; only the local socket is trusted. PostgreSQL runs one replica without a budget, so sign-in pauses while it restarts. The PodDisruptionBudget `keycloak` and the pods' spread select `app=keycloak` and `app.kubernetes.io/instance=keycloak`, the labels the operator sets.

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
| `protected/websecure`, `public/public-websecure` | `*.kfirs.com` (which also matches `*.dev.kfirs.com` and `admin.id.kfirs.com`) | `wildcard-kfirs-com` (`*.kfirs.com`, `*.dev.kfirs.com`, `admin.id.kfirs.com`) / `traefik/wildcard-kfirs-com-tls` |
| `public/octomaton-dev` (port 9443) | `octomaton.dev` | `octomaton-dev` / `traefik/octomaton-dev-tls` |
| `fin/fin`, listeners `app` and `api` (port 8443) | Production's hosts (below); listener `api` goes with the `api` host | `fin` / `fin/fin-tls` |
| `traefik/fin-pull-requests`, listeners `app` and `api` (port 8443) | `*.app.dev.fin.kfirs.com`, `*.api.dev.fin.kfirs.com` | `fin-pull-requests` (both wildcards) / `traefik/fin-pull-requests-tls` |

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
| `admin.id.kfirs.com` | protected | `keycloak/keycloak-service:8080`, paths `/` (Keycloak redirects it to the console), `/admin`, `/realms/master` and `/resources`: Keycloak's admin console |
| `auth.kfirs.com` | public | `auth/oauth2-proxy:80`, path `/oauth2` |
| `id.kfirs.com` | public | `keycloak/keycloak-service:8080`, paths `/realms/hub` and `/resources`, and `/realms/master` behind the hub's sign-in (Middleware `keycloak/oidc`, a ForwardAuth to oauth2-proxy): the admin console signs in against this frontend hostname |
| `legal.kfirs.com` | public | `docs/docs:80`, exact paths `/privacy.html`, `/tos.html` and their `.md.html` pages: the privacy policy and terms of service the Google OAuth app's branding links to |
| `octomaton.dev` | public (listener `octomaton-dev`) | `octomaton/octomaton:80` for path `/github/hooks`; `octomaton/go-import:80` for everything else |
| `fin.kfirs.com` | public | `go-import/go-import:80`: Fin's Go import page |
| `app.fin.kfirs.com` | `fin/fin` (protected entry point) | `fin/api:80` for `/api/` (through Middleware `fin/id-token`), `fin/web:80` for everything else. `api.fin.kfirs.com` serves `fin/api:80` until Fin's `/api` route ships, then goes |
| `pr-<number>.app.dev.fin.kfirs.com` | `traefik/fin-pull-requests` (protected entry point) | `fin-pr-<number>/api:80` for `/api/` (through Middleware `fin-pr-<number>/id-token`), `fin-pr-<number>/web:80` for everything else. `pr-<number>.api.dev.fin.kfirs.com` serves `fin-pr-<number>/api:80` until Fin's `/api` route ships, then goes |

DNS A records (TTL 300) point each host at its gateway's IP: in zone `kfirs-com` for `kfirs.com` hosts, and the apex
of zone `octomaton-dev` for `octomaton.dev`.

[Fin](#fin)'s hosts need certificates of their own (`*.kfirs.com` covers one label), so they have Gateways of their own on the protected gateway's entry point (port 8443, `websecure`), and their routes get the same interceptor. Production's is `fin/fin`, whose listeners take routes from its own namespace only. Every pull request's environment shares `traefik/fin-pull-requests`, whose one certificate covers all their hosts, so a pull request issues no certificate (Let's Encrypt issues at most 50 a week for `kfirs.com`); its listeners take routes only from namespaces labelled `kfirs.com/pull-request=true`. Fin's routes never attach to `traefik/protected`. Fin's DNS records are `app.fin`, `api.fin` and the wildcards `*.app.dev.fin` and `*.api.dev.fin`, which answer for every pull request's hosts, all at `ingress-protected`, and `fin`, its Go import page, at `ingress-public`. The API moves under `/api` on the app's host, one origin for the browser; once it has, `api.fin` and `*.api.dev.fin` go, with the `api` listeners and the certificates' `api` names. The wildcards sit where the certificate's DNS-01 challenge records do (`_acme-challenge.app.dev.fin`, `_acme-challenge.api.dev.fin`): a wildcard higher up would stop answering below them while they exist. Pull requests' hosts lie under production's `.fin.kfirs.com`, so production's Gateway, certificate and routes are held to names outside `.dev.fin.kfirs.com`.

## Authentication

Keycloak decides who signs in: the users `terraform/keycloak` declares in realm `hub`, and nobody else ([design](designs/keycloak.md)). oauth2-proxy and Argo CD sign in with it.

| Item | Value |
| --- | --- |
| Realm `hub` | Issuer `https://id.kfirs.com/realms/hub`. Registration, password reset and duplicate emails off; login with email on. Access tokens live 10 minutes; SSO sessions end after 7 idle days, and after 30 days at most |
| Browser flow | `browser-google`, the realm's browser flow: an existing session (`auth-cookie`), or straight to Google (`identity-provider-redirector`, config `google`, default provider `google`) |
| Identity provider `google` | Google OIDC; client secret `${vault.google-client-secret}`, from Keycloak's file vault; emails trusted; sync mode `IMPORT`; scopes `openid email profile`. Its Google OAuth client, `8909046976-i0f5h1b5t5dvggl4qbejap1h8nkmj217.apps.googleusercontent.com` in project `arikkfir` (Google Auth Platform, External, in production), is created by hand, with redirect URIs `https://id.kfirs.com/realms/hub/broker/google/endpoint` and `https://id.kfirs.com/realms/master/broker/google/endpoint` |
| First login | Flow `existing-users-only`: `idp-detect-existing-broker-user`, then `idp-auto-link`. A Google identity links to the declared user with the same email; anyone else is refused |
| Users | Declared in `terraform/keycloak`, keyed by the email of their Google account, which is also their username; email verified. Those marked `admin` also get a user in realm `master` with realm role `admin`, which administers every realm |
| Client `hub` | Confidential, standard flow only; redirect URIs `https://auth.kfirs.com/oauth2/callback` and `https://argocd.dev.kfirs.com/auth/callback`. Terraform generates its secret and writes it, write-only, to Keycloak and to `keycloak-hub-client-secret`. oauth2-proxy and Argo CD share it, so Argo CD accepts the ID tokens oauth2-proxy forwards |
| Realm `master` | Its console at `admin.id.kfirs.com`, its sign-in at `id.kfirs.com/realms/master`, both only behind the hub's sign-in. The same browser flow, identity provider `google` and first login as realm `hub`, for the admins `terraform/keycloak` declares. Clients `terraform-plan` and `terraform-apply` ([Terraform applies](#terraform-applies)), and the bootstrap admin, service account `bootstrap-admin`, which is deleted once the pipelines apply `keycloak`. Break-glass: `kcadm.sh` through `kubectl exec`; `kc.sh bootstrap-admin` recreates an admin |
| Server | Resource `keycloak`: hostname `https://id.kfirs.com`, admin hostname `https://admin.id.kfirs.com`, backchannel URLs from each request (for Terraform's in-cluster calls), plain HTTP on 8080 behind Traefik, trusting its `X-Forwarded-*` headers. The file vault is Secret `keycloak-vault`, mounted at `/opt/keycloak/vault`. The operator's NetworkPolicy admits port 8080 from namespaces `traefik` and `ci-infra` only |

- oauth2-proxy (`auth` namespace) is the OIDC client (client `hub`), keeps a session cookie on `.kfirs.com`, and admits every user Keycloak authenticates (`emailDomains: ["*"]`, no email list).
- Traefik's `oidc` ForwardAuth middleware calls `http://oauth2-proxy.auth.svc.cluster.local/` (static `202` upstream)
  for every request on the protected entry point, and copies `X-Auth-Request-User`, `X-Auth-Request-Email` and
  `X-Auth-Request-Preferred-Username` to the upstream request. `strip-auth-headers` removes client-supplied copies first.
- Grafana trusts `X-Auth-Request-Email` (auth proxy mode). Argo CD's route adds the `argocd/id-token` ForwardAuth middleware, which copies oauth2-proxy's `Authorization: Bearer <ID token>` to Argo CD only; Argo CD verifies the token against Keycloak (OIDC, same client), so the Keycloak session signs the user in, and grants `role:admin` to every authenticated user. Its own "Log in via Keycloak" remains the fallback. Tekton Dashboard, NUI and the Traefik dashboard rely on the interceptor alone.
- oauth2-proxy requests `openid email profile` and refreshes a session's tokens after 5 minutes (`cookie-refresh`), so the ID token it hands to Argo CD stays valid. It doesn't request `offline_access`: requested at the first login, it stops Keycloak from setting its SSO cookie. The refresh token lasts as long as the SSO session.
- NUI's route adds `nats/strip-cookies`, which removes the `Cookie` header after ForwardAuth: NUI's server (fasthttp)
  refuses request headers over 4 KiB, which oauth2-proxy's session cookies on `.kfirs.com` can exceed.
- Protected backends accept traffic only from the `traefik` namespace (NetworkPolicy); Argo CD's server also admits
  its own namespace and Octomaton, which relays GitHub webhooks to `/api/webhook`.
- [Fin](#fin) signs people in through this interceptor, on Gateways `fin/fin` and `traefik/fin-pull-requests`. Its routes remove the `Cookie` header after it, so the hub's session cookie (domain `.kfirs.com`) never reaches Fin's code, a pull request's included. Its `/api` rules first add Middleware `id-token` in Fin's own namespace, a ForwardAuth like Argo CD's that copies oauth2-proxy's `Authorization: Bearer <ID token>`; fin-api verifies the token (issuer `https://id.kfirs.com/realms/hub`, audience `hub`) with the realm's published keys, and takes the person from it.

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
| Kubernetes | namespace `octomaton` (label `pod-security.kubernetes.io/enforce: restricted`, version `latest`; `kfirs.com/public-ingress: "true"` from `delivery`; `argocd.argoproj.io/sync-options: Delete=false,Prune=false`), Deployment/ServiceAccount/Service `octomaton` (Service port 80 → container 8080); Deployment/Service/ConfigMap `go-import` for the import page (Service port 80 → container 8080); two replicas of each Deployment, with PodDisruptionBudgets `octomaton` and `go-import` (`maxUnavailable: 1`) |
| Deployment | `deploy/` in `arikkfir-org/octomaton` (Kustomize): the hub's deployment as written, its Namespace and RBAC included ([design](designs/octomaton-deployment.md)) |
| Application | In namespace `argocd`, from Application `octomaton-environment` (`platform/octomaton/manifests` in `delivery`, wave 4): Application `octomaton`, `deploy/` at `octomaton`'s `main`, without finalizer and without `CreateNamespace`. Its `kustomize` options: image `images/octomaton` at `${ARGOCD_APP_REVISION_SHORT}` (the synced commit's short SHA), and a patch labelling Namespace `octomaton` `kfirs.com/public-ingress: "true"` |
| Project | `octomaton`: source `https://github.com/arikkfir-org/octomaton` only; destination `octomaton`; cluster-scoped, Namespace `octomaton`, ClusterRoles `octomaton` and `octomaton-tenant` and ClusterRoleBinding `octomaton` only; namespaced kinds `ServiceAccount`, `Role`, `RoleBinding`, `ConfigMap`, `external-secrets.io` `ExternalSecret`, `Deployment`, `PodDisruptionBudget`, `Service`, `gateway.networking.k8s.io` `HTTPRoute` and `NetworkPolicy` only. No admission policies: only `main` deploys |
| Validation | `octomaton`'s `ci` (check `Continuous Integration`) renders `deploy/` as written and with the `kustomize` options of every Application in `delivery`'s `main` that deploys it (`deploy/manifests.sh`, `make manifests`), and validates both with kubeconform; a patch whose target matches nothing in `deploy/` fails it |
| Config | Environment variables only ([server configuration](#server-configuration)): ConfigMap `octomaton` through `envFrom`; `OCTOMATON_POD_NAME` and `OCTOMATON_POD_NAMESPACE` from the downward API; `OTEL_RESOURCE_ATTRIBUTES` with the pod, namespace and container names; `enableServiceLinks: false` |
| GitHub secret | Secret `octomaton-github`: keys `app-id`, `private-key`, `webhook-secret` as `OCTOMATON_GITHUB_APP_ID`, `OCTOMATON_GITHUB_PRIVATE_KEY`, `OCTOMATON_GITHUB_WEBHOOK_SECRET` |
| Endpoints | `POST /github/hooks`, `GET /healthz`, `GET /readyz` (all on 8080) |
| Telemetry | On GKE: JSON logs on stdout to Cloud Logging; metrics to Cloud Monitoring and traces to Cloud Trace through the Telemetry API (`telemetry.googleapis.com`), as `octomaton/octomaton`. Elsewhere: text logs, nothing exported |
| Check links | `https://tekton.dev.kfirs.com/#/namespaces/<namespace>/pipelineruns/<name>` |
| Tenant namespaces | `ci-<repository>` for every repository but `.github`, which has no CI; each has ServiceAccounts `pipeline`, `docs-reader` and `docs-publisher` (only `docs-publisher` is annotated `octomaton.dev/branches: main`; see [docs site](#docs-site)) and RoleBinding `octomaton` → ClusterRole `octomaton-tenant`, plus the [reviewer's objects](#pull-request-reviewer). `ci-infra` also has ServiceAccounts `ci-infra-plan` and `ci-infra-apply` (only `ci-infra-apply` is annotated `octomaton.dev/branches: main`), `ci-tooling` has `ci-tooling-publish` and `ci-octomaton` has `ci-octomaton-release` (both annotated `octomaton.dev/branches: main`); `ci-fin` has `ci-fin-release` (annotated `octomaton.dev/branches: main`) and `ci-fin-preview` (not annotated: pull requests' branches use it) |
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
- Every GitHub request (installation tokens included) is retried when it fails for a reason that may pass: a connection
  error or timeout (30 s per attempt), a 5xx but 501, a 429, or a secondary rate limit (403 with `Retry-After`). Up to 6
  attempts, waits doubling from 1 s to 30 s or as `Retry-After` says (at most a minute), each retry logged as a warning
  ([design](designs/octomaton-github-retries.md)). An event whose requests still fail is reported: a configuration that
  could not be read fails `octomaton` (the scheduled pipeline's check when a schedule fires; a reply when a comment
  command, which has no check, is declined), and a run whose check could not be opened fails a check of its pipeline's
  name. Re-running a failed check tries again; `octomaton` is then concluded successfully when the event evaluates. Only
  the periodic read of a repository's schedules just logs: the next read tries again. A failure report outlives the
  webhook job's deadline and is retried the same way; one that still fails is logged as an error.
- A replica drops a delivery it is handling or has handled in the last hour (by `X-GitHub-Delivery`, which a
  redelivery keeps). A delivery whose GitHub or Kubernetes calls still failed and left part of its event undone is
  forgotten, so redelivering it from the App's Recent deliveries handles it again, until one copy succeeds.

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
      # repositories: all              # optional: every repository the App is installed on in the owner, not just this
                                       # one; only when every trigger reads definitions from the default branch
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
ignored), on open pull requests, drafts included. Each request gets its own run. New commits on the pull request
(`synchronize`) while the review is still requested run those pipelines again at the new head, as the pending request
(`.Action` stays `review_requested`), and supersede the older commit's run: GitHub sends no new request while one is
pending, so a re-request can't. Requesting a review takes triage or write access, so the request is the permission
check; only new commits on the pull request's own branch, which take write access, run a pending one again.
`review_requested` is not a `pull_request` type, and an invalid configuration is not reported on review requests: most
are for people. A configuration GitHub would not serve is reported, review requests included.

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
head commit never reach a Secret. The token reads only the run's repository, unless `githubToken.repositories: all` asks
for every repository the App is installed on in the owner (same `permissions`); the same rule as for `secrets` applies. Remote Tekton references are refused (`pipelineRef`, `taskRef`, a step's `ref`, any
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
| Model | DeepSeek V4.1 Flash (`deepseek-flash`), through opencode `1.18.33` (`ghcr.io/anomalyco/opencode`) as `deepseek/deepseek-flash`, at reasoning effort `low` (`--variant low`), without subagents; key in Secret Manager `reviewer-deepseek-api-key` |
| Image | `me-west1-docker.pkg.dev/arikkfir/images/reviewer:main` in `reviewer/pipelinerun.yaml` for every step and the sidecar, pulled for every pod (`imagePullPolicy: Always`): opencode's image plus `bash`, `python3`, `git`, `jq`, `yq`, `curl`, `wget` and GNU userland. Built from `images/reviewer/` in `arikkfir-org/octomaton` by its pipeline `reviewer-image` (on pushes to `main` that change it, as `ci-octomaton-release`; `reviewer-image-check`, check `Reviewer Image`, builds it on pull requests) |
| GitHub proxy | Sidecar `github` of task `review`, on `http://127.0.0.1:8080`: GitHub's REST API under `/api/` (GET and HEAD) and git fetches under `/git/<owner>/<repository>.git`, sent with the run's token, which only it and the `clone` and `state` steps mount. Code `reviewer/github_proxy.py` |
| Definitions | `arikkfir-org/tooling`, `reviewer/`: the PipelineRun `reviewer/pipelinerun.yaml`, its scripts, the prompt and `opencode.json`, all read at `tooling`'s default branch |
| Findings | Each a thread, marked 🔴 blocking (must fix), 🟡 non-blocking (should fix) or 🔵 nit (could fix), with a severity (`low`, `medium`, `high`, `urgent`) and a likelihood (`low`, `medium`, `high`). The review approves when there are none or only nits, and requests changes otherwise |
| Trigger | Pipeline `review`, display name `AI Review`: an organization pipeline in `arikkfir-org/tooling`'s `.octomaton.yaml` (the organization repository), so every repository has it. `on.review_request.reviewers: [arikkfir-reviewer]`, `secrets: [reviewer-deepseek-api-key, reviewer-github-pat]`, `githubToken` with contents and pull requests read for every repository (`repositories: all`) |
| Tasks | `review` (clone, state, opencode, check, fix, recheck; sidecar `github`), `report`; all as ServiceAccount `reviewer`, all labelled `kfirs.com/sandbox=true` |
| Volume | One per run: 50Gi, `ReadWriteOnce` (`volumeClaimTemplate`), deleted an hour after the run (`OCTOMATON_RETENTION_FREE_PVCS_AFTER`) |
| Files on the volume | `<repository>/`: the pull request's repository at the head commit, the model's working directory, with `pr.json`, `pr.diff`, `pr.log` (clone and state) and `findings.json` (the model) at its root; `.review/` beside it (`reviewer/` from `tooling`'s default branch, opencode's home). The model clones other repositories into `/tmp` |
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

One URL space at `https://docs.dev.kfirs.com`, composed from every repository
([design](designs/docs-site-composition.md)).

| Item | Value |
| --- | --- |
| Sources | `docs`: its whole tree. Every other repository: its `docs/` directory, at the site root. Hidden paths (any file or directory name starting with `.`) are never published; a source named `*.md.html` is refused |
| Layers | `gs://arikkfir-docs/.layers/<repository>/`, mirrored from the repository's `main` on every push |
| URLs | `X.md`: the Markdown (`text/markdown; charset=utf-8`). `X.md.html`: rendered on request. Other files: as they are. A missing `X.html` redirects to `X.md.html`. Hidden paths and directories: 404 |
| Overlay order | `docs`, then every other repository alphabetically; Caddy serves a path from the first layer that has it |
| Collisions | A file path belongs to the first repository that publishes it. The `Docs` check fails a change that publishes a path another layer has; after a race, both repositories' checks fail until one renames |
| Check | Organization pipeline `docs`, check `Docs`, on pull requests and merge groups, as `docs-reader`: no `*.md.html` sources, relative links resolve against the composed site, no collisions |
| Publish | Organization pipeline `docs-publish`, on pushes to `main`, as `docs-publisher`: mirror the layer, then the same checks |
| Definitions | `tooling`: `.octomaton.yaml` (`organization.pipelines`) and `docs-site/` |
| Serving | `delivery`, `platform/docs`: the Caddyfile and page template; its layer list is the overlay order |

## Fin

[Fin](https://github.com/arikkfir-org/fin)'s environments ([design](https://github.com/arikkfir-org/fin/blob/main/docs/fin/designs/environments.md)): production, from `fin`'s `main`, and an environment of its own for every open pull request, whatever its base branch, from its head commit. Each is self-contained: its own namespace, PostgreSQL, migrations and host names.

| Item | Value |
| --- | --- |
| Environments | `production`: namespace `fin`, `https://app.fin.kfirs.com`. `pr-<number>`: namespace `fin-pr-<number>`, `https://pr-<number>.app.dev.fin.kfirs.com`. Each serves the app, the back-office at `/backoffice`, and the API under `/api/` (the back-office's under `/api/backoffice/`). Until Fin's `/api` route ships, the API also answers at `https://api.fin.kfirs.com` and `https://pr-<number>.api.dev.fin.kfirs.com`; then those hosts go |
| Deployment | `deploy/` in `fin`: one Kustomize deployment, production as written. ConfigMap `environment` (local-config: `name`, `app`, `api`) and its replacements carry the environment's name and hosts into the workloads, the NATS resources, the certificate, the Gateway and the routes; a pull request's deployment has no certificate or Gateway of its own. Images `fin-api`, `fin-worker`, `fin-scraper`, `fin-web` and `fin-migrations`, tagged by Argo CD; components `components/reset-database` and `components/pull-request` for pull requests |
| Applications | In namespace `argocd`, from Application `fin-environments` (`platform/fin/manifests` in `delivery`, wave 4): Application `fin`, `deploy/` at `fin`'s `main`, without finalizer; ApplicationSet `fin-pull-requests`, whose pull request generator lists all of `fin`'s open pull requests, whatever their base branch, every minute through Argo CD's GitHub App, and makes Application `fin-pr-<number>` from `deploy/` at the head commit, with the resources finalizer |
| Overrides | Application `fin`: images `images/fin-api`, `images/fin-worker`, `images/fin-scraper`, `images/fin-web` and `images/fin-migrations` at `${ARGOCD_APP_REVISION_SHORT}`. ApplicationSet `fin-pull-requests`, in its template's `kustomize` options: namespace `fin-pr-<number>`; the same images from `previews`; one replica of `api` and of `web`; patches: ConfigMap `environment` (`pr-<number>` and its hosts), no Gateway `fin` or Certificate `fin`, routes attached to `traefik/fin-pull-requests`, the Namespace's label `kfirs.com/pull-request: "true"` without the `sync-options` annotation, the smaller quota, no PodDisruptionBudgets, a 1Gi volume, and a generated `db-arik`; components `components/reset-database` and `components/pull-request`, with `ignoreMissingComponents: true`. `components/pull-request` is fin's: what differs inside a pull request's environment and grants nothing, so it stays with the code it changes (the pods run as `default` with the pool's credentials, the NATS resources go with the namespace, one replica and one scrape at a time, a generated sealing key, Demo Bank only) |
| Projects | `fin` (destination `fin`) and `fin-pull-requests` (`fin-pr-*`): source `https://github.com/arikkfir-org/fin` only; cluster-scoped, the Namespace of that name only; namespaced kinds `Deployment`, `StatefulSet`, `Service`, `ConfigMap`, `ResourceQuota`, `Job`, `PodDisruptionBudget`, `NetworkPolicy`, `gateway.networking.k8s.io` `HTTPRoute`, `external-secrets.io` `ExternalSecret`, `generators.external-secrets.io` `Password`, `jetstream.nats.io` `Stream`, `Consumer` and `KeyValue`, `keda.sh` `ScaledObject`, `ScaledJob` and `TriggerAuthentication`, and `traefik.io` `Middleware`, and in `fin` also `cert-manager.io` `Certificate` and `gateway.networking.k8s.io` `Gateway`, only |
| Admission | ValidatingAdmissionPolicies, each with a binding of the same name, for namespaces `fin` and `fin-pr-*` by name: `fin-namespaces` (the latest restricted Pod Security Standard enforced, no `kfirs.com/` label but `kfirs.com/pull-request`, which `fin-pr-*` must carry as `"true"`), `fin-cluster-ip-services` (`ClusterIP` only, no external IPs), `fin-gateways` (only in `fin`: listeners HTTPS on 8443, hosts under `.fin.kfirs.com` but not `.dev.fin.kfirs.com`, routes from their own namespace only), `fin-http-routes` (in `fin`: hosts under `.fin.kfirs.com` but not `.dev.fin.kfirs.com`, parents only Gateways in the same namespace; in `fin-pr-<number>`: hosts `pr-<number>.app.dev.fin.kfirs.com` and `pr-<number>.api.dev.fin.kfirs.com` only, parent only `traefik/fin-pull-requests`; every rule removes `Cookie`), `fin-certificates` (only in `fin`: DNS names and common name under `.fin.kfirs.com` but not `.dev.fin.kfirs.com`), `fin-external-secrets` (Secret Manager read only by name, only `fin-*`), `fin-jetstream` (streams, consumers and key-value buckets named `fin-<env>-…` and subjects under `fin.<env>.`, where `<env>` is `production` in `fin` and `pr-<number>` in `fin-pr-<number>`; no servers, credentials, TLS, account, mirror, sources or republishing elsewhere), `fin-keda` (triggers `cpu`, `memory` and `postgresql` only, the last on `postgres.<namespace>.svc.cluster.local` with the password from a TriggerAuthentication; a TriggerAuthentication holds nothing but `secretTargetRef`s of parameter `password`), `fin-middlewares` (a ForwardAuth to `http://oauth2-proxy.auth.svc.cluster.local/` that copies `Authorization` and nothing else) |
| Workloads | Deployments and Services `api` (fin-api, port 80 → 8080) and `web` (Caddy, port 80 → 8080); Deployment `worker` (fin-worker: the outbox relay, the consumers, the scheduler, jobs and model calls; no Service); ScaledJob `scraper` (fin-scraper: one Kubernetes Job per scrape, Chromium, a 15-minute deadline, no retries). PodDisruptionBudgets of `maxUnavailable: 1` for `api` and `web` in production. NetworkPolicies `api` and `web` admit only the `traefik` namespace; `scraper` reaches only NATS, DNS and port 443 |
| Autoscaling | KEDA: ScaledObjects `api` (CPU, 2–6 replicas), `web` (CPU, 2–4) and `worker` (PostgreSQL `fin_worker_backlog()` and CPU, 1–4); ScaledJob `scraper` (PostgreSQL `fin_scraper_demand()`, polled every 5 s, at most three Jobs at once). The PostgreSQL triggers sign in as role `keda` through TriggerAuthentication `postgres`. A pull request's: one replica each, one scrape at a time |
| ServiceAccounts | `api`, `worker` and `scraper` in `fin`, without token automount, made by `delivery` (`platform/fin/manifests/service-accounts.yaml`), since Fin's code makes no ServiceAccounts; their Workload Identity principals hold production's grants ([GCP identities and permissions](#gcp-identities-and-permissions)). A pull request's pods run as `default`, and `api`, `worker` and the scraper's Jobs authenticate to Google through pool `fin-pull-requests` with a projected token |
| NATS | The hub's cluster, without credentials; a set of resources per environment, declared in `deploy/` as NACK resources and deleted with them: streams `fin-<env>-scrape-requests`, `fin-<env>-scrape-results`, `fin-<env>-events`, `fin-<env>-jobs` and `fin-<env>-dead-letters`, their consumers, and key-value buckets `fin-<env>-scrape-control`, `fin-<env>-scraper-sessions` and `fin-<env>-keys`; subjects under `fin.<env>.`, where plain subjects without a stream carry what may be lost: the assistant's text as it arrives and a scrape's live screencast (`fin.<env>.scrape.frames.<household>.<run>`, while someone watches). Production's streams keep three replicas and set `preventDelete: true`; a pull request's keep one and go with its namespace |
| Scrape artifacts | Videos, Playwright traces and raw statements, in bucket `arikkfir-fin` (production) or `arikkfir-fin-pull-requests` (every pull request, under `pr-<number>/`); fin-api streams them to members, and nothing else reads them |
| Sealing key | Bank credentials and saved browser sessions are sealed (HPKE) in the browser and opened only by fin-scraper, whose key pair comes from a 32-byte seed: production's from Secret Manager `fin-scraper-sealing-key` (ExternalSecret `scraper-sealing-key`), a pull request's from a `Password` generator |
| Models | Vertex AI, global endpoint, as `fin/worker` (a pull request's through pool `fin-pull-requests`): Claude Opus 5.5 (`claude-opus-5-5`) for classification and the assistant, enabled in Model Garden by the owner, who accepts Anthropic's terms once; `gemini-embedding-2` (768 dimensions) for search by meaning. API `aiplatform.googleapis.com` |
| Database | StatefulSet and Service `postgres` (5432, without TLS), one replica without a budget, a 10Gi volume in production and 1Gi for a pull request. NetworkPolicy `postgres` admits only the `api`, `worker` and `migrate` pods, and KEDA's operator (namespace `keda`). Database `fin`, owned by role `migrator`, which runs migrations; role `backend`, fin-api's and fin-worker's, reads and writes rows under row-level security and never changes the schema; role `system`, fin-worker's for work across households, bypasses row-level security; role `assistant` reads only the views in schema `assistant`; role `keda` may only run `fin_worker_backlog()` and `fin_scraper_demand()`; role `arik`, a superuser, is for people (`kubectl port-forward -n <namespace> svc/postgres 5432`); role `postgres`, the image's superuser, only over the local socket. pgvector lives in schema `extensions` |
| Migrations | SQL files in `apps/api/migrations` (golang-migrate's format), applied by Job `migrate`, an Argo CD `Sync` hook in wave -1, after PostgreSQL (wave -2) and before the workloads, as role `migrator`. Its image, `fin-migrations`, is golang-migrate's CLI (`docker.io/migrate/migrate:v4.20.1`) with the files in `/migrations`; no Go code migrates or reads golang-migrate's bookkeeping. A pull request's Job first runs `reset.sql` (component `components/reset-database`: schema `public` dropped and created again). Migrations are forward-compatible: the previous version keeps serving on the migrated schema until the rollout replaces it |
| Database secrets | `db-postgres`, `db-migrator`, `db-backend`, `db-system`, `db-assistant`, `db-keda` and, for a pull request, `db-arik` (key `password`): ESO `Password` generator `db`, `refreshPolicy: CreatedOnce`. Production's `db-arik`: Secret Manager `fin-postgres-arik-password` |
| Namespace | Label `pod-security.kubernetes.io/enforce: restricted` (version `latest`), and for a pull request `kfirs.com/pull-request: "true"`; ResourceQuota `fin` (production: 6 CPUs and 12Gi requested, 24Gi limits, 40 pods, two volumes, 100Gi; a pull request: 2 CPUs, 4Gi, 8Gi, 15 pods, one volume, 5Gi). Production's carries `argocd.argoproj.io/sync-options: Delete=false,Prune=false` |
| Argo CD's GitHub App | `arikkfir-argocd`, App ID `5179565`, created by hand; Contents, Pull requests and Metadata read; installed on `fin` only. Secret `argocd/github-app`, repo-creds for `https://github.com/arikkfir-org/fin`, from `argocd-github-app-id` and `argocd-github-app-private-key`. Argo CD finds the installation itself |
| Sign-in | The hub's interceptor guards every request ([Authentication](#authentication)): Keycloak's realm `hub`, with Google. Every route removes `Cookie` after it; the `/api` rules first copy the ID token through Middleware `id-token`, and fin-api validates it |
| Go module | `fin.kfirs.com/apps/api` (`apps/api/go.mod`). `https://fin.kfirs.com/<path>?go-get=1` returns `<meta name="go-import" content="fin.kfirs.com git https://github.com/arikkfir-org/fin">`; any other request is redirected (302) to the repository. Served on the public gateway, since Go fetches it without signing in, by Deployment, Service and ConfigMap `go-import` in namespace `go-import` (Application `go-import`, `platform/go-import/manifests` in `delivery`, wave 4): two replicas with PodDisruptionBudget `go-import` (`maxUnavailable: 1`), and NetworkPolicy `go-import` admitting only the `traefik` namespace |
| CI | Pipelines `ci` (check `Continuous Integration`: the API, the app, `deploy/` rendered as written and with `delivery`'s overrides, and the end-to-end suite), `preview` (check `Preview images`, as `ci-fin-preview`) and `release` (pushes to `main`, as `ci-fin-release`) |
