variable "namespace" {
  type = string
}

# authentik outpost name; also the pod label app.kubernetes.io/instance and the name in
# authentik's outpost health list.
variable "outpost_name" { default = "media-proxy" }

# The protected apps' HTTPRoutes point at this Service, so callers share the name.
variable "service_name" { default = "authentik-outpost" }

variable "image" { default = "ghcr.io/goauthentik/proxy" }
variable "image_tag" { default = "2025.10.3" }

# In-cluster, so http is fine -- never seen by a browser.
variable "core_url" { type = string }

# If empty the outpost falls back to core_url, leaking the internal service name into
# browser-facing redirects -- so pass the public host.
variable "browser_url" { type = string }

variable "token" {
  type      = string
  sensitive = true
}

# Only egress to its pods is opened; the namespace firewall blocks RFC1918 by default.
variable "core_namespace" { default = "kube-auth" }
