# Tech Context — tooling, environment, and how to actually run things

## Toolchain

- **OpenTofu** (`tofu`) — not Terraform, though the CLI is compatible.
- **`kubectl` + a kubeconfig at `~/.kube/config`** — every stack's providers
  point there, and `modules/network/api_gateway_config.tf` shells out to
  `kubectl` to install the Gateway API CRDs.
- **AWS CLI** — only for the manual Route53 drift test / inspection.
- **`~/.ssl/ca.crt` and `~/.ssl/ca.key` must exist.** `modules/cert_manager`
  reads them with `file()` **at plan time**; a missing/renamed CA fails the plan.
  They live outside the repo (generator: `~/.ssl/gencert`).
- Host: macOS (darwin/arm64), providers in `.terraform.lock.hcl` are
  `darwin_arm64`.

## Providers in use

| Stack | Providers |
|---|---|
| core | `kubernetes` 3.0.1, `helm`, `kubectl` 1.19.0, `random` |
| mantle | + `harbor` 3.10.17, `argocd` 7.12.4, `authentik` 2025.10.1, `aws` ~> 6.0 |
| apps | + `argocd` 7.12.4 |

## State

Kubernetes Secret backend, **no remote backend to bootstrap**:

```hcl
backend "kubernetes" {
  namespace     = "kube-system"
  secret_suffix = "core"        # / "mantle" / "deployment"
  config_path   = "~/.kube/config"
}
```

## Inputs

`stacks/<stack>/terraform.tfvars` is a **symlink to `/Users/jblack/.tfenvs/k8s.tfenv`**
(outside the repo, so the secret-bearing file is single-sourced). Structure:
`deployment = { common, harbor, storage, network_ingress, network, ldap, auth,
keycloak, metal, vpn, internal_dns, dyndns_host, media, cert,
cert_authorities, domains, argocd_devops, ... }`.

tfvars is the single source of truth for the LAN CIDR, pod/service CIDRs and the
MetalLB IPs, so renumbering the network is a one-line change, not a code edit.

- `network.pod_cidr` = Calico's range (referenced literally as `10.244.0.0/16`
  in media/qbittorrent notes).
- `network_ingress.public_ip` / `private_ip` → the pinned gateway data-plane IPs.
- `metal.local_lan` → the non-pod source range allowed into LoadBalancer-fronted
  namespaces.
- `cert` doubles as the AWS credential bucket (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` — note the v6 rename `secret_key`, not
  `secret_access_key` — `AWS_REGION`, `R53_ZONEID`).
- `stacks/apps` has **no** tfvars committed; create one locally:
  `deployment = { common = { domain = "vn.linuxguru.net" } }`.
- `deployment.dyndns_host` in `k8s.tfenv` is dead config — no `.tf` references it.

## Run / validate

```sh
tofu -chdir=stacks/core   init && tofu -chdir=stacks/core   apply
tofu -chdir=stacks/mantle init && tofu -chdir=stacks/mantle apply
tofu -chdir=stacks/apps   init && tofu -chdir=stacks/apps   apply
```

- **`tofu plan` is the drift check** — and the primary validation for a change.
- **Never use `-target`/`-exclude`** except to recover from a specific error.
- No CI, no linter, no test framework. Validation = `tofu validate`, then
  `tofu plan` in the affected stack(s), then live checks (`kubectl`, `dig`,
  `curl`, `openssl s_client`, `dns-sd`).
- `tofu fmt` for formatting; HCL style in this repo is `snake_case` vars,
  `var.name`, `terraform_data` for one-shot shell bootstrap steps.
