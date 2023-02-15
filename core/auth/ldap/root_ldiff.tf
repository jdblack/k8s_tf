locals {
  root_ldif = <<-EOT
    dn: ${var.ldap_dn}
    objectclass: dcObject
    objectclass: organization
    dc: ${split("=",split(",",var.ldap_dn)[0])[1]}
    o: ${var.ldap_org}


    dn: ou=users,${var.ldap_dn}
    ou: users
    objectClass: organizationalUnit
    objectClass: top

  EOT
}
