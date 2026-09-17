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
- **Policy is a namespace-scoped curtain first, then holes — one call = one object, in
  `network/firewalls/`: `egress`, `egress_peer`, `ingress`.** The direction the curtain drops is
  chosen by which way the namespace is dangerous: risky **to** the cluster (media's internet-facing
  apps) → drop **egress**; at risk **from** the cluster (storage, the IdP) → drop **ingress**. Then
  open what the namespace actually needs, at namespace or pod granularity, whichever is appropriate.
  A call renders one typed `kubernetes_network_policy_v1`, so `plan` sees drift. Egress has DNS and
  own-namespace always on, everything else behind an explicit switch (`allow_k8s_api`,
  `allow_cluster`, `allow_internet`, `to_namespaces`, `to_cidrs`); ingress has own-namespace and
  **the node addresses** always on — kubelet probes and the apiserver's own calls into a pod arrive
  from the node, so that one is a floor, not a switch. **Self-talk stays open and one namespace is
  one object** — the reader's working set is the real constraint, so rules must earn their place.
  **A pod worse than its namespace** (plex and qbittorrent, internet-exposed while `media` as a
  whole is not) is carved out of the namespace's holes and given its own. Ordering between our own
  policies is irrelevant — they union inside tier `default` — and a brief cutover outage is
  accepted; only two orderings are not ours to waive (the `egress/data.tf` deferred read, and the
  operator's tier-100 deny). Call sites today: egress in `media`, `blender`, `vaultwarden`,
  `kube-storage`, `kube-certificates`, `argo`, `devops-harbor`; ingress in `kube-storage` and
  `longhorn-system`. Whisker's tier CRs are separate and load-bearing, not a restriction
  (`modules/network/whisker/tier.tf`).
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
