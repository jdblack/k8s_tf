locals {
  users_ldif = <<-EOT
    dn: cn=jblack,ou=users,dc=vn,dc=linuxguru,dc=net
    cn: jblack
    sn: James Blackwell
    Email: jblack@linuxguru.net
    objectClass: inetOrgPerson
    objectClass: top
  EOT
}

