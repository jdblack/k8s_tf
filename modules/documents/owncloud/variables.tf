variable "namespace" { default = "documents" }
variable "name" { default = "owncloud" }

variable "domain" { type = string }
variable "hostname" { default = "drive" }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
variable "auth_namespace" { default = "kube-auth" }
variable "monitoring_namespace" { default = "monitoring" }

variable "helm_version" {
  type        = string
  default     = "0.8.0"
  description = "Chart version pulled from the OCI registry; publish_chart.sh tags what it pushes with this, so a bump means running it again."
}

variable "chart_registry" {
  type        = string
  default     = "oci://ghcr.io/jdblack/ocis-charts"
  description = "Where the chart is published. Owned here because upstream stopped publishing it; see publish_chart.sh."
}


variable "image_tag" { default = "8.2.0" }

variable "desktop_client_id" {
  default     = "xdXOt13JKxym1B1QcEncf2XDkLAexMBFwiT9j6EfhhHFJhs2KM9jbjTmf8JBXE69"
  description = "Client id the ownCloud desktop client has compiled in; the shipped build refuses system-config overrides, so the provider has to carry it."
}

variable "storage_class" { default = "longhorn" }
# Not really a metadata size: s3ng stages every upload on this claim before shipping the
# blob to S3, so the claim has to hold the uploads that are in flight at once, not just the
# largest one. A 5Gi default ignored that and filled up, and a full claim then fails every
# later upload with a 507 that reads as a quota error.
variable "metadata_size" { default = "15Gi" }
variable "storagesystem_size" { default = "1Gi" }
variable "nats_size" { default = "1Gi" }

# The chart names its Services after the service, not the release, so this is the bare
# name its own templates render.
variable "proxy_service_name" { default = "proxy" }
variable "proxy_port" { default = 9200 }

variable "s3_endpoint" { default = "https://s3.vn.linuxguru.net" }
variable "s3_region" { default = "seaweedfs" }
variable "s3_bucket" { default = "owncloud-storage" }

variable "ldap_uri" { type = string }
variable "ldap_bind_dn" { type = string }
variable "ldap_user_base_dn" { type = string }
variable "ldap_group_base_dn" { type = string }

variable "ldap_bind_password" {
  type      = string
  sensitive = true
}

variable "ldap_port" {
  type        = number
  default     = 6636
  description = "LDAPS port on the authentik LDAP outpost; the egress policy has to name it."
}

variable "oidc_issuer_base" {
  type        = string
  description = "authentik root URL, e.g. https://auth.example.net. The issuer is derived from it and this module's name, which is the slug the OIDC application is created with."
}

variable "metrics_enabled" { default = true }
