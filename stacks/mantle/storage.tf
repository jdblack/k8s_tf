# The SeaweedFS admin UI behind an authentik proxy outpost. The release and its
# Services are core's (stacks/core/storage.tf); the SSO gate has to live here because
# only mantle has the authentik provider -- so apply core before mantle.
module "seaweedfs_admin" {
  source = "../../modules/storage/seaweedfs_admin"

  namespace = "kube-storage"
  domain    = var.deployment.domains.private
  # Listener cert only: the outpost validates auth.vn against public roots.
  cert_issuer = var.deployment.cert_authorities.default

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  # This module OWNS the "storage" group; add members in the authentik UI to grant
  # access. Any future storage app joins this same group.
  group_name = "storage"
}
