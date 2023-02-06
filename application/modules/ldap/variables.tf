variable cert_issuer  {
  type = string
}
variable namespace    {
  type = string
  default = "ldap" 
}
variable release_name { 
  type = string
  default = "ldap"
}

variable ldap_org { 
  type = string
}
variable ldap_domain { 
  type = string 
}
