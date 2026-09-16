# Closed floor on purpose: measured reach is this namespace + DNS, and the three API grants come from
# the sidecars' RBAC rather than from a flow -- watches never appear in a flow log.
# Ordering trap: the outpost's peer is in `mantle` while this floor is in `core`, so `mantle` applies
# first -- reversed, SSO to `admin.seaweedfs.<domain>` is down for the interval between the two.

# Namespace profile: `pod_selector` omitted on purpose, so `{}` covers every pod present and future,
# including the hook Jobs a chart upgrade leaves behind.
module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace = var.namespace
  name      = "kube-storage-baseline-egress"
}

# The provisioner/resizer/attacher sidecars: leader-election Leases and their watches.
module "egress_csi_controller" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-controller-egress"
  pod_selector  = { "app" = "seaweedfs-csi-controller" }
  allow_k8s_api = true
}

# `driver-registrar` only: it writes the driver's CRDs and events at startup, and one that cannot
# register leaves that node's volumes unresolvable -- granted, not probed for.
module "egress_csi_node" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-node-egress"
  pod_selector  = { "app" = "seaweedfs-csi-node" }
  allow_k8s_api = true
}

# Cluster-wide VolumeSnapshot reconciliation (the `longhorn-*` classes) plus its own lease; it lives
# here only because the chart ships with the Longhorn layer.
module "egress_snapshot_controller" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "snapshot-controller-egress"
  pod_selector  = { "app.kubernetes.io/name" = "snapshot-controller" }
  allow_k8s_api = true
}

# Landmine: `allow_k8s_api` reads the `kubernetes` Service and Endpoints, and `module "storage"`
# carries `depends_on = [module.network]`. Pending changes in `module.network` defer those reads and
# the apply dies with `inconsistent final plan` -- never add a `depends_on` to the calls above.
