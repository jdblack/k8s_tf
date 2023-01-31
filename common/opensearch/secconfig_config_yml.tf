locals {
  secconfig_config_yml =  {
    _meta = {
      type= "config"
      config_version= 2
    }
    config = {
      dynamic = {
        do_not_fail_on_forbidden =  true
        http = {
          anonymous_auth_enabled: false
          xff = {
            enabled: false
            internalProxies: ""
          }
        }
        authc = {
          basic_internal_auth_domain = {
            description  = "Authenticate via HTTP Basic against internal users database"
            http_enabled =  true
            transport_enabled =  true
            order= 0
            http_authenticator = {
              type: "basic"
              challenge: true
            }
            authentication_backend = {
              type= "intern"
            }
          }
        }
      }
    }
  }
}

