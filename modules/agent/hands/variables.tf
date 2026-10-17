variable "namespace" {
  type        = string
  description = "The self's room. A hand runs in the room of the brain it serves — compute can be borrowed, identity cannot."
}

variable "name" {
  type        = string
  default     = "hand"
  description = "Workload name; the Service and the doorbell hostname derive from it."
}

variable "domain" {
  type = string
}

variable "hostname" {
  type        = string
  default     = null
  description = "Full door hostname; default <name>.<domain>."
}

variable "cert_issuer" {
  type    = string
  default = ""
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}

variable "expose" {
  type        = bool
  default     = true
  description = "Publish the doorbell on the gateway. Off keeps the CronJobs (they need no door) while nothing outside the namespace can ring it."
}

# ★ THE BRAIN, SAME NAMESPACE. This is what a self's room buys: a ClusterIP name, no gateway hop,
# no cross-namespace policy. `bin/store` reads ELLMEPHANT_URL, so the URL must end in `/mcp`.
variable "brain_url" {
  type        = string
  description = "e.g. http://stet.agent-stet.svc.cluster.local:8888/mcp"
}

variable "brain_health_url" {
  type        = string
  default     = ""
  description = "Where the maintenance predicate asks for the store's snapshot age. Defaults to brain_url with /health."
}

variable "image_repository" {
  type    = string
  default = "harbor.vn.linuxguru.net/library/cline-hand"
}

variable "image_tag" {
  type        = string
  default     = "0.1.3"
  description = "★ The image bakes bin/, so a code change needs a NEW TAG; pullPolicy is Always so a restart actually moves."
}

variable "port" {
  type    = number
  default = 8600
}

# The model credential and the door token. ★ CREATED OUT OF BAND, never in state: a secret that lives
# in tfvars ends up in the state file and in every plan.
variable "secret_name" {
  type = string
}

variable "model_key_field" {
  type    = string
  default = "deepSeekApiKey"
}

variable "door_token_field" {
  type    = string
  default = "doorToken"
}

# ★ WHO THE FINGER SPEAKS FOR. Empty = no identity, which is only right for a hand that never writes:
# an anonymous finger's `claim_acquire` is refused whenever `ELLMEPHANT_LEASERS` names a real identity.
# Setting this WITHOUT the secret field present is the failure mode to avoid — the pod dies at
# CreateContainerConfigError rather than writing anonymously, which is the loud failure we want.
variable "identity" {
  type        = string
  default     = ""
  description = "The proven identity this hand writes as, e.g. `hands`. Empty disables identity entirely."
}

# The key in `secret_name` that holds THIS identity's proof (the value, not the `name:secret` table).
variable "identity_secret_field" {
  type        = string
  default     = "handsIdentitySecret"
  description = "Secret key carrying the raw X-Stet-Auth value for `identity`."
}

variable "cpu_request" {
  type    = string
  default = "100m"
}

variable "memory_request" {
  type    = string
  default = "256Mi"
}

variable "memory_limit" {
  type    = string
  default = "2Gi"
}

# The roster. A CronJob is a BELL: it runs `bin/hands --activity <name>`, whose predicate costs
# nothing, so a bell with no grounds spends nothing. The activities themselves live in CODE.
variable "activities" {
  type = map(object({
    schedule = string
    suspend  = optional(bool, false)
  }))
  default = {}
}
