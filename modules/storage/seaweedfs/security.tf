# SeaweedFS is exposed to a deliberately small peer set: its own namespace, the
# shared gateways in kube-network (there is NO LoadBalancer on seaweed itself) and
# monitoring (ServiceMonitor scrapes). Everything else reaches storage through the
# CSI driver, which runs inside this namespace.
module "firewall" {
  source = "../../network/firewalls/limited_ingress"

  namespace = var.namespace

  allowed_ingress_namespaces = [
    var.namespace,
    "kube-network",
    "monitoring",
  ]
}

# Egress: this namespace only (master/filer/volume <-> s3 and csi-mount, plus the admin UI
# talking to the filer) + cluster DNS + the API. No internet; no other namespace.
#
# The API carve-out is for the CSI driver: csi-controller/csi-node are controllers and watch
# PVCs/PVs, so without it every new volume stays unprovisioned. The authentik outpost in
# here is governed by its own pod-scoped egress policy (stacks/mantle, module
# storage/seaweedfs_admin); policies union, so this namespace-wide one only ever adds.
#
# policy_name differs from the ingress policy above, which owns "namespace-firewall".
module "firewall_egress" {
  source           = "../../network/firewalls/basic_egress"
  namespace        = var.namespace
  policy_name      = "namespace-egress"
  allow_namespaces = [var.namespace]
  allow_k8s_api    = true
}

