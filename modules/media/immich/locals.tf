locals {
  fqdn = "${var.name}.${var.domain}"

  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/"
  icon     = var.icon == null ? "${local.icon_cdn}${var.name}.svg" : (var.icon == "" ? null : var.icon)

  uid = 1000
  gid = 1000

  pod_security_context = { runAsUser = local.uid, runAsGroup = local.gid, fsGroup = local.gid }

  postgres_name = "${var.name}-postgres"

  server_name = "${var.name}-server"
  server_port = 2283

  # Only the keys that differ from Immich's defaults: an omitted key stays UI-editable.
  oauth = {
    enabled      = true
    issuerUrl    = "https://auth.${var.domain}/application/o/${var.name}/"
    clientId     = module.auth.client_id
    clientSecret = module.auth.client_secret

    autoRegister = true
    autoLaunch   = false
    buttonText   = "Sign in with Authentik"
  }

  helm_values = {
    defaultPodOptions = { securityContext = local.pod_security_context }

    immich = {
      persistence       = { library = { existingClaim = var.library_pvc } }
      metrics           = { enabled = var.metrics_enabled }
      configurationKind = "Secret"
      configuration     = { oauth = local.oauth }
    }

    server = {
      controllers = {
        main = {
          containers = {
            main = {
              image = { tag = var.image_tag }
              env = {
                IMMICH_MEDIA_LOCATION = "/data"
                DB_HOSTNAME           = module.postgres.host
                DB_USERNAME           = module.postgres.user
                DB_DATABASE_NAME      = module.postgres.database
                DB_PASSWORD = {
                  valueFrom = { secretKeyRef = { name = module.postgres.password_secret, key = "password" } }
                }
              }
            }
          }
        }
      }
      persistence = {
        # Type is chart-schema-mandated; the claim is the library itself, so no subPath.
        data = {
          type          = "persistentVolumeClaim"
          existingClaim = var.library_pvc
          globalMounts  = [{ path = "/data" }]
        }
      }
    }

    machine-learning = {
      controllers = { main = { containers = { main = { image = { tag = var.image_tag } } } } }
      persistence = {
        cache = {
          type         = "persistentVolumeClaim"
          accessMode   = "ReadWriteOnce"
          size         = var.ml_cache_size
          storageClass = var.storage_class
        }
      }
    }

    valkey = { enabled = true }
  }
}
