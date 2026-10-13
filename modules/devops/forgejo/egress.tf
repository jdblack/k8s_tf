# Baseline: DNS and this namespace only.
module "egress" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "${var.name}-egress"
}

# Both authentik (OIDC discovery, JWKS, token exchange) and SeaweedFS S3 (s3.<domain>) sit
# behind the private gateway, so one peer covers both: the gateway pod the address DNATs to,
# not the address itself.
module "egress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "${var.name}-gateway-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.auth_gateway_name }
    ports        = [{ port = 443 }]
  }]
}

# Outbound git (mirrors, imports, webhooks) needs the public internet, which the namespace
# baseline (DNS and self only) does not admit.
module "egress_internet" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace      = var.namespace
  name           = "${var.name}-internet-egress"
  allow_internet = true
}
