# System Patterns — architecture and the patterns you must follow

## Layout

```
stacks/{core,mantle,apps}/      # root modules, applied in that order
modules/
├── network/        Calico, MetalLB, external-dns, shared NGF gateways,
│                   Gateway API CRD bootstrap, wireguard, whisker
│   ├── gateway/    one NGF instance per call; submodules listener_set,
│   │               http_route, expose (= listener_set + http_route)
│   ├── whisker/    flow-log UI; tier.tf = the Calico CRs that work around the
│   │               operator's own deny tier (not a restriction on whisker)
│   ├── firewalls/  NetworkPolicy builders, one policy per call: egress/ (per pod
│   │               profile), egress_peer/ (ns + pod + port), ingress/ (Ingress-only)
│   └── dns/route53_record/
├── storage/        Longhorn (+VolumeSnapshotClasses), SeaweedFS
│                   (helm, CSI, listeners, dashboard), seaweedfs_admin
├── cert_manager/   cert-manager + linuxguru-ca + letsencrypt (Route53 DNS-01)
├── auth/authentik/ core, proxy_outpost, oidc_provider
├── monitoring/     prometheus (kube-prometheus-stack), grafana_oidc,
│                   metrics_server, smartctl
├── harbor/         core (release+listener), mantle (projects+OIDC)
├── argo/           core (Argo CD), mantle (SSO/deploy key, workflows, events),
│                   aoa_deployment (app-of-apps generator, apps stack)
├── media/          arr stack + plex + qbittorrent + media-private gateway
├── blender/        Samba on the LAN + mDNS/Bonjour advertiser
└── vaultwarden/    Bitwarden-compatible server + its Route53 A record
```

## Pattern: each app owns its exposure

`modules/<mod>/listener.tf` calls `network/gateway/expose`, which renders the
app's HTTPS `ListenerSet` (annotated with the cert-manager issuer, so
`cert-<fqdn>` is auto-provisioned) plus an `HTTPRoute` (host → Service) and any
cross-namespace `ReferenceGrant`. Charts that render their own route
(harbor, authentik, argo-cd) omit `backend_name` and get the listener only.
Outpost-fronted apps point `route_name = "<app>-auth"` at the outpost service.

- Certs and secrets live with the services that use them; no hand-written
  `Certificate` anywhere.
- One host can move off the default issuer without moving its namespace: the shim
  re-issues in place because the Certificate is named after the listener's Secret.
- **One name for the issuer: `cert_authorities.default`** (tfvars; `letsencrypt`
  today). Every module takes a plain `cert_issuer` string and each of the ten call
  sites in core/mantle passes that key, so switching one host — or all of them —
  back to the CA is a value change, not a plumbing change. The `cert_issuers` maps
  (media per-app override, seaweedfs visibility-keyed) and `local.issuers` were
  deleted 2026-09-15.
- **No module injects a CA any more (2026-09-15).** All 19 hosts are on
  `letsencrypt`; the four that used to mount the private CA (`harbor`, `grafana`,
  `argo-wf`, `argo-cd`) validate authentik against the container's own public
  roots. Per-consumer injection checklist (Argo CD first) and the
  same-apply rule for bundle-replacing knobs: `modules/cert_manager/README.md`.
- **Apps deployed from the external `argo-linuxguru` repo (the `ai` project)
  own their exposure in their own chart values instead** — they aren't TF
  modules, so `gateway/expose` can't reach them. `extraObjects` in the
  Application's `valuesObject` carries the ListenerSet + `ReferenceGrant` +
  `HTTPRoute` (the `otwld/ollama-helm` convention); both local charts
  (`corsless-helm`, `llm-embedder-chart`) now ship
  `templates/extraObjects.yaml` to render it. Those charts publish to Harbor
  project **`library`** (`library/<app>` + `library/<chart>`), not `linuxguru`.
  ArgoCD reaches the charts through `argocd_repository.devops_helm`
  (`modules/argo/mantle/argo-cd/repositories.tf`), whose Terraform id **is the
  repo URL** and whose Secret lands as `argo/repo-<fnv32a(repo_url)>` — so
  changing the project in one place without the other shows up as a permanent
  `1 to add` in `tofu plan`, and hand-editing the Secret's `url` desyncs it.
- `hostname` overrides for sub-subdomains (`admin.seaweedfs.<domain>`).

