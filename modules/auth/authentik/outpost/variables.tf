variable "namespace" {
  type = string
}

# authentik outpost instance name; also the pod label app.kubernetes.io/instance and
# the name in authentik's outpost health list.
variable "outpost_name" { default = "media-proxy" }

# Service/Deployment names. The protected apps' HTTPRoutes point at this service, so
# callers are wired to the same name.
variable "service_name" { default = "authentik-outpost" }

variable "image" { default = "ghcr.io/goauthentik/proxy" }
variable "image_tag" { default = "2025.10.3" }

# URL the outpost uses to talk to the authentik API/websocket (in-cluster, http is
# fine -- never seen by a browser).
variable "core_url" { type = string }

# URL used in browser-facing redirects during the OAuth dance. If empty the outpost
# falls back to core_url, leaking the internal service name into redirects -- so pass
# the public host.
variable "browser_url" { type = string }

# API token for the outpost's service account (module proxy_app output).
variable "token" {
  type      = string
  sensitive = true
}

# Namespace authentik core runs in; only egress to its pods is opened (the namespace
# firewall blocks all RFC1918 egress by default).
variable "core_namespace" { default = "kube-auth" }
