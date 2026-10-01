locals {
  outpost_labels = {
    "app.kubernetes.io/name"     = "authentik-ldap"
    "app.kubernetes.io/instance" = var.outpost_name
  }

  core_url    = "http://authentik-server.${var.core_namespace}.svc.cluster.local:80"
  browser_url = "https://${coalesce(var.auth_fqdn, "auth.${var.domain}")}"

  users_dn  = "ou=users,${var.base_dn}"
  groups_dn = "ou=groups,${var.base_dn}"
  bind_dn   = "cn=${var.bind_user},${local.users_dn}"

  # What clients dial. Also the cert name when a certificate is supplied: the tls provider
  # cannot emit SANs, so anything it makes would fail hostname verification anyway.
  server_name = "${var.service_name}.${var.namespace}.svc.cluster.local"
}

data "authentik_flow" "bind" {
  slug = var.bind_flow_slug
}

data "authentik_flow" "unbind" {
  slug = var.unbind_flow_slug
}

resource "authentik_provider_ldap" "provider" {
  name        = var.outpost_name
  base_dn     = var.base_dn
  bind_flow   = data.authentik_flow.bind.id
  unbind_flow = data.authentik_flow.unbind.id
  bind_mode   = var.bind_mode
  search_mode = var.search_mode

  # Unset, the outpost serves LDAPS with a self-signed cert it generates at boot.
  certificate     = one(authentik_certificate_key_pair.ldaps[*].id)
  tls_server_name = var.certificate_pem == null ? null : local.server_name
}

resource "authentik_certificate_key_pair" "ldaps" {
  count = var.certificate_pem == null ? 0 : 1

  name             = "${var.outpost_name}-ldaps"
  certificate_data = var.certificate_pem
  key_data         = var.certificate_key_pem
}

resource "authentik_application" "app" {
  name              = var.outpost_name
  slug              = var.outpost_name
  protocol_provider = authentik_provider_ldap.provider.id
}

resource "authentik_group" "access" {
  name = var.group_name
}

resource "authentik_rbac_role" "search" {
  name = "${var.outpost_name}-search"
}

# An object permission rather than a global one: the bind user sees this provider's directory
# and nothing else, so a second provider needs its own role. The codename is qualified with its
# app label even here: guardian, underneath, always wants app_label.codename.
resource "authentik_rbac_permission_role" "search" {
  role       = authentik_rbac_role.search.id
  model      = "authentik_providers_ldap.ldapprovider"
  permission = "authentik_providers_ldap.search_full_directory"
  object_id  = authentik_provider_ldap.provider.id
}

resource "random_password" "bind_password" {
  length  = var.password_length
  special = false
}

# A plain user, not a service account: the bind flow runs the standard identification and
# password stages, which is the account type the authentik LDAP guide sets up.
resource "authentik_user" "bind" {
  username = var.bind_user
  name     = "LDAP bind"
  password = random_password.bind_password.result
  groups   = [authentik_group.access.id]
  roles    = [authentik_rbac_role.search.id]
}

# A user has to reach the application before it can bind or search the directory.
resource "authentik_policy_binding" "app" {
  target = authentik_application.app.uuid
  group  = authentik_group.access.id
  order  = 0
}

resource "authentik_outpost" "outpost" {
  name = var.outpost_name
  type = "ldap"

  # Owned here, so unlike the proxy outpost this does not need an empty list plus a later
  # attachment: the provider already exists by the time the outpost is created.
  protocol_providers = [authentik_provider_ldap.provider.id]
}
