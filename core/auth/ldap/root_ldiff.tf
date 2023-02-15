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

    dn: ou=groups,${var.ldap_dn}
    ou: groups
    objectClass: organizationalUnit
    objectClass: top

    dn: cn=clusteradmin,ou=groups,${var.ldap_dn}
    cn: clusteradmin
    objectclass: groupOfNames
    objectclass: top
    member: cn=nobody

    dn: cn=grafana-editor,ou=groups,${var.ldap_dn}
    cn: grafana-editor
    objectclass: groupOfNames
    objectclass: top
    member: cn=nobody

    dn: cn=grafana-admin,ou=groups,${var.ldap_dn}
    cn: grafana-admin
    objectclass: groupOfNames
    objectclass: top
    member: cn=nobody

  EOT
}
