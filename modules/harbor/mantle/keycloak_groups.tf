
resource "keycloak_group" "admin" {
  realm_id = var.realm
  name = "harbor-admin"
}

