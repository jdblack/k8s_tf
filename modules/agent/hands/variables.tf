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
