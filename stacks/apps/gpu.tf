# Intel GPU device plugin (gpu.intel.com/i915), so pods on the mini-PCs can reach the
# Alder Lake-N iGPU for QuickSync/VA-API transcoding.
#
# Two node-level prerequisites live in ../../support/initial_setup.yml rather than here,
# because they are host state, not cluster state:
#   * the HWE kernel, without which the 8086:46d4 iGPU gets no i915 binding and /dev/dri
#     never appears (6.8's i915 does not know that PCI ID);
#   * containerd's enable_cdi, without which the plugin's CDI injection silently leaves
#     /dev/dri out of the container.
#
# The plugin itself is pulled from upstream at a pinned tag by the child Application in
# deployments/gpu/; this module only creates the AppProject and the app-of-apps that syncs
# that directory.
module "gpu_deployment" {
  source = "../../modules/argo/aoa_deployment"

  # name is the AppProject and the aoa name (aoa-gpu); namespace is where the plugin runs.
  name           = var.gpu_project
  namespace      = var.gpu_namespace
  argo_namespace = var.gpu_argo_namespace

  # kube-gpu is created by the child Application's CreateNamespace sync option, so
  # terraform must not claim it too -- kubernetes_namespace_v1 would fail with "already
  # exists". Flip this to true only if the namespace is ever removed from the cluster.
  create_namespace = var.gpu_create_namespace

  deployer_repo = var.gpu_deployer_repo
  deployer_path = var.gpu_deployer_path
}
