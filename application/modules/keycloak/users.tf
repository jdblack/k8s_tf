#This has moved to ldap
#resource "keycloak_user" "jblack" {
#  realm_id = keycloak_realm.realm.id
#  username = "jblack"
#  enabled  = true
#
#  email      = "jblack@linuxguru.net"
#  email_verified = true
#  first_name = "James"
#  last_name  = "Blackwell"
#  initial_password {
#    value = "admin1"
#    temporary = true
#  }
#}
#
#resource "keycloak_user_groups" "jblack_groups" {
#  realm_id = keycloak_realm.realm.id
#  user_id = keycloak_user.jblack.id
#  exhaustive = false
#
#  group_ids  = [
#    keycloak_group.clusteradmin.id
#  ]
#}
#
#
