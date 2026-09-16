# `kube-storage`'s egress: one namespace profile and three API exceptions. This namespace backs
# every SeaweedFS-CSI PVC and the Longhorn snapshot path, so the profile is the narrowest shape the
# builder has -- own namespace + DNS, and nothing else. No internet, no LAN, no other namespace, no
# API server except where a controller provably holds one.
#
#   kube-storage-baseline-egress     podSelector: {}                            own namespace + DNS
#   seaweedfs-csi-controller-egress  app=seaweedfs-csi-controller               + the API server
#   seaweedfs-csi-node-egress        app=seaweedfs-csi-node                     + the API server
#   snapshot-controller-egress       app.kubernetes.io/name=snapshot-controller + the API server
#
# Measured, not assumed. A 30-day Whisker window for this namespace holds 39 flows in six shapes, all
# of them intra-namespace or DNS:
#   filer/volume/worker/csi-mount -> seaweedfs-volume:8080, :18080   volume data + its gRPC twin
#   volume/worker                 -> seaweedfs-master:19333          master gRPC
#   worker/csi-mount              -> seaweedfs-filer:18888           filer gRPC
#   every one of the above        -> coredns:53/udp
#   seaweedfs-admin-auth          -> seaweedfs-admin:23646           the outpost proxying the UI
#   seaweedfs-admin-auth          -> kube-auth/authentik-server:9000  the only cross-namespace peer
# That last peer is NOT here: it belongs to the outpost, is stated per-pod in
# `seaweedfs_admin/egress.tf`, and is deliberately one pod on one port rather than `kube-auth`
# wholesale. Everything else in the list is the self rule plus the always-on DNS rule, so this
# profile grants exactly what the namespace was observed to use.
#
# No `allow_internet`, unlike `media`. Nothing here fetches from off-cluster at runtime: the
# SeaweedFS images, the CSI sidecars and the worker's job data all arrive in-cluster, and image pulls
# belong to the kubelet rather than to any pod netns. A grant here would be one nothing measured asks
# for, and a namespace-wide one can never be taken back per-pod.
#
# The three API grants are a construction argument (watches over long-lived connections are not
# emitted into flow logs -- see `.clinedocs/flow-logs.md`), read off the sidecars' own RBAC:
#   - csi-provisioner / csi-resizer / csi-attacher all run with `--leader-election` (Leases) and
#     watch PVs, PVCs, StorageClasses and VolumeAttachments;
#   - the node DaemonSet's `driver-registrar` is the one holder of *write* verbs in the CSI RBAC:
#     `customresourcedefinitions create|delete` at startup and `events` CRUD beside it;
#   - snapshot-controller (`--leader-election=true`) watches and writes the whole
#     snapshot.storage.k8s.io surface cluster-wide -- the Longhorn `longhorn-snapshot` /
#     `longhorn-backup` classes are reconciled by it, so it is a cluster component that happens to
#     live in this namespace.
# Selectors are the chart's own plain `app=` labels (the CSI chart sets no `app.kubernetes.io/*` on
# its pods), checked live.
#
# What deliberately does NOT get the API, and why RBAC is not the test: the chart binds
# `seaweedfs-rw-cr` (pods get|list|watch|create|update|patch|delete) to the SA that master, volume
# and filer run as, and binds the read-only CSI roles to the SA the DaemonSets run as. RBAC a chart
# ships is not traffic a pod makes. Checked per pod, `/proc/net/tcp` + `/proc/net/tcp6` hold no
# socket to the apiserver (0x192B = 6443) in master, volume, filer, admin, s3, worker, csi-node or
# csi-mount, and no `weed` process carries a k8s flag in `/proc/1/cmdline` (`master -port=9333
# -mdir=/data -peers=...`, `volume -port=8080 -master=...`, `s3 -filer=...`): every peer they name is
# in this namespace. The method has a blind spot worth remembering -- a socket table shows long-lived
# and in-flight connections, not a *write-once* call, which is exactly why the registrar above gets
# its grant from its RBAC rather than from a clean socket table.
#
# Ordering, since the rule elsewhere is "namespace-wide calls last": inside this stack the four calls
# land in ONE apply, so the only order that can bite is *across* stacks. The outpost's peer lives in
# `mantle` (`seaweedfs_admin/egress.tf`) while the floor that covers that pod lives here, so `mantle`
# was applied FIRST: reversed, the outpost would have sat on the floor alone between the two applies
# and SSO to `admin.seaweedfs.<domain>` would have been down for the interval. The rule exists because
# a floor added before its namespace's per-pod calls is a cutover to DNS + self that breaks every peer
# nobody has measured yet.

# The namespace profile, and the only call here that is not about one workload. `pod_selector` is
# omitted on purpose: empty renders `podSelector: {}` -- every pod in the namespace, present and
# future, including the CSI DaemonSets, the hook Jobs a chart upgrade leaves behind and any
# hand-made debug box. That is what closes the fall-through to Kubernetes' default-allow namespace
# profile (`kns.kube-storage`: LAN, gateway VIP, API server, internet) -- the same reason `media`
# grew a floor.
module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace = var.namespace
  name      = "kube-storage-baseline-egress"
}

# CSI controller: the provisioner/resizer/attacher sidecars' leader-election Leases and watches, plus
# the plugin's dial to the filer (in-namespace, the floor's job).
module "egress_csi_controller" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-controller-egress"
  pod_selector  = { "app" = "seaweedfs-csi-controller" }
  allow_k8s_api = true
}

# CSI node DaemonSet, for `driver-registrar` alone: it writes the driver's CRDs and events through the
# API at startup. Losing this is not a cosmetic failure -- a registrar that cannot register leaves the
# node without the driver and the volumes mounted there stop resolving -- so it is granted rather
# than probed for. The `seaweedfs-csi-mount` DaemonSet beside it uses the same SA and is NOT granted:
# it holds no API socket, its job is the fuse mount, and its peers (filer, volume) are in this
# namespace.
module "egress_csi_node" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-node-egress"
  pod_selector  = { "app" = "seaweedfs-csi-node" }
  allow_k8s_api = true
}

# snapshot-controller: cluster-wide VolumeSnapshot reconciliation (the `longhorn-*` classes) plus its
# own leader-election Lease. It lives here because the chart rolls out with the Longhorn/snapshot
# layer, not because its traffic is storage-local.
module "egress_snapshot_controller" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "snapshot-controller-egress"
  pod_selector  = { "app.kubernetes.io/name" = "snapshot-controller" }
  allow_k8s_api = true
}

# Landmine to respect when editing this file: `allow_k8s_api` makes the egress module read the
# `kubernetes` Service and its Endpoints, and `module "storage"` carries
# `depends_on = [module.network]` in `stacks/core`. If a plan ever has pending changes in
# `module.network`, those reads defer, the peer count becomes a guess and the apply dies with
# `inconsistent final plan` (2026-09-16). Do not add a `depends_on` to the calls above.

# to DNS + self that breaks every peer nobody has measured yet.
