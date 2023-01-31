
resource "keycloak_group" "gbpn" {
  realm_id = keycloak_realm.realm.id
  name     = "gbpn"
}
