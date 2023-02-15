locals {
  groups_ldif = <<-EOT
    dn: ou=groups,${var.ldap_dn}
    ou: groups
    objectClass: organizationalUnit
    objectClass: top

    dn: ou=linuxguru,ou=groups,${var.ldap_dn}
    ou: linuxguru
    objectClass: organizationalUnit
    objectClass: top

    dn: ou=admin,ou=linuxguru,ou=groups,${var.ldap_dn}
    ou: admin
    member: cn=invalid
    objectClass: groupOfNames
    objectClass: top

  EOT
}


