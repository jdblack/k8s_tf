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

# ★ THE MAILBOX IS THE BRAIN. `bin/mail` defaults to the PUBLIC host, and a pod cannot reach the LAN
# address that name resolves to — so a bell asks, hangs, and reports "could not ask", which looks
# exactly like an empty inbox. Measured in agent-stet 2026-10-17 (the first mail bell there).
variable "mail_me" {
  type        = string
  default     = ""
  description = "The mailbox this hand reads, i.e. the SELF's name (`stet`), not the hand's (`stet-hand`). Empty = strip `-hand` from `name`."
}

# ★ WHERE THE CODE LIVES. A hand that can commit and push is a hand whose work is not hostage to a
# human's laptop — but Forgejo is a ClusterIP in another room, and `allow_internet` deliberately
# excludes the LAN and the cluster's own services. Empty = no rule, no token, no path.
variable "forgejo_namespace" {
  type        = string
  default     = ""
  description = "Namespace hosting Forgejo. Empty = the hand cannot reach the repo at all."
}

variable "forgejo_port" {
  type    = number
  default = 3000
}

variable "forgejo_token_field" {
  type        = string
  default     = ""
  description = "Key in `secret_name` holding a Forgejo token (HTTP). Empty = no FORGEJO_TOKEN in the pod."
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

# ★ THE SELF'S FILES. Empty keeps the image-baked home, which is what a hand ran on before the claim
# existed. Setting it mounts the claim at CLINE_HOME, so `bin/` and `dist/` come from the HOME — which
# means the home must be COMPLETE before this is on (`dist/hands` is load-bearing, not build output).
variable "home_claim" {
  type        = string
  default     = ""
  description = "PVC holding the self's home, mounted at /home/node/cline-home. Empty keeps the baked home."
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
