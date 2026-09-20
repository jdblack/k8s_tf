variable "namespace" { type = string }
variable "velero_namespace" { default = "kube-backup" }

# The backup unit: the PVC this schedule protects. Becomes <target>-<tier>.
variable "target" { type = string }

# Must match the pod mounting the target PVC: Velero drags the claim in from the pod.
variable "selector" {
  type = map(string)

  validation {
    condition     = length(var.selector) > 0
    error_message = "A target needs a pod selector, otherwise its schedule captures the whole namespace."
  }
}

# Tiers to enrol this target in; the cron/TTL policy lives in locals.tf.
variable "tiers" {
  type    = list(string)
  default = []
}

# Per-tier TTL overrides, e.g. { daily = "720h" }.
variable "ttl_overrides" {
  type    = map(string)
  default = {}
}