## Pattern: namespace curtain first, holes at namespace or pod granularity

Three builders in `modules/network/firewalls/`, each rendering exactly one
`kubernetes_network_policy_v1` (typed, so `plan` sees drift): **`egress`** (`policyTypes: ["Egress"]`,
per pod profile), **`egress_peer`** (one namespace + pod selector + port, the shape `to_namespaces`
cannot say), and **`ingress`** (`policyTypes: ["Ingress"]`, added 2026-09-17). Egress defaults: DNS
(`UDP+TCP/53` → `kube-system`/`k8s-app=kube-dns`) and the pod's own namespace on; every other peer an
explicit switch (`allow_k8s_api`, `allow_cluster`, `allow_internet`) or list (`to_namespaces`,
`to_cidrs`). Ingress defaults: that same self rule **plus the node addresses** (`allow_nodes`) —
kubelet probes and the apiserver's own calls into a pod arrive from the node, so without it every
governed pod goes NotReady. A caller passes `pod_selector` so a policy scopes named pods, and **omits
it for the namespace-wide object** — the shape that closes the fall-through instead of leaving it
open. That fall-through (`kns.<ns>`: allow-all, both directions, all 18 namespaces) is the default
this layer exists to replace; the per-pod shape tightens named targets, and the namespace-wide shape
is the curtain those targets are holes in (`media`, `kube-storage`).

- **Curtain first, holes found cheaply after.** The curtain goes down on the threat direction; the
  holes are then read off real traffic (`module`'s README + `.clinedocs/flow-logs.md`), one call per
  pod profile, with a different `pod_selector` where profiles differ. Measuring is how you *find* the
  holes, not a gate to pass before building — curtaining first is what makes the outliers surface as
  breakage instead of being guessed at. **A scrape breaks the recipe:** a connection held open is
  never emitted, so Prometheus is found in `up{namespace=...}`, not in a flow (measured 2026-09-17 —
  13/13 targets up, zero flow records on `:9327`).
- **Ingress has no safe default shape, so the first one took three sources.** A policy that types
  `Ingress` is deny-all-inbound for the pods it selects, and `kube-storage-baseline-ingress` was
  written only after its guests came from the flows, the live HTTPRoutes (peer *and* ports) and `up{}`
  — and it has **no CIDR peer**, because every Service in that namespace is ClusterIP, which makes the
  gateway pod the only door an off-cluster client can come through and lets a pod selector name that
  door exactly.
- **Port-scoped cross-namespace peering is `egress_peer`** (`{namespace, pod_selector, port}`), and it
  is what every narrow peer in the repo uses — both co-located outpost peers (`media`,
  `seaweedfs_admin`), harbor-core, and argo's three gateway peers (six calls; whisker's outpost peer
  is a Calico tier CR instead). `to_namespaces` on its own grants the whole namespace on every port,
  which is why **no call site uses it**; the ingress builder carries the same shape as `from_peers`.
- **Reaching the LAN is a CIDR peer**, `to_cidrs = [var.deployment.network.host_cidr]` — the only
  declaration of the LAN anywhere; a published hostname resolves to the gateway VIP inside it, not
  to a namespace peer.
- Whisker's tier CRs are the other half and are *not* a restriction: `modules/network/whisker/tier.tf`
  exists because the operator's own tier would otherwise deny that namespace outright.


## Hard Calico invariants (expensive to get wrong)

- Both directions are evaluated **POST-DNAT**: an egress rule matches the *endpoint* IP (a ClusterIP is
  never a peer), and an ingress rule's `ports` are the **destination pod's** own ports — the gateway
  reaches the authentik outpost on `:9000`, never its TLS `:9443`, and the pod selector on the peer is
  the *gateway's* data-plane pod, not a VIP.
- **A scrape is a guest you cannot see.** Prometheus holds its connection open, so no flow record is
  ever emitted for it: `up{namespace=...}`, not Whisker, is where scrape guests are found
  (`.clinedocs/flow-logs.md`).
- **Guests come from real flow data** (Goldmane/Whisker), never from guessing: see
  `.clinedocs/flow-logs.md`, and note the result set is capped, so a widened time window
  under-reports instead of over-reporting.
