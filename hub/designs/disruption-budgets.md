# Disruption budgets

**Decision**: every service the others depend on runs two replicas, spread over nodes when the pool has several, with
a PodDisruptionBudget of `maxUnavailable: 1`. That covers Traefik, oauth2-proxy, the docs site, Grafana, Octomaton and
its `go-import` page, and KEDA's three components. NATS keeps its chart's budget over three servers. Grafana moves its
state from a SQLite file on its own volume to a shared PostgreSQL database (Cloud SQL), so that two replicas can run.
Facts:
[reference](../reference.md#kubernetes-platform). Pull requests:
[delivery#12](https://github.com/arikkfir-org/delivery/pull/12),
[octomaton#11](https://github.com/arikkfir-org/octomaton/pull/11); Grafana:
[infra#14](https://github.com/arikkfir-org/infra/pull/14),
[delivery#13](https://github.com/arikkfir-org/delivery/pull/13).

## Context

GKE drains nodes on purpose. It drains the old node in a surge upgrade, and the cluster autoscaler drains a node it
removes. A drain evicts pods, and a service with one replica is down until its pod runs again elsewhere, which takes an
image pull, a start and a readiness probe. For Traefik and oauth2-proxy that is every request. For Octomaton it is
GitHub's webhook deliveries, which GitHub doesn't retry on its own. Before this change only NATS had a budget.

## Design

```mermaid
sequenceDiagram
  autonumber
  participant G as GKE (upgrade or autoscaler)
  participant O as draining node
  participant B as PodDisruptionBudget (maxUnavailable 1)
  participant N as another node
  G->>O: cordon
  G->>B: evict replica A?
  B-->>G: yes, B is ready
  O->>N: A starts again (the autoscaler adds a node if none has room)
  G->>B: evict replica B?
  B-->>G: no, A isn't ready yet
  N-->>B: A is ready
  G->>B: evict replica B?
  B-->>G: yes
```

| Service | Replicas | Budget | Defined in | Why several replicas work |
| --- | --- | --- | --- | --- |
| Traefik | 2 | `maxUnavailable: 1` | `delivery`: `platform/traefik/values.yaml` | Stateless; both serve both load balancers |
| oauth2-proxy | 2 | `maxUnavailable: 1` | `delivery`: `platform/auth/values.yaml` | Sessions live in cookies |
| Docs site | 2 | `maxUnavailable: 1` | `delivery`: `platform/docs/manifests/` | Each pod mounts the bucket read-only |
| Octomaton | 2 | `maxUnavailable: 1` | `octomaton`: `deploy/` | Every replica serves webhooks; the Lease holder reports, schedules and cleans up |
| `go-import` | 2 | `maxUnavailable: 1` | `octomaton`: `deploy/` | Static answers |
| KEDA operator, metrics server, webhooks | 2 each | `maxUnavailable: 1` each | `delivery`: `platform/keda/values.yaml` | KEDA keeps one operator and one metrics server active and the other on standby; both webhook replicas serve |
| NATS | 3 | `maxUnavailable: 1` (the chart's) | `delivery`: `platform/nats/values.yaml` | JetStream keeps a quorum with two of three servers |
| Grafana | 2 | `maxUnavailable: 1` | `delivery`: `platform/grafana/`; the database in `infra`: `terraform/gcp/sql.tf` | State in PostgreSQL, shared; alert state gossiped between the replicas, so each alert notifies once |

The replicas spread by host with `whenUnsatisfiable: ScheduleAnyway`. They land on different nodes when the system
pool has several, and share one otherwise, instead of making the pool grow. A drain still keeps one replica serving
with a single node: the evicted replica waits for room, which the autoscaler adds, and the budget holds the second until
the first is ready.

The extra replicas request about 0.4 CPU and 0.5Gi of memory on the system pool, mostly KEDA's. Traefik and
oauth2-proxy request nothing (their charts' defaults).

### Grafana on PostgreSQL

```mermaid
flowchart LR
  T[Traefik] --> G1[grafana replica]
  T --> G2[grafana replica]
  G1 <-->|gossip 9094| G2
  G1 -- "postgres.hub.internal:5432, TLS" --> SQL[(Cloud SQL hub<br/>database grafana)]
  G2 --> SQL
  ESO[ExternalSecret grafana-db] -. password .-> G1
  ESO -. password .-> G2
  SQL --- PSA[range peered-services<br/>10.40.0.0/20]
```

- The instance `hub` runs PostgreSQL 18 on the Enterprise edition's smallest tier (`db-f1-micro`). It is zonal, next
  to the cluster, and costs about $12 a month with its disk and backups. It has a private address only, from a range
  peered into the VPC, and refuses unencrypted connections.
- Pods reach it by name: `postgres.hub.internal` is a record in a private Cloud DNS zone visible to the VPC, which
  GKE's cluster DNS resolves. Its address is assigned at creation, so `delivery` doesn't hard-code it.
- Terraform creates the instance and the database `grafana`. The owner creates the user `grafana` and its password by
  hand, like every secret value, and puts the password in Secret Manager for ExternalSecret `grafana-db`.
- Two replicas share sessions, users, dashboards and alert rules through the database. Their alert managers gossip
  over Service `grafana-headless` (port 9094), so an alert notifies once. The NetworkPolicy admits that gossip between
  Grafana's own pods only.

## Decisions

| Decision | Why | Rejected |
| --- | --- | --- |
| Two replicas and `maxUnavailable: 1` | One replica always serves through a drain, and the budget stays right at any replica count | `minAvailable: 1`: the same at two replicas, but it blocks every drain if a service drops to one |
| No budget for a single replica | A budget on one pod either blocks drains (GKE waits up to an hour per node, then evicts anyway) or protects nothing | Budgets everywhere |
| Soft spread by host | Keeps the system pool at the size its load needs | Required anti-affinity: one node per replica, so a pool of at least two nodes |
| Traefik and oauth2-proxy too, though not first on the list | Every other service is reached through them; the others' budgets would protect nothing without them | Leaving them single |
| KEDA made ready now, though nothing scales through it yet | It is the hub's autoscaler for workloads to come, and it is cheap | Waiting for the first ScaledObject |
| Grafana on a Cloud SQL PostgreSQL | Two replicas need a shared database; Cloud SQL runs, patches and backs it up | Grafana stateless with dashboards only as code (UI edits lost on restart); a PostgreSQL in the cluster (an operator to run, its own volumes and budget); Grafana single, without a budget |
| A private address and a private DNS name | No public endpoint, and `delivery` names the database without knowing its address | The Cloud SQL Auth Proxy as a sidecar (a container per replica, and it would need a Google service account for IAM logins, which the hub doesn't use) |
| Users and passwords by hand | Like every secret value in the hub: Terraform state never holds one | A Terraform-generated password (it would sit in state) |
| `db-f1-micro` | About 25 connections and 0.6GB are plenty for Grafana; the cheapest tier | `db-g1-small` (about three times the cost), when Grafana outgrows it |

## Security and failure modes

- Budgets cover voluntary disruptions only. A node crash still takes every replica on it, and with one system node
  that is all of them.
- GKE honours a budget for up to an hour per node during an upgrade, then drains anyway.
- Permissions don't change. The network policies select pods by label, and the new replicas carry the same labels;
  Grafana's also admits its own pods on the gossip port.
- Grafana now depends on the database. The instance is zonal and has no standby, so Grafana is down while Cloud SQL
  restarts it: maintenance (Sundays at 02:00 UTC) or a zone failure. Grafana is a UI; nothing else waits on it.

## Rollout

1. Merge this pull request (the reference).
2. Merge the `delivery` and `octomaton` budget pull requests in any order. Argo CD scales each service to two and
   creates its budget. Nothing restarts except where a pod template changed (the spread constraint).
3. Grafana, in order:
   1. Merge the `infra` pull request and apply `terraform/gcp`. It creates the peering, the instance (several minutes),
      the database, the private zone and the secret container.
   2. Create the user and store its password (the `infra` README, "PostgreSQL"):

      ```bash
      pw="$(openssl rand -base64 32 | tr -d '\n')"
      gcloud sql users create grafana --instance=hub --password="$pw"
      printf %s "$pw" | gcloud secrets versions add grafana-db-password --data-file=-
      ```

   3. Export anything made in Grafana's UI that you want to keep (dashboards as JSON, alert rules from Alerting's
      export). The SQLite data doesn't move: users come back on their first sign-in, and the data source is
      provisioned.
   4. Merge the `delivery` Grafana pull request. The new replicas start on PostgreSQL. The old pod keeps serving until
      they are ready, then goes, and Argo CD deletes its volume.
   5. Import what you exported.
4. Check: `kubectl get pdb -A` lists `traefik`, `auth-oauth2-proxy`, `docs`, `grafana`, `octomaton`, `go-import`, the
   three KEDA budgets and `nats`, each allowing one disruption.

## Open questions

- Grafana's dashboards and alert rules could also live in Git (provisioned from `delivery`), so the database holds
  only what is made in the UI.
