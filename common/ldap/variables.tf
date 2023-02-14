variable cert_issuer  {
  type = string
}
variable namespace    {
  type = string
  default = ""
}
variable release_name { 
  type = string
  default = "ldap"
}

variable ldap_domain { 
  type = string 
}
