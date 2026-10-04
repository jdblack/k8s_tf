locals {
  fqdn = "${var.hostname}.${var.domain}"

  # Built rather than passed: authentik serves a provider under its application's slug, and
  # the module below creates that application named after this module.
  oidc_issuer = "${var.oidc_issuer_base}/application/o/${var.name}/"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  # Named in the parent, which keeps this pod out of the namespace baseline egress.
  trash_purge        = var.trash_purge_name
  trash_purge_labels = { "app.kubernetes.io/name" = var.trash_purge_name }

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
    # endpoint has to be reachable under connect-src.
    http = {
      csp = {
        directives = {
          connectSrc = [
            "'self'",

            # authentik serves tokens outside the issuer path, so oCIS's own issuer entry
            # does not cover the exchange and the login page waits forever on "you are
            # being redirected".
            "${var.oidc_issuer_base}/application/o/token/",

            # The editor iframe opens its co-editing websocket back here.
            var.onlyoffice_url,
            replace(var.onlyoffice_url, "https://", "wss://"),
          ]

          # The editors are an iframe served by the document server.
          childSrc = ["'self'", var.onlyoffice_url]
          frameSrc = ["'self'", "blob:", var.onlyoffice_url]

          # App icons are fetched from the document server for the file list.
          imgSrc = ["'self'", "data:", "blob:", var.onlyoffice_url]
        }
      }
    }

    # Renders the chart's own ServiceMonitor over the metrics-debug ports.
    monitoring = {
      enabled = var.metrics_enabled
    }

    features = {
      # Office editing. oCIS runs the WOPI host here -- this flag deploys the collaboration
      # service (the WOPI endpoint) and the app registry -- while the document server on
      # the other end is the WOPI client.
      appsIntegration = {
        enabled = true

        wopiIntegration = {
          officeSuites = [{
            name        = "OnlyOffice"
            product     = "OnlyOffice"
            enabled     = true
            uri         = var.onlyoffice_url
            description = "Edit office documents with ONLYOFFICE"
            iconURI     = "${var.onlyoffice_url}/web-apps/apps/documenteditor/main/resources/img/favicon.ico"

            # Both ends sit behind the shared gateway with a real certificate.
            insecure = false

            # The document server signs its WOPI requests with its own proof key.
            disableProof = false

            secureViewEnabled = false
            disableChat       = true

            # The WOPI endpoint stays internal: only the document server calls it, and it
            # reaches it over the namespace-local Service.
            ingress = {
              enabled = false
            }
          }]
        }

        # Makes ONLYOFFICE the editor the file list opens these in, and offers them
        # for creation.
        mimetypes = [
          {
            mime_type      = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            extension      = "docx"
            name           = "Text document"
            description    = "Text document"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
          {
            mime_type      = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            extension      = "xlsx"
            name           = "Spreadsheet"
            description    = "Spreadsheet"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
          {
            mime_type      = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            extension      = "pptx"
            name           = "Presentation"
            description    = "Presentation"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
          {
            mime_type      = "application/vnd.oasis.opendocument.text"
            extension      = "odt"
            name           = "OpenDocument text"
            description    = "OpenDocument text document"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
          {
            mime_type      = "application/vnd.oasis.opendocument.spreadsheet"
            extension      = "ods"
            name           = "OpenDocument spreadsheet"
            description    = "OpenDocument spreadsheet document"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
          {
            mime_type      = "application/vnd.oasis.opendocument.presentation"
            extension      = "odp"
            name           = "OpenDocument presentation"
            description    = "OpenDocument presentation document"
            icon           = "image-edit"
            default_app    = "OnlyOffice"
            allow_creation = true
          },
        ]
      }

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
        # The chart's maintenance jobs stay disabled: each mounts this ReadWriteOnce claim, so a
        # pod on another node dies on Multi-Attach and, under the hardcoded Forbid, wedges every
        # later run. Trash purge runs instead as an exec CronJob; see maintenance.tf.

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
            webClientID    = module.oidc.client_id
            webClientScope = "openid profile email groups offline_access"
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
