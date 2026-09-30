# Node prerequisites (the HWE kernel that binds 8086:46d4, containerd's enable_cdi) are host
# state and live in ../../support/initial_setup.yml.
module "gpu_device_plugin" {
  source = "./gpu_device_plugin"

  namespace        = kubernetes_namespace_v1.kube_hardware.metadata[0].name
  image_repository = var.image_repository
  image_tag        = var.image_tag
  shared_dev_num   = var.shared_dev_num
  node_selector    = var.node_selector
}