- A module-level `depends_on` covers a module's **data sources**, and a deferred
  read makes its consumer's plan a lie: a policy that read the `kubernetes`
  Endpoints object *inside* the module planned a guessed peer count (ClusterIP
  only) and the apply died with `inconsistent final plan` (2026-09-16). The fix
  that time was to read it in the **stack root** (`stacks/core/core.tf`) and pass
  the peer IPs down — never hardcode control-plane IPs. **Live again now:**
  `firewalls/egress/data.tf` reads the `kubernetes` Service and Endpoints whenever
  `allow_k8s_api = true`, so a caller that grows a `depends_on` over a pending
  change re-arms the landmine.
- k8s netpols only UNION → an operator-shipped netpol cannot be tightened.
  tigera's `goldmane` allows any source on 7443; unfixable from TF.
- The apiserver calls webhooks/aggregation from a **remote node** → those paths
  need the **node CIDR** in the guest list, which the ingress curtain's `allow_nodes`
  floor grants by default (InternalIP + the `tunl0` address, per node). **The `etp`
  half of this claim was inverted and is corrected 2026-09-17:** a `etp=Cluster`
  LoadBalancer has its client SNAT'd to a node address before the pod sees it, so it
  lands *inside* that floor — `blender-samba`, the only Cluster one here, reads as
  `PRIVATE NETWORK` in the flow, i.e. an in-cluster address, not the LAN client. It is
  `etp=Local` (media, both gateways) that preserves the real client IP, so *that* is
  the shape an explicit CIDR guest has to name. End-to-end confirmation is the pending
  `blender` ingress call (`activeContext.md` § The policy layer), not a commit.
- `calicoctl` on PATH is **3.32.0 vs cluster v3.32.2 → refuses to run**. Pass
  `--allow-version-mismatch` on every call (re-verified 2026-09-17; the env var does NOT work).

## Other conventions

- **Terraform owns structure (groups, apps, bindings); the UI owns people.**
  Rebuild needs group members re-added by hand.
- **Pin charts — done repo-wide (2026-09-16); every `helm_release` carries a `version`.** The
  awk audit in `progress.md` is the check (config → `grep`/awk, deployed → `state show` or
  `helm list`, upstream → `helm show chart` with no `--version`). Current pins, where they differ
  from what you'd guess: NGF `2.7.1` (all three releases together), kube-prometheus-stack
  `91.4.1`, Longhorn `1.12.1`, SeaweedFS `4.40.0` + CSI `0.2.35`, authentik `2026.8.2`,
  cert-manager `v1.21.2`, tigera-operator `v3.32.2`, external-dns `1.22.0`, argo-cd `10.9.1`,
  argo-events `2.4.27`, argo-workflows `2.0.6`, MetalLB `0.16.1`, wireguard-operator `0.3.0`,
  and the media charts. **Still behind upstream:** seaweedfs + CSI, and the arr patches. Bump one
  at a time, and read the plan for a **6-space** `version` line only — every touched release also
  emits `~ version`/`~ app_version` inside its `metadata` block.
- **Dashboards ship from the owning module** as `grafana_dashboard: "1"`
  ConfigMaps (mirrors ServiceMonitors); Grafana keys them by `uid`.
- **`checksum/config`** on pod templates when a Secret/ConfigMap should roll the
  pod (vaultwarden, blender mdns).
- **Snapshots are cluster policy, joined by Volume-CR labels.** Longhorn matches a
  `RecurringJob` to a volume by `recurring-job-group.longhorn.io/<group>` on the
  **Volume CR** (`RecurringJob.spec` has `groups`; there is no volume list), so the
  labels are written once — `modules/storage/snapshot_labeler.tf` — and *no PVC
  carries them*: a PVC with those labels **replaces** its volume's entire group set
  instead of merging, silently de-enrolling it. Never list the `default` group in a
  job (every newly provisioned unlabelled volume lands in it), and re-run the
  labeler (`-replace` of one address) after deleting a job or moving a volume
  between tiers. Reverting a snapshot needs **maintenance mode**, because
  `spec.disableFrontend` is derived from the VolumeAttachment tickets and not from
  the Volume CR, and the manager API answers **in-cluster only**. Runbook with the
  verified commands: `modules/storage/disaster_recovery.md`.
- `.clinedocs/` holds deep, non-obvious operational notes (flow queries, netpol
  invariants) — load only when working that area.
