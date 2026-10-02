# oCIS fetches its OIDC discovery document and JWKS from the issuer, and every blob from
# the S3 endpoint, and both names resolve to the shared gateway -- which is a MetalLB
# address, so the peer is the gateway pod the address DNATs to, not the address itself.
module "egress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "owncloud-gateway-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}

# The directory itself, on the outpost's unprivileged LDAPS port.
module "egress_ldap" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "owncloud-ldap-egress"

  peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik-ldap" }
    ports        = [{ port = var.ldap_port }]
  }]
}

# Plugin installs fetch from the internet, which the namespace baseline (DNS and self
# only) does not admit.
module "egress_internet" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace      = var.namespace
  name           = "owncloud-internet-egress"
  allow_internet = true
}
