locals {
  clusterName = local.name

  opensearch_values = [ yamlencode({
    extraEnvs = [
      { 
        name = "DISABLE_INSTALL_DEMO_CONFIG"
        value = "true"
      }
    ]
    clusterName = local.clusterName
    singleNode = var.singlenode
    replicas = var.replicas
    masterService = "${local.clusterName}-master"
    persistence = {
      enabled = false
    }
    service = {
      type = var.lbtype
    }
    secretMounts = [
      {
        name = "certs"
        path = local.cert_path
        secretName = module.opensearch-cert.secret
        defaultMode = "0700"
      }
    ]

    securityConfig = {
      config = {
        data = {
          "internal_users.yml" = local.internal_users_yml
          "action_groups.yml" = local.action_groups_yml
          "config.yml" = local.secconfig_config_yml
          "nodes_dn.yml" = local.nodesdn_yml
          "roles_mapping.yml" = local.roles_mapping_yml
          "roles.yml" = local.roles_yml
          "tenants.yml" = local.tenants_yml
          "whitelist.yml" = local.whitelist_yml
        }
      }
    }
    config = {
      "opensearch.yml" =  {
        cluster = { 
          name = local.clusterName
        }
        plugins = {
          security = {
            nodes_dn = [ "CN=${local.fqdn}" ]
            restapi = {
              roles_enabled = [ "all_access", "security_rest_api_access" ]
            }

            allow_default_init_securityindex = true #FIXME Maybe redundant
            ssl = {
              transport = {
                pemcert_filepath = "tls/tls.crt"
                pemkey_filepath = "tls/tls.key"
                pemtrustedcas_filepath = "tls/ca.crt"
                enforce_hostname_verification = false
              }
              http = {
                enabled = var.TLSforLB
                pemcert_filepath = "tls/tls.crt"
                pemkey_filepath = "tls/tls.key"
                pemtrustedcas_filepath = "tls/ca.crt"
              }
            }
          }
        }
      }
    }
  })]
}

