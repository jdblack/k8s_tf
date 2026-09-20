variable "namespace" { type = string }
variable "velero_namespace" { default = "kube-backup" }

# The backup unit: the PVC this schedule protects. It is the schedule name, so every backup it
# makes is <target>-<timestamp>.
variable "target" { type = string }

# Must match the pod mounting the target PVC: Velero drags the claim in from the pod.
variable "selector" {
  type = map(string)

  validation {
    condition     = length(var.selector) > 0
    error_message = "A target needs a pod selector, otherwise its schedule captures the whole namespace."
  }
}

# Daily cadence is the unit of capture; thinning is the retention policy. TTL only bounds what a
# dead thinner leaves behind.
variable "cron" { default = "0 3 * * *" }
variable "ttl" { default = "2160h" }
