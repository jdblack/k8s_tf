module "seaweedfs" {
  source      = "../../modules/storage/seaweedfs"
  namespace   = "kube-storage"
  cert_issuer = var.deployment.cert_authorities.default
  domains     = var.deployment["domains"]
  data_center = var.deployment.storage.data_center
}

moved {
  from = module.storage.module.egress_csi_controller
  to   = module.seaweedfs.module.csi.module.egress_csi_controller
}

moved {
  from = module.storage.module.egress_csi_node
  to   = module.seaweedfs.module.csi.module.egress_csi_node
}
