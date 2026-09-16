# Tech Context — tooling, environment, and how to actually run things

## Toolchain

- **OpenTofu** (`tofu`) — not Terraform, though the CLI is compatible.
- **`kubectl` + a kubeconfig at `~/.kube/config`** — every stack's providers
  point there, and `modules/network/api_gateway_config.tf` shells out to
  `kubectl` to install the Gateway API CRDs.
- **AWS CLI** — only for the manual Route53 drift test / inspection.
- **`~/.ssl/ca.crt` and `~/.ssl/ca.key` must exist.** `modules/cert_manager`
  reads them with `file()` **at plan time**; a missing/renamed CA fails the plan.
  They live outside the repo (generator: `~/.ssl/gencert`). Still true only
  because the module keeps creating the now-unused `linuxguru-ca` issuer —
  deleting that block is the last step of the CA retirement (see
  `activeContext.md`).
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
`deployment = { common, harbor, storage, network, auth,
metal, vpn, internal_dns, dyndns_host, media, cert,
cert_authorities, domains, argocd_devops, ... }`.

tfvars is the single source of truth for the pod/service CIDRs and the
MetalLB IPs, so renumbering the network is a one-line change, not a code edit.

- `network.pod_cidr` = Calico's range (referenced literally as `10.244.0.0/16`
  in media/qbittorrent notes).
- `metal.local_lan` → **deleted 2026-09-16** (its only readers were the deleted
  firewall modules; the key, the LAN-CIDR sentence in the `network` comment and the
  comment naming it are all gone from the tfenv — backup `k8s.tfenv.bak.20260916-201448`).
  Nothing in the `.tf` tree reads it.
- `cert` doubles as the AWS credential bucket (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` — note the v6 rename `secret_key`, not
  `secret_access_key` — `AWS_REGION`, `R53_ZONEID`).
- `cert_authorities` = `{ private = "linuxguru-ca", public = "letsencrypt",
  default = "letsencrypt" }`. **`default` is the issuer knob** (added
  2026-09-15 late): all ten `cert_issuer` arguments in core/mantle read it.
  `private` still exists but nothing references it — the CA is dormant.
- `stacks/apps` has **no** tfvars committed; create one locally:
  `deployment = { common = { domain = "vn.linuxguru.net" } }`.
- **`grep -r` cannot see this file** (it's a symlink, and recursive grep skips
  symlinked files), so a key here looks unreferenced even when it drives a
  resource. Confirm with an explicit path: `grep -n '<key>' stacks/*/terraform.tfvars`.
  Dead keys found and **deleted 2026-09-15**: `deployment.keycloak` (credentials,
  namespace, realm, realm_display) and `deployment.ldap` (org, dn) — nothing in
  the `.tf` tree read either, and authentik long ago replaced keycloak (there is
  no keycloak namespace in the cluster); plus `argocd_devops.repo_name` /
  `argocd_devops.harbor_project` and `cert.pub_cert_issuer` (the module hardcodes
  the repo display name and `…/library`; the ACME issuer name is
  `external_issuer_name`'s default). **Still dead, deliberately kept:**
  `deployment.dyndns_host` (FQDN + a copy of `cert`'s AWS keys) — it may be read
  by something outside this repo, so it stays until you're sure.
- **The tfenv is not under git**, so a bad edit there is unrecoverable — back it
  up first (`~/.tfenvs/k8s.tfenv.bak-*`). And **check for an open editor before
  editing**: `ps -eo command | grep '[v]im'` is **not sufficient** — vim shows
  the *last* file it opened, so a session sitting on `vpn.tf` can still be
  holding the tfenv as an earlier buffer. Check the swap instead:
  `lsof -p <pid> | grep k8s.tfenv.swp` (or just look for
  `~/.tfenvs/.k8s.tfenv.swp`). An outside edit lands under that stale buffer and
  the next `:w` silently reverts it — the failure is loud (`default` disappears →
  every plan errors), but it is avoidable. `:e!` that buffer before writing.

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
