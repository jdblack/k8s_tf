# The S3/filer tier and its CSI driver, in the `kube-storage` namespace this module owns. It used to
# be a sibling called at stack scope; folding it in here lets `module.backup` (below/backup.tf) take a
# real ordering edge to it, since its provisioner execs into the SeaweedFS S3 pod.
module "seaweedfs" {
  source = "../../../modules/storage/seaweedfs"

  namespace   = var.namespace
  cert_issuer = var.cert_issuer
  domains     = var.domains
  data_center = var.data_center

  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  depends_on = [kubernetes_namespace_v1.storage]
}
