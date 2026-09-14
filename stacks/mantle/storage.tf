# SeaweedFS admin UI (`weed admin`) behind authentik, exactly like the media
# apps and whisker: HTTPS on the shared private gateway + an authentik proxy
# outpost in front. The release and its Services are core's
# (stacks/core/storage.tf); the SSO gate has to live here because only mantle
# has the authentik provider. On a fresh build apply core before mantle.
module "seaweedfs_admin" {
  source = "../../modules/storage/seaweedfs_admin"

  namespace = "kube-storage"
  domain    = var.deployment.domains.private
  # Leaf cert only: the authentik outpost in front validates auth.vn against
  # the private CA, not this host's cert.
  cert_issuer = var.deployment.cert_authorities.public

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  # This module OWNS the "storage" group (it creates it); add members in the
  # authentik UI to grant access. Any future storage app joins this same group.
  group_name = "storage"
}
