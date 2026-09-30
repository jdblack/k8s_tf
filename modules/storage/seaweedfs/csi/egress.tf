module "egress_csi_controller" {
  source    = "../../../network/firewalls/policy"
  direction = "egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-controller-egress"
  pod_selector  = { "app" = "seaweedfs-csi-controller" }
  allow_k8s_api = true
}

module "egress_csi_node" {
  source    = "../../../network/firewalls/policy"
  direction = "egress"

  namespace     = var.namespace
  name          = "seaweedfs-csi-node-egress"
  pod_selector  = { "app" = "seaweedfs-csi-node" }
  allow_k8s_api = true
}
