resource "keycloak_realm" "realm" {
  realm             = var.realm
  enabled           = true
  display_name      = var.realm_display
  display_name_html = "<b>${var.realm_display}</b>"
  access_token_lifespan = "1h"
  access_token_lifespan_for_implicit_flow = "1h"
  sso_session_idle_timeout = "24h"
  sso_session_idle_timeout_remember_me = "336h"
  sso_session_max_lifespan = "48h"
  sso_session_max_lifespan_remember_me = "720h"
  lifecycle {
    ignore_changes = [
      account_theme,
      email_theme,
      admin_theme,
      login_theme
    ]
  }
}

resource "keycloak_group" "clusteradmin" {
  realm_id = keycloak_realm.realm.id
  name     = "clusteradmin"
}

