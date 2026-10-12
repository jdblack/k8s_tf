variable "namespace" {
  type        = string
  description = "Namespace the release lands in."
}

variable "name" {
  type        = string
  default     = "ellmephant"
  description = "Release name; the chart pins fullnameOverride to it, so the Service, PVC and selectors all share this name."
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
# `edge` is what harbor-publish.sh mirrors; pin a sha-<short> tag to freeze a build.
# Pinned 2026-10-13 to the memory_useful trigger fix (feedback nudge fires).
variable "image_tag" { default = "sha-62a62ed" }

variable "storage_class" { default = "" }
variable "storage_size" { default = "2Gi" }
