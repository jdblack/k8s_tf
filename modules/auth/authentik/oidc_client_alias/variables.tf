variable "namespace" { type = string }
variable "name" { default = "authentik-oidc-client-alias" }

# The listener that fronts authentik: the proxy's HTTPRoute attaches to the same one the
# authentik server's own route does, so a request to an aliased path lands here first.
variable "listener_name" { default = "auth" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# In-cluster address of the authentik server the proxy forwards to. The port is the Service
# port, not the container port: the server's Service exposes 80 -> 9000, and only 80 has a
# kube-proxy rule, so anything else is dropped at the ClusterIP.
variable "upstream_host" { default = "authentik-server" }
variable "upstream_port" { default = 80 }

# Paths routed through the proxy. Only authentik's authorization and token endpoints need
# rewriting; the surrounding login flow redirects to other paths that go straight to the
# server, so they are deliberately left off this list.
variable "paths" {
  type    = list(string)
  default = ["/application/o/authorize/", "/application/o/token/"]
}

# Alias client id -> canonical client id. A request that carries an alias (in the authorize
# query string, the token form body, or a Basic auth header) is rewritten to the canonical id
# before it reaches authentik; every other request is forwarded untouched.
variable "aliases" {
  type = map(string)
}

variable "image" { default = "openresty/openresty" }
variable "image_tag" { default = "1.31.1.1-3-alpine" }
