module "owncloud" {
  source = "./owncloud"

  namespace   = kubernetes_namespace_v1.namespace.metadata[0].name
  domain      = var.domain
  hostname    = var.hostname
  cert_issuer = var.cert_issuer

  gateway_name         = var.gateway_name
  gateway_namespace    = var.gateway_namespace
  auth_namespace       = var.auth_namespace
  monitoring_namespace = var.monitoring_namespace

  ldap_uri           = var.ldap_uri
  ldap_bind_dn       = var.ldap_bind_dn
  ldap_bind_password = var.ldap_bind_password
  ldap_user_base_dn  = var.ldap_user_base_dn
  ldap_group_base_dn = var.ldap_group_base_dn

  oidc_issuer_base = var.oidc_issuer_base

  # The document server oCIS opens documents in. Referenced by the module output so the
  # server rolls out before the oCIS chart, whose collaboration service reads its
  # discovery endpoint at startup.
  onlyoffice_url = "https://${module.onlyoffice.fqdn}"

  # Named here so the baseline egress policy above can exclude the purge pod.
  trash_purge_name = local.trash_purge

  # The namespace has to exist before the app's claims, Secrets and policies land in it.
  depends_on = [kubernetes_namespace_v1.namespace]
}
