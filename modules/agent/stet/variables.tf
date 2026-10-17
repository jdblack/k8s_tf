variable "namespace" {
  type        = string
  default     = "agent-stet"
  description = "The self's room. A self = a namespace = a brain + its hands."
}

variable "name" {
  type        = string
  default     = "stet"
  description = "The BRAIN takes the self's name (the app is `ellmephant`, the instance is `stet`), and so does its hostname."
}

variable "domain" {
  type = string
}

variable "cert_issuer" {
  type = string
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "storage_class" {
  type    = string
  default = ""
}

variable "storage_size" {
  type        = string
  default     = "2Gi"
  description = "★ The DATABASE is ~6.5 MB; nearly all of this is the embedder model cache, which re-downloads."
}

# ★ THE FILES, which are small and numerous. Separate claim from the database on purpose: a restore
# of the brain must not be able to overwrite the home, and vice versa.
variable "home_size" {
  type        = string
  default     = "10Gi"
  description = "The self's home: tools, notes, work, inbox. Text and scripts, not media."
}

variable "home_storage_class" {
  type        = string
  default     = "longhorn"
  description = "RWO is enough: only the hand reads the home, and a filer costs 48x per metadata op (measured)."
}

variable "chart_version" {
  type    = string
  default = "0.2.0"
}

variable "image_tag" {
  type    = string
  default = "edge"
}

# The model key + the door token, in one Secret this module creates (see secret.tf). ★ Read from FILES
# on the applying machine, never from tfvars: the key already lives at 600 under ~/.cline/secrets.
variable "secret_name" {
  type    = string
  default = "stet-secrets"
}

variable "model_key_file" {
  type    = string
  default = "~/.cline/secrets/deepseek-hands"
}

variable "door_token_file" {
  type    = string
  default = "~/.cline/secrets/stet-door-token"
}

variable "model_key_field" {
  type    = string
  default = "deepSeekApiKey"
}

variable "door_token_field" {
  type    = string
  default = "doorToken"
}

variable "extra_env" {
  type        = any
  default     = []
  description = "Extra env vars for the brain (passed straight to the chart's `env`)."
}

variable "hands_image_tag" {
  type    = string
  default = "0.1.3"
}

variable "hands_expose" {
  type        = bool
  default     = true
  description = "Publish the doorbell at <name>-hand.<domain>."
}

variable "hands_identity" {
  type        = string
  default     = "hands"
  description = "★ The proven identity the finger writes as; empty disables it (and its leases are then refused under a leaser allowlist)."
}

variable "hands_identity_file" {
  type        = string
  default     = "~/.cline/secrets/identity-hands"
  description = "File holding the raw proof for `hands_identity`. Optional: an existing Secret's `data` is ignored, so a rotation is a file edit + `kubectl delete secret` + re-apply."
}

variable "activities" {
  type = map(object({
    schedule = string
    suspend  = optional(bool, false)
  }))
  default = {}
}

variable "backup_cron" {
  type        = string
  default     = "0 18 * * *"
  description = "★ 18:00 UTC is 01:00 local — quiet AND off-peak. The old store's 03:30 line was my busiest hour, which is the worst possible time to copy a live database."
}
