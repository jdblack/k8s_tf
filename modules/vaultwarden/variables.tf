variable "namespace" { default = "vaultwarden" }
variable "name" { default = "vaultwarden" }

# The PUBLIC suffix the host is served under (linuxguru.net) -- see listener.tf:
# private gateway, publicly-trusted cert.
variable "domain" { type = string }

# ClusterIssuer for the listener cert. Deliberately the PUBLIC issuer
# ("letsencrypt") even though the gateway is private: its only solver is DNS-01, so
# issuance needs no inbound reachability and clients need no private-CA install.
variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Route53 hosted zone id for the A record, passed LITERALLY (the deployment key
# is denied route53:GetHostedZone -- see ../network/dns/route53_record/README.md).
variable "zone_id" { type = string }

# The IP the private gateway's data plane holds; the A record points at it.
variable "private_gateway_ip" { type = string }

# Upstream image. Pin the tag -- no ":latest" for a secrets store.
variable "image" { default = "vaultwarden/server" }
variable "image_tag" { default = "1.37.3" }

# Container/Service port. The official image runs Rocket on 80; websockets ride
# the SAME port in 1.3x (ENABLE_WEBSOCKET), so there is no second port here.
variable "port" { default = 80 }

variable "storage_class" { default = "longhorn" }
variable "storage_size" { default = "2Gi" }

# Bootstrap only. vaultwarden has no CLI "create user": the first account is made
# through the web vault's registration form, which requires SIGNUPS_ALLOWED=true.
# Set it true, register, set it back to false -- while true, anyone who can reach
# the host (LAN or WireGuard) can create an account.
variable "signups_allowed" { default = false }
