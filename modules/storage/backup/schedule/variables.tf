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

# Daily cadence is the unit of capture; Velero's garbage collector enforces the TTL, which is the
# retention policy: one backup per day, 7 days deep.
variable "cron" { default = "0 3 * * *" }
variable "ttl" { default = "168h" }

# Offsite copies are made by the ns1 rclone job (pulls the backupstore offsite), so the per-target
# weekly schedule is disabled: an empty BSL name means the weekly resource is not created.
variable "weekly_storage_location" { default = "" }
variable "weekly_cron" { default = "0 4 * * 0" }
variable "weekly_ttl" { default = "720h" }
