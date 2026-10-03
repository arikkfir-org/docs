# Claude Code cluster access

Claude Code on the web sessions read the hub cluster, its objects, events and pod logs, through GKE's remote MCP server, as service account `claude-code@`. Sessions never get a kubeconfig, and nothing they run changes the cluster. Tracked in ENG-69.

## Why

A session diagnosed a deployment from the outside only: when `https://fin.kfirs.com` answered 404, it could tell that Traefik had no route, but not whether Argo CD had created Application `go-import`, or what stopped it.

kubectl can't reach the cluster from a session. The cluster answers only on its DNS-based endpoint (`*.gke.goog`), and the sessions' proxy adds the Google credential only to requests for `*.googleapis.com`. gcloud has no login of its own in a session either. GKE's remote MCP server, `https://container.googleapis.com/mcp`, is under `*.googleapis.com`, so the credential the proxy already adds authenticates it, and nothing is left to configure in a session.

## Design

```mermaid
flowchart LR
  S[Claude Code session] -->|MCP server gke, read tools only| P[Session proxy]
  P -->|adds claude-code@'s credential| M[container.googleapis.com/mcp]
  M -->|claude-code@'s IAM| K[GKE cluster hub]
```

| Piece | Value |
| --- | --- |
| Identity | `claude-code@arikkfir.iam.gserviceaccount.com`, made by hand; the Claude Code environment holds its key, and its proxy adds it to requests for `*.googleapis.com` |
| Roles (`infra`, `terraform/gcp`) | `roles/viewer`: reads the project, the cluster's objects and pod logs included, but no Kubernetes Secret or Secret Manager payload, and changes nothing. `roles/mcp.toolUser`: calls Google's MCP servers' tools |
| MCP server (`tooling`'s bundle) | `gke`, `https://container.googleapis.com/mcp`, at user scope in every session |
| Without a prompt | its read tools: `get_*`, `list_*`, `describe_*` and `check_*` |
| Denied | its write tools: `apply_*`, `patch_*`, `delete_*`, `create_*`, `update_*` and `cancel_*`, which IAM refuses as well |

## Risks

- The key reads the whole project, ConfigMaps and logs included. Revoke it by disabling or deleting the key of `claude-code@`.
- Google may rename the MCP server's tools; a renamed read tool then asks for permission, and a renamed write tool is still refused by IAM.
