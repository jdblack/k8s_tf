# Forgejo used to be built by `mantle`. It is cluster infrastructure -- its own namespace, PVC,
# S3 bucket and gateway listener -- so it belongs to the stack that owns those, and `mantle` is left
# with the CI-facing half. The instance's OIDC client is created the same way, but through an
# authentik blueprint rather than the authentik provider: this stack has no provider API token, and
# a blueprint is the delivery mechanism authentik applies by itself.
module "forgejo_oidc" {
  source = "../../modules/auth/authentik/oidc_blueprint"

  namespace   = kubernetes_namespace_v1.auth.metadata[0].name
  name        = "forgejo"
  issuer_base = var.deployment.auth.server
  domain      = var.deployment.cluster.domains.private

  # The Secret has to exist before the worker mounts it, and the worker is part of the release below.
  depends_on = [kubernetes_namespace_v1.auth]
}

module "forgejo" {
  source = "../../modules/devops/forgejo/core"

  domain       = var.deployment.cluster.domains.private
  cert_issuer  = var.deployment.cert_manager.external_issuer
  host_network = var.deployment.network.host_cidr

  # Sourcing these restores the ordering edge to the gateway as well as the value.
  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  # The stack literals are the ones the running instance already has, so the rendered login_source row
  # does not move. Its sibling values come from `forgejo_oidc`, which is where the client is created.
  oidc = {
    client_id        = module.forgejo_oidc.client_id
    client_secret    = module.forgejo_oidc.client_secret
    discovery_url    = module.forgejo_oidc.discovery_url
    scopes           = "openid,email,profile,groups"
    group_claim      = "groups"
    admin_group      = "forgejo-admin"
    restricted_group = "forgejo-user"
  }

  # In `mantle` these were ordered for free by cross-stack sequencing; here they are same-stack, and the
  # submodules reach them through *defaulted string literals* rather than references, so the edges have
  # to be written down: bucket/s3_user exec into SeaweedFS, backup needs core's Velero CRDs (owned by
  # module.storage -- there is no module.backup at stack scope), and expose needs the private gateway.
  depends_on = [module.seaweedfs, module.storage, module.network]
}
