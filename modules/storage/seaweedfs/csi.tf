
module csi {
  source = "./csi"
  namespace = var.namespace
  name = "seaweedfs-csi"
  depends_on = [ helm_release.helm ]
 
}
