locals {
  ldap_user = data.kubernetes_secret.ldap.data["name"]
  ldap_pass = data.kubernetes_secret.ldap.data["pass"]
}

data "kubernetes_secret" "ldap" {
  metadata {
    name = "ldap-admin"
    namespace = var.namespace
  }

}

resource "keycloak_ldap_user_federation" "ldap_user_federation" {
  name     = "openldap"
  realm_id = keycloak_realm.realm.id
  enabled  = true
  edit_mode = "WRITABLE"
  search_scope = "SUBTREE"
  full_sync_period = 1800
  changed_sync_period = 600

  username_ldap_attribute = "cn"
  rdn_ldap_attribute      = "cn"
  uuid_ldap_attribute     = "entryUUID"
  user_object_classes     = [ "inetOrgPerson" ]
  connection_url          = "ldap://ldap"
  users_dn                = "ou=users,dc=vn,dc=linuxguru,dc=net"
  bind_dn                 = "cn=${local.ldap_user},dc=vn,dc=linuxguru,dc=net"
  bind_credential         = local.ldap_pass

  connection_timeout = "5s"
  read_timeout       = "10s"

}


