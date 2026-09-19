module "egress" {
  source = "../../network/firewalls/egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "velero-egress"
  allow_k8s_api = true

  # The server and node-agent both upload straight to the S3 endpoint.
  to_peers = [{
    namespace = var.seaweedfs_namespace
    ports     = [{ port = 8333 }]
  }]
}
