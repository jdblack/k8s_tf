# `stacks/apps` — ArgoCD app-of-apps

OpenTofu stack whose only job is to hand deployments to ArgoCD. It creates an
`AppProject` plus an app-of-apps `Application` per workload via
[`modules/argo/aoa_deployment`](../../modules/argo/aoa_deployment), and ArgoCD
then syncs everything the referenced repo path contains.

- State: Kubernetes secret backend in `kube-system`, `secret_suffix =
  "deployment"` — the Secret is `tfstate-default-deployment`. The **stale
  `tfstate-default-fuckbatz` Secret** from the parked wordpress deployment below
  was deleted on 2026-09-15, along with its `lock-tfstate-default-fuckbatz` Lease.
- **This stack's state lock was stuck** (2026-09-15): the
  `lock-tfstate-default-deployment` Lease in the k8s backend (a
  `coordination.k8s.io` Lease — which is why it is *not* visible in the state
  Secret, and why `kubectl get secret` looked innocent) held a `plan` lock from
  2026-08-29, so `plan` and `apply` both failed with "state is already locked".
  `force-unlock` cleared it that night; all three stacks now plan `No changes`,
  and this stack's refresh is what proves it owns the `ai` namespace:
  `module.ai_deployment.kubernetes_namespace_v1.namespace[0]  [id=ai]` (core's
  duplicate declaration of that namespace was removed the same night).
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

## Parked: the wordpress deployment

`ngoc_website.tf.disabled` is the origin of this stack: a module call into
`git::https://github.com/Linuxgurus/wordpress.git//terraform` — a module that
takes `ingress_class` and expects the old nginx ingress classes — so it was
disabled when the cluster moved to Gateway API. Reviving it means porting that
module to `gateway/expose` (ListenerSet + HTTPRoute) and passing a working cert
issuer — `cert_authorities.default` (`letsencrypt`, DNS-01; the old
`letsencrypt-http` is long gone and `linuxguru-ca` is dormant).

There was a **second** one, `notbatz.com_website.tf.disabled` (module
`fuckbatz_website`, `fuckbatz` namespace, `www.notbatz.com`). It was deleted
2026-09-15: `notbatz.com` has no Route53 zone here at all (only `linuxguru.net`
and `emtho.com` do), so the site never had a working DNS path in this account,
and its config would have been dead on arrival anyway — dead issuer, dead ingress
class. Its state Secret, lock Lease and 81 MB module cache went with it.

By contrast `emtho.com` **is** a zone in this account, so the `ngoc_website`
file above is left parked rather than deleted — it's the only record of that
site's definition.

The module repo's own `./build` script (bump chart version → commit/push →
package and push the chart) still applies if you go back to it.

## Inputs

There is no `terraform.tfvars` here — it's in `.gitignore` and this stack's copy
was never force-added, unlike core/mantle's (both of which are symlinks into
`~/.tfenvs/k8s.tfenv`). So pass the tfenv explicitly:

```sh
tofu -chdir=stacks/apps plan -var-file=~/.tfenvs/k8s.tfenv
```

Only `deployment` is read from it, so a hand-rolled tfvars would need just:

```hcl
deployment = {
  common = { domain = "vn.linuxguru.net" }
}
```

Variables (`variables.tf`): `deployment` (required), `argo_namespace` (`argo`),
`argo_auth_secret` (`argocd-initial-admin-secret`), `argo_cd_server` (empty →
the domain fallback), and the `ai_*` set (`ai_namespace`, `ai_create_namespace`,
`ai_argo_namespace`, `ai_deployer_repo`, `ai_deployer_path`).
