variable "prometheus_name" { default = "prometheus" }

variable "namespace" {}
variable "cert_issuer" {}
variable "domain" {}
variable "grafana_name" { default = "grafana" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Optional ntfy alerting wiring, supplied by the caller from
# modules/monitoring/ntfy:
#
#   url               - in-cluster publish endpoint (http://ntfy/<topic>)
#   token_secret_name - Secret holding the publisher's write-only access token
#   token_secret_key  - key within that Secret holding the bare `tk_...`
#
# When set, Alertmanager gains an `ntfy` webhook receiver and the token is
# mounted as a file. Null (default) leaves Alertmanager untouched.
variable "ntfy" {
  type = object({
    url               = string
    token_secret_name = string
    token_secret_key  = string
  })
  default = null
}

