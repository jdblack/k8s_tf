variable "namespace" { default = "vaultwarden" }
variable "name" { default = "vaultwarden" }

# The public suffix the host is served under (linuxguru.net) -- private gateway,
# publicly-trusted cert.
variable "domain" { type = string }

# DNS-01 is the issuer's only solver, so issuance needs no inbound reachability and
# clients need no private CA installed, even though the gateway is private.
variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Passed LITERALLY: the deployment key is denied route53:GetHostedZone.
variable "zone_id" { type = string }

# The A record points here. Nothing pins the VIP, so the caller reads it off the live
# gateway Service.
variable "private_gateway_ip" { type = string }

# Pin the tag -- no ":latest" for a secrets store.
variable "image" { default = "vaultwarden/server" }
variable "image_tag" { default = "1.37.3" }

# Rocket listens on 80, and websockets ride the SAME port in 1.3x (ENABLE_WEBSOCKET),
# so there is no second port here.
variable "port" { default = 80 }

variable "storage_class" { default = "longhorn" }
variable "storage_size" { default = "2Gi" }

# Bootstrap only: vaultwarden has no CLI "create user", so the first account comes from
# the web vault's registration form. While true, anyone who can reach the host (LAN or
# WireGuard) can create an account.
variable "signups_allowed" { default = false }
