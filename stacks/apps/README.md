# `stacks/apps` — ArgoCD app-of-apps

OpenTofu stack whose only job is to hand deployments to ArgoCD. It creates an
`AppProject` plus an app-of-apps `Application` per workload via
[`modules/argo/aoa_deployment`](../../modules/argo/aoa_deployment), and ArgoCD
then syncs everything the referenced repo path contains.

- State: Kubernetes secret backend in `kube-system`, `secret_suffix =
  "deployment"` — the Secret is `tfstate-default-deployment`. A **stale
  `tfstate-default-fuckbatz` Secret** also sits there from the parked wordpress
  deployment below: unreferenced, and safe to delete with
  `kubectl -n kube-system delete secret tfstate-default-fuckbatz`.
- Providers: `argocd` (pointed at `argo-cd.<domain>:443`, or `var.argo_cd_server`
  when set) plus `kubernetes`/`helm`. The ArgoCD admin password comes from the
  `argocd-initial-admin-secret` in the `argo` namespace.
- Depends on `stacks/core` (Argo CD itself) and `stacks/mantle` (its OIDC clients
  and repo credentials) already being applied.

## What it deploys today

| Module call | Namespace | Project | Repo / path |
|---|---|---|---|
| `ai.tf` → `aoa_deployment` | `ai` | `ai` | `git@github.com:jdblack/argo-linuxguru.git`, `deployments/ai` |

The generated `Application` is `aoa-ai`, syncing with `automated { prune,
self_heal, allow_empty }`; the `AppProject` `ai` grants the `argo-cd-admin` and
`argo-cd-admin-ai` groups admin access to it (those groups live in authentik —
see the main README's "Terraform owns structure, the UI owns people").

Everything *inside* `ai` is owned by that external repo, not by this one. As
applied today it syncs three more Applications — `ollama` (helm chart
`otwld/ollama-helm`), `corsless` and `llm-embedder` (Helm OCI charts from Harbor)
— and their manifests create `ollama.vn.linuxguru.net`'s ListenerSet/HTTPRoute.
That host has **no authentik in front of it**; see the main README's hostname
table. Deleting the module here would drop the ArgoCD Application, not the
cluster objects (`prune` on the app-of-apps handles those).

## Parked: the wordpress deployments

`ngoc_website.tf.disabled` and `notbatz.com_website.tf.disabled` are the origin
of this stack. Both were module calls into
`git::https://github.com/Linuxgurus/wordpress.git//terraform` — a module that
takes `ingress_class` and expects the old nginx ingress classes — so they were
disabled when the cluster moved to Gateway API. Reviving one means porting that
module to `gateway/expose` (ListenerSet + HTTPRoute) and a working cert issuer
(`letsencrypt-http` no longer exists; the issuers are `letsencrypt`, DNS-01, and
`linuxguru-ca`).

The module repo's own `./build` script (bump chart version → commit/push →
package and push the chart) still applies if you go back to it.

## Inputs

No `terraform.tfvars` is committed here (`terraform.tfvars` is in `.gitignore`,
and `stacks/apps`'s copy was never force-added like core/mantle's). Create one
locally before planning:

```hcl
deployment = {
  common = { domain = "vn.linuxguru.net" }
}
```

Variables (`variables.tf`): `deployment` (required), `argo_namespace` (`argo`),
`argo_auth_secret` (`argocd-initial-admin-secret`), `argo_cd_server` (empty →
the domain fallback), and the `ai_*` set (`ai_namespace`, `ai_create_namespace`,
`ai_argo_namespace`, `ai_deployer_repo`, `ai_deployer_path`).
