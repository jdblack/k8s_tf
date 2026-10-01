locals {
  fqdn = "${var.hostname}.${var.domain}"

  # Built rather than passed: authentik serves a provider under its application's slug, and
  # the module below creates that application named after this module.
  oidc_issuer = "${var.oidc_issuer_base}/application/o/${var.name}/"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  # Each schedule drags its claim in from the pod that has it mounted, so the selector has
  # to name the chart's own per-service label ("app", not the workload label).
  backup_targets = {
    owncloud-metadata      = { app = "storageusers" }
    owncloud-storagesystem = { app = "storagesystem" }
    owncloud-nats          = { app = "nats" }
  }

  helm_values = {
    externalDomain = local.fqdn

    image = {
      tag = var.image_tag
    }

    replicas = 1

    # The only services with state here are Deployments on ReadWriteOnce claims, so the
    # replacement has to come down before its successor comes up.
    deploymentStrategy = {
      type = "RollingUpdate"
      rollingUpdate = {
        maxSurge       = 0
        maxUnavailable = 1
      }
    }

    # Exposure goes through the shared gateway listener instead of the chart's Ingress.
    ingress = {
      enabled = false
    }

    # The frontend exchanges its authorization code from the browser, so the token
    # endpoint has to be reachable under connect-src. oCIS adds only the issuer there, and
    # authentik serves tokens outside the issuer path -- so without this the exchange is
    # blocked by CSP and the login page waits forever on "you are being redirected".
    http = {
      csp = {
        directives = {
          connectSrc = [
            "'self'",
            "${var.oidc_issuer_base}/application/o/token/",
          ]
        }
      }
    }

    # Renders the chart's own ServiceMonitor over the metrics-debug ports.
    monitoring = {
      enabled = var.metrics_enabled
    }

    features = {
      ocm = {
        enabled = false
      }

      externalUserManagement = {
        enabled = true

        # The outpost serves a read-only view of authentik, so there is nowhere to
        # provision into: accounts are created in authentik, not here.
        autoprovisionAccounts = {
          enabled = false
        }

        oidc = {
          issuerURI = local.oidc_issuer

          # The account is keyed by the LDAP attribute, so the claim has to carry the same
          # value or a login lands beside the account the directory already knows.
          userIDClaim                 = "preferred_username"
          userIDClaimAttributeMapping = "username"
          accessTokenVerifyMethod     = "jwt"

          roleAssignment = {
            enabled = true
            claim   = "groups"
            mapping = [
              { role_name = "admin", claim_value = "owncloud-admin" },
              { role_name = "user", claim_value = "owncloud-user" },
            ]
          }
        }

        ldap = {
          uri    = var.ldap_uri
          bindDN = var.ldap_bind_dn

          # The outpost's cert is trusted as far as the chart is concerned, which keeps it
          # from mounting a CA we do not have; `insecure` is what actually skips the
          # verification, since the outpost self-signs at boot without a SAN.
          certTrusted = true
          insecure    = true

          # Read-only directory: oCIS must not try to write back into it.
          writeable = false

          # authentik serves users as objectClass `user` with `cn` for the username and
          # `uid` for the id, and groups as `group` -- not the idm defaults, which are
          # `inetOrgPerson`/`ownclouduuid` and match nothing there.
          user = {
            baseDN      = var.ldap_user_base_dn
            objectClass = "user"

            schema = {
              id          = "uid"
              userName    = "cn"
              mail        = "mail"
              displayName = "displayName"
            }
          }

          group = {
            baseDN      = var.ldap_group_base_dn
            objectClass = "group"

            schema = {
              id          = "cn"
              groupName   = "cn"
              mail        = "mail"
              displayName = "cn"
            }
          }
        }
      }
    }

    services = {
      storageusers = {
        # Blobs go to SeaweedFS over S3; only the decomposedfs metadata stays on the claim.
        storageBackend = {
          driver = "s3ng"

          driverConfig = {
            s3ng = {
              endpoint = var.s3_endpoint
              region   = var.s3_region
              bucket   = var.s3_bucket
            }
          }
        }

        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.metadata.metadata[0].name
          accessModes   = ["ReadWriteOnce"]
        }
      }

      storagesystem = {
        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.storagesystem.metadata[0].name
          accessModes   = ["ReadWriteOnce"]
        }
      }

      nats = {
        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.nats.metadata[0].name
          accessModes   = ["ReadWriteOnce"]
        }
      }

      # Plain in-cluster state, not worth a claim each.
      authapp = {
        persistence = { enabled = false }
      }

      search = {
        persistence = { enabled = false }
      }

      thumbnails = {
        persistence = { enabled = false }
      }

      web = {
        persistence = { enabled = false }

        config = {
          oidc = {
            # Required by the schema, and it has to be the client authentik knows.
            webClientID = module.oidc.client_id

            # The role assignment above reads the groups claim, which only arrives if the
            # frontend asks for it -- the chart's default scope omits it, and an admin
            # without the claim is just a user.
            webClientScope = "openid profile email groups"
          }
        }
      }
    }

    secretRefs = {
      s3CredentialsSecretRef = module.s3_user.secret_name
      ldapSecretRef          = kubernetes_secret_v1.ldap.metadata[0].name
    }
  }
}
