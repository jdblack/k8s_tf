variable "namespace" {
  type        = string
  default     = "cline-home"
  description = "Cline's sandbox namespace. Namespaced, none of it cluster-scoped."
}

# The scratch PVC is a local scratchpad (longhorn RWO); the shared one is the RWX volume the pod
# and the laptop can both write (seaweedfs).
variable "scratch_storage_class" { default = "longhorn" }
variable "scratch_size" { default = "5Gi" }

variable "shared_storage_class" { default = "seaweedfs-csi" }
variable "shared_size" { default = "10Gi" }

variable "hello_image" { default = "docker.io/library/nginx:1.27-alpine" }
variable "heartbeat_image" { default = "docker.io/library/busybox:1.36" }
