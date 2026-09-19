variable "namespace" { type = string }
variable "velero_namespace" { default = "kube-backup" }

# Tiers to enrol this namespace in; the cron/TTL policy lives in locals.tf.
variable "tiers" {
  type    = list(string)
  default = []
}
