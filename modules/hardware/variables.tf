variable "namespace" { default = "kube-hardware" }
variable "image_repository" { default = "intel/intel-gpu-plugin" }
variable "image_tag" { default = "0.37.0" }

# Slots per node. Upstream defaults to 1, i.e. one pod holding the whole iGPU.
variable "shared_dev_num" { default = 10 }

variable "node_selector" { default = { "kubernetes.io/arch" = "amd64" } }
