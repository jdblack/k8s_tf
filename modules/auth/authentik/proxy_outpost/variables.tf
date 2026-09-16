# The namespace being protected: the outpost Deployment/Service/Secret live here, next to the apps.
variable "namespace" {
  type = string
}

# Each key becomes the application/provider slug (sonarr, radarr, ...).
variable "apps" {
  type = map(object({
    # Public URL the gateway serves; also the provider's external_host.
    external_host = string
    # The app's in-cluster Service, which the outpost proxies to.
    internal_host = string
    # Bookmark-tile icon URL; null leaves it unset.
    icon = optional(string)
  }))
}

# authentik outpost name; also the pod label app.kubernetes.io/instance and the name in the health list.
variable "outpost_name" { default = "media-proxy" }

# The protected apps' HTTPRoutes point at this Service, so callers share the name.
variable "service_name" { default = "authentik-outpost" }

variable "group_name" { default = "media" }

# Cluster domain: the public authentik host is derived as auth.<domain>.
variable "domain" { type = string }

# Only for the day the public authentik host is not auth.<domain>.
variable "auth_fqdn" {
  type    = string
  default = null
}

# Core's namespace: the outpost's only cross-namespace egress target.
variable "core_namespace" { default = "kube-auth" }

variable "image" { default = "ghcr.io/goauthentik/proxy" }

# Left at the version the outposts were first deployed with: the proxy image is versioned separately
# from the server (see stacks/core/auth.tf) and was not part of the 2026.8.2 upgrade. Bump it as its own
# change and verify the outposts reconnect afterwards.
variable "image_tag" { default = "2025.10.3" }
