# Calico Whisker (the flow-log UI) behind an authentik proxy outpost. Lives in mantle
# because it needs the authentik provider.
module "whisker" {
  source = "../../modules/network/whisker"

  namespace = "calico-system"
  domain    = var.deployment.domains.private
  # Listener cert only: the outpost validates auth.vn against public roots.
  cert_issuer = var.deployment.cert_authorities.default

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  # Add members to this group in the authentik UI to grant access.
  group_name = "platform"
}