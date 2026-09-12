# Calico Whisker (the flow-log UI) exposed like the media apps: HTTPS on the
# shared private gateway, fronted by an authentik proxy outpost, with
# pod-scoped NetworkPolicies so no other cluster pod can read the flow data
# directly. Lives in the mantle stack because it needs the authentik provider.
module "whisker" {
  source = "../../modules/network/whisker"

  namespace   = "calico-system"
  domain      = var.deployment.domains.private
  cert_issuer = var.deployment.cert_authorities.private

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  # Add members to this group in the authentik UI to grant access.
  group_name = "platform"
}