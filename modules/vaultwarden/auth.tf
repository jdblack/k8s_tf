# Dashboard tile only: vaultwarden authenticates its own users, so the app carries no
# SSO provider. Name and slug match the tile that was created by hand in authentik.
resource "authentik_application" "app" {
  name            = "Vaultwarden"
  slug            = "vault"
  meta_launch_url = "https://${local.fqdn}"
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/vaultwarden.svg"
}

resource "authentik_group" "admin" {
  name = "${var.name}-admin"
}

resource "authentik_group" "user" {
  name = "${var.name}-user"
}

# Both groups, as with the OIDC apps, so an admin need not also join -user to see the tile.
resource "authentik_policy_binding" "own_groups" {
  for_each = {
    admin = authentik_group.admin.id
    user  = authentik_group.user.id
  }

  target = authentik_application.app.uuid
  group  = each.value
  order  = 0
}

