# Namespace traffic may leave for DNS and itself and nothing else. oCIS reaches the
# gateway, S3 and LDAP through the peers declared in the owncloud module.
module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "documents-baseline-egress"
  allow_internet = false
}
