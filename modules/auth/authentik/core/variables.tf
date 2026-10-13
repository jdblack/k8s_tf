variable "namespace" { type = string }
variable "name" { default = "authentik" }

variable "helm_version" { default = "2026.8.2" }

variable "pod_cidr" { type = string }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "outpost_namespaces" {
  type    = list(string)
  default = ["media", "kube-storage", "calico-system", "monitoring"]
}

# The LDAP outpost is a separate pod on its own ports, so a namespace that reads the
# directory is not the same thing as one running a proxy outpost.
variable "ldap_client_namespaces" {
  type        = list(string)
  default     = []
  description = "Namespaces whose pods read the directory through the LDAP outpost. Without this the egress side can be perfect and every search still times out, because this policy governs the outpost too."
}

variable "extra_blueprints" {
  type        = list(string)
  default     = []
  description = "Extra k8s Secrets to mount as blueprints, by name. Each Secret's keys must be .yaml files or the worker mounts them and never applies them; this is a list of names, so it cannot express the key. Empty by default, which renders the same helm values as before this input existed."
}

variable "ldap_ports" {
  type        = list(number)
  default     = [3389, 6636]
  description = "Ports the LDAP outpost serves on. Must match ldap_port and ldaps_port in modules/auth/authentik/ldap_outpost."
}
