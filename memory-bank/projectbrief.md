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
- **No network-policy layer (deleted 2026-09-16).** The `firewalls/` library and every
  per-app netpol were removed so every workload can reach every other one, and the
  least-privilege version that existed first was retired with them. The lone exception
  is whisker's tier CRs, which are *required* for it to work (see `memory-bank/progress.md`).
  If a policy layer is ever rebuilt, start from `.clinedocs/calico-netpols.md`.
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
