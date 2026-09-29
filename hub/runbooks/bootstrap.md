# Bootstrap runbook

Bringing the hub up from nothing, in order. Names and values: [reference](../reference.md). Designs:
[phase 1](../designs/phase-1-foundations.md), [phase 2](../designs/phase-2-octomaton.md),
[phase 3](../designs/phase-3-ingress-and-auth.md).

```mermaid
flowchart TD
  P[0. Prerequisites] --> SB[1. State bucket]
  SB --> APP[2. GitHub App]
  SB --> DS[3. Descope]
  APP --> GCP[4. terraform/gcp]
  DS --> GCP
  GCP --> SEC[5. Secret values]
  SEC --> IMG[6. First Octomaton image]
  IMG --> ACD[7. terraform/argocd]
  ACD --> VER[8. Verify platform and login]
  VER --> CI[9. Verify CI checks]
  CI --> GH[10. terraform/github: rulesets]
  GH --> CC[11. Claude Code environment]
```

## 0. Prerequisites

- `gcloud` signed in as a project owner of `arikkfir`, plus Application Default Credentials:
  `gcloud auth login && gcloud auth application-default login`.
- Terraform ≥ 1.14, `kubectl`, Go and [`ko`](https://ko.build).
- A GitHub token for Terraform with administration rights on `arikkfir-org` repositories (classic: `repo`,
  `admin:org`), exported as `GITHUB_TOKEN`.

## 1. Terraform state bucket

State for all three roots lives in `gs://arikkfir-devops`. Skip this step if the bucket already exists.

```bash
gcloud storage buckets create gs://arikkfir-devops --project=arikkfir --location=me-west1 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://arikkfir-devops --versioning
```

## 2. GitHub App

In `arikkfir-org` → Settings → Developer settings → GitHub Apps → New GitHub App:

| Field | Value |
| --- | --- |
| Name | `octomaton-dev` (`octomaton` is taken by a GitHub user) |
| Homepage URL | `https://octomaton.dev` |
| Webhook URL | `https://octomaton.dev/github/hooks` |
| Webhook secret | `openssl rand -hex 32` (keep it for step 5) |
| Repository permissions | Checks: read and write; Contents: read; Metadata: read; Pull requests: read and write; Merge queues: read |
| Events | Push, Pull request, Issue comment, Check suite, Check run, Merge group |
| Where can it be installed | Only on this account |

Then: generate a private key (download the `.pem`), note the App ID, and install the App on all repositories of
`arikkfir-org`.

## 3. Descope

Company `KFIRS`, project `development` (`P3JyPV2qsSrMLUpVPTGcBNRHlSkv`). The sign-in-only Google flow `hub-sign-in`,
the default OIDC application's login page and the first user are already configured
([phase 3](../designs/phase-3-ingress-and-auth.md#manual-setup)). Create an access key (Access keys → create) and keep
it for step 5: it is the OIDC client secret.

## 4. GCP resources

```bash
cd infra
terraform -chdir=terraform/gcp init
terraform -chdir=terraform/gcp plan    # the two DNS zones must import without changes
terraform -chdir=terraform/gcp apply
```

This creates the network, static IPs, the cluster, IAM, secret containers, Artifact Registry, buckets, the
`octomaton-dev` DNS zone and the DNS records for every hub host.

Then delegate `octomaton.dev` to its new zone: at the domain's registrar, set the name servers to the four that
`terraform -chdir=terraform/gcp output octomaton_dev_name_servers` prints. Turn DNSSEC off at the registrar first if
it's on. `dig +short NS octomaton.dev` must list them before step 7, because the Gateways wait for the
`octomaton.dev` certificate.

## 5. Secret values

```bash
add() { gcloud secrets versions add "$1" --project=arikkfir --data-file=-; }
printf '%s' "<app id>"                          | add octomaton-github-app-id
add octomaton-github-private-key               < octomaton-dev.YYYY-MM-DD.private-key.pem
printf '%s' "<webhook secret>"                  | add octomaton-github-webhook-secret
printf '%s' "<descope access key>"              | add oidc-client-secret
openssl rand -base64 32 | tr -d '\n' | tr -- '+/' '-_' | add oauth2-proxy-cookie-secret
printf '%s\n' "you@example.com" "friend@example.com" | add hub-authorized-emails
```

## 6. First Octomaton image

Octomaton builds its own releases, but the first one has to come from a workstation:

```bash
gcloud auth configure-docker me-west1-docker.pkg.dev
git clone https://github.com/arikkfir-org/octomaton && cd octomaton
git tag v0.1.0 && git push origin v0.1.0
KO_DOCKER_REPO=me-west1-docker.pkg.dev/arikkfir/images/octomaton ko build --bare --tags=v0.1.0 ./cmd/octomaton
```

## 7. Argo CD

```bash
cd infra
terraform -chdir=terraform/argocd init
terraform -chdir=terraform/argocd apply
gcloud container clusters get-credentials hub --zone=me-west1-a --project=arikkfir --dns-endpoint
kubectl -n argocd get applications -w     # everything converges to Synced / Healthy
```

## 8. Verify the platform and login

- `kubectl -n traefik get certificate wildcard-kfirs-com octomaton-dev` shows both `Ready`.
- `curl -s 'https://octomaton.dev/?go-get=1'` returns the `go-import` tag, and `https://octomaton.dev` redirects to
  the repository.
- `kubectl -n external-secrets get clustersecretstore gcp-secret-manager` is `Valid`, and every `ExternalSecret` is
  `SecretSynced`.
- `https://argocd.dev.kfirs.com`, `https://grafana.dev.kfirs.com`, `https://tekton.dev.kfirs.com`,
  `https://nui.dev.kfirs.com` and `https://traefik.dev.kfirs.com` redirect to Descope, accept an allowlisted Google
  account, and reject any other.

## 9. Verify CI

Open a pull request in any hub repository; a `ci` check run from `octomaton-dev` appears and links to the
Tekton Dashboard.

Pushes made before Octomaton ran were never delivered, so nothing is published yet. Merge a pull request (any change)
into `docs` and into `tooling` to trigger the first publish, then check
`https://docs.dev.kfirs.com/README.html` (after signing in) and `https://storage.googleapis.com/arikkfir-claude/setup.sh`.

## 10. GitHub repositories and rulesets

Only once `ci` checks work, since the rulesets require them:

```bash
cd infra
terraform -chdir=terraform/github init
terraform -chdir=terraform/github apply -var octomaton_app_id=<app id>
```

## 11. Claude Code environment

In claude.ai/code → environment settings → setup script:

```bash
curl -fsSL https://storage.googleapis.com/arikkfir-claude/setup.sh | bash
```
