variable "namespace" {
  type        = string
  description = "Namespace the release lands in."
}

variable "name" {
  type        = string
  default     = "ellmephant"
  description = "The WORKLOAD name; the chart pins fullnameOverride to it, so the Service, PVC and selectors all share this name. Say what it is — `stet-brain`, not `stet`."
}

variable "release_name" {
  type        = string
  default     = ""
  description = "The Helm RELEASE name, which becomes app.kubernetes.io/instance. Name it after the SELF (`stet`), not the workload: the label says WHOSE the object is. Empty = the workload name, which every existing caller gets."
}

variable "domain" {
  type        = string
  description = "Domain the MCP endpoint is exposed under, at <name>.<domain>."
}

variable "cert_issuer" {
  type        = string
  description = "ClusterIssuer for the listener certificate."
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# The address, when it should not be `<name>.<domain>`. ★ Object names and addresses answer different
# questions: a workload should say WHAT IT IS (`stet-brain`), while the address someone types should
# be the self's name (`stet.vn.linuxguru.net`). Empty = derive from the name, as before.
variable "hostname" {
  type    = string
  default = ""
}

# Expose the MCP endpoint on the shared Gateway. Off leaves the Service cluster-internal.
variable "expose" {
  type    = bool
  default = true
}

# The embedder pulls its weights from the HuggingFace Hub on first use, so the pod needs internet
# egress. Turn off only with a pre-populated cache (`models.existingClaim`/`hostPath`) or offline.
variable "allow_internet" {
  type    = bool
  default = true
}

variable "mcp_port" {
  type    = number
  default = 8888
}

variable "chart_repository" { default = "oci://harbor.vn.linuxguru.net/library/charts" }
variable "chart" { default = "ellmephant" }
variable "chart_version" { default = "0.2.0" }

# The chart defaults to the upstream GHCR image; this cluster runs the Harbor mirror.
variable "image_repository" { default = "harbor.vn.linuxguru.net/library/ellmephant" }
# The tag is a CONSTANT on purpose. `edge` is what the publish workflows build for `dev`, and a
# moving tag with a constant string is what lets TF and helm agree: nothing to diff, nothing for a
# stray helm upgrade to revert. Paired with `pullPolicy = Always` in locals.tf -- without that, k8s
# reuses the cached image under a moving tag and a restart silently does nothing.
# To FREEZE a build, pin a sha-<short> here and apply: a deliberate human edit, not a pipeline's.
variable "image_tag" { default = "edge" }

variable "storage_class" { default = "" }
variable "storage_size" { default = "2Gi" }
