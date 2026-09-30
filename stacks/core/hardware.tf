# Intel GPU device plugin (gpu.intel.com/i915): exposes the Alder Lake-N iGPU on the
# mini-PCs and the Iris Xe on k8smaster to pods for QuickSync/VA-API work.
module "hardware" {
  source = "../../modules/hardware"
}
