# Project Brief — Kubernetes Terraform (a.k.a. `k8s/terraform`)

**What this is:** the single source of truth for one home-lab Kubernetes
cluster's own configuration — network, storage, certs, identity, monitoring,
platform services and the workloads on top. The OS, kubeadm and Calico's data
plane are **not** managed here.

**Tool:** OpenTofu (`tofu`), three root modules under `stacks/`, applied in order.

**Location / VCS:** `/Users/jblack/code/k8s/terraform`, branch `main`
(`origin/main` is the tracked branch; a stale `master`/`v0` exist locally).

## Goals

- Rebuild-from-scratch is fully `tofu apply`-driven, in the documented stack
  order, with no hand-run `kubectl apply` step for anything this repo owns.
- `tofu plan` is the drift check. Resources are typed (`kubernetes_*`) rather
  than `kubectl_manifest` on purpose, so out-of-band edits show as diffs.
- **Policy is per-pod, opt-in, and lives in `network/firewalls/`: `egress`, `egress_peer`,
  `ingress`.** The whole firewall layer was deleted 2026-09-16 and rebuilt narrower from
  2026-09-17: one call renders one typed `kubernetes_network_policy_v1`, so `plan` sees drift.
  Egress has DNS and own-namespace always on, everything else behind an explicit switch
  (`allow_k8s_api`, `allow_cluster`, `allow_internet`, `to_namespaces`, `to_cidrs`); ingress has
  own-namespace and **the node addresses** always on — kubelet probes and the apiserver's own calls
  into a pod arrive from the node, so that one is a floor, not a switch — and every guest named
  explicitly. A namespace is covered only when its **observed** traffic justifies a profile
  (Whisker flows; plus, for ingress, the live HTTPRoutes and Prometheus's `up{}`, because a scrape
  holds its connection open and never appears in a flow), so this tightens named pods rather than
  walling anything off — pods no policy selects stay open. Ingress went live in `kube-storage`
  (2026-09-17) and is the only namespace with one. Whisker's tier CRs are
  separate and load-bearing, not a restriction (`modules/network/whisker/tier.tf`).
- Version-pin every chart you touch.

## Non-goals / explicitly out of scope

- The host OS, kubeadm, the Calico data plane.
- People: authentik group *membership* is hand-managed in the UI ("Terraform
  owns structure, the UI owns people").
- The `ai` namespace's contents (owned by the external
  `jdblack/argo-linuxguru` app-of-apps repo); `stacks/apps` only files the
  ArgoCD `Application`.

## Scope note

This memory bank is an **index, not a copy**. The repo already has dense,
high-quality docs (root `README.md`, `memory-bank/progress.md`, per-module `README.md`,
`.clinedocs/`, `.clinerules/`). Read the narrowest of those first; the memory
bank tells you *which* one and captures state that has no other home.
