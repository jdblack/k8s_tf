locals {
  fqdn     = "${var.hostname}.${var.domain}"
  ssh_fqdn = "${var.ssh_hostname}.${var.domain}"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  data_pvc_name = "${var.name}-data"

  # The chart names its Services <release>-http / <release>-ssh; the release is var.name and the
  # chart name is contained in it, so common.names.fullname collapses to var.name.
  http_service_name = "${var.name}-http"

  # authentik: the OIDC source name, which is baked into the callback URL.
  oidc_source_name = "authentik"
  oidc_issuer      = "${var.oidc_issuer_base}/application/o/${var.name}/"

  # The S3 credential Secret's keys ARE these env names, and env-to-ini folds every FORGEJO__
  # prefixed env into app.ini, so the credentials reach [storage] without a values round-trip.
  s3_credential_env = [
    "FORGEJO__storage__MINIO_ACCESS_KEY_ID",
    "FORGEJO__storage__MINIO_SECRET_ACCESS_KEY",
  ]

  # Everything app.ini needs, in the chart's value shape (sections lowercase, keys all caps).
  # Secret keys -- SECRET_KEY, INTERNAL_TOKEN, LFS_JWT_SECRET -- are left to the chart, which
  # generates them once and persists them in app.ini on the data claim.
  helm_values = {
    strategy = { type = "Recreate" }

    image = {
      registry   = var.image_registry
      repository = var.image_repository
      tag        = var.image_tag
      rootless   = true
    }

    # The chart creates the claim, named after local.data_pvc_name (a plain name, not a hashed
    # release artifact) so the Velero schedule and `kubectl get pvc` keep naming the same volume.
    persistence = {
      enabled      = true
      create       = true
      claimName    = local.data_pvc_name
      size         = var.data_size
      storageClass = var.storage_class
    }

    service = {
      http = { port = var.port }

      ssh = {
        type = "LoadBalancer"
        port = var.ssh_port

        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.ssh_fqdn
        }
      }
    }

    # Exposure goes through the shared gateway listener instead of the chart's Ingress.
    ingress = { enabled = false }

    gitea = {
      # Nothing in the pod is annotated by the hand-written module anymore, so the volume Velero
      # drags in from the pod is named here, on the chart's own volume ("data").
      podAnnotations = {
        "backup.velero.io/backup-volumes" = "data"
      }

      # The break-glass local admin is a DB row the chart's configure-gitea init creates. No
      # password is passed: the chart mints one and keeps it in the <name>-admin Secret, so it
      # never lands in values or terraform state. initialOnlyNoReset = create once, never reset.
      admin = {
        username     = var.admin_username
        email        = var.admin_email
        passwordMode = "initialOnlyNoReset"
      }

      # Native OIDC, not the authentik proxy outpost: the source is registered against this
      # callback and the group claim drives admin/restricted, so no outpost is involved.
      oauth = [{
        name            = local.oidc_source_name
        provider        = "openidConnect"
        key             = module.oidc.client_id
        secret          = module.oidc.client_secret
        autoDiscoverUrl = "${local.oidc_issuer}.well-known/openid-configuration"
        scopes          = "openid,email,profile,groups"
        groupClaimName  = "groups"
        adminGroup      = "${var.name}-admin"
        restrictedGroup = "${var.name}-user"
      }]

      additionalConfigFromEnvs = [for k in local.s3_credential_env : {
        name      = k
        valueFrom = { secretKeyRef = { name = module.s3_user.secret_name, key = k } }
      }]

      # Metrics ride the main web port at /metrics; the chart renders the ServiceMonitor.
      metrics = {
        enabled        = true
        serviceMonitor = { enabled = true }
      }

      config = {
        server = {
          PROTOCOL                = "http"
          DOMAIN                  = local.fqdn
          ROOT_URL                = "https://${local.fqdn}/"
          HTTP_PORT               = var.port
          SSH_DOMAIN              = local.ssh_fqdn
          SSH_PORT                = var.ssh_port
          SSH_LISTEN_PORT         = var.ssh_listen_port
          START_SSH_SERVER        = true
          BUILTIN_SSH_SERVER_USER = "git"
          LFS_START_SERVER        = true
          APP_DATA_PATH           = "/data"
        }

        database = {
          DB_TYPE = "sqlite3"
          PATH    = "/data/forgejo.db"
        }

        # Repo storage path is left at the chart's default (/data/git/gitea-repositories, on the
        # data claim); a fresh instance, so there is nothing to migrate.
        repository = {
          DISABLED_REPO_UNITS = "repo.actions"
        }

        # Every [storage] subsystem -- LFS, attachments, avatars, repo-avatars, repo-archive,
        # packages, actions logs/artifacts -- is a blob store, so it goes to SeaweedFS over S3.
        # The credentials come from the s3_user Secret via additionalConfigFromEnvs.
        storage = {
          STORAGE_TYPE        = "minio"
          MINIO_ENDPOINT      = var.s3_endpoint
          MINIO_BUCKET        = var.s3_bucket
          MINIO_LOCATION      = "us-east-1"
          MINIO_BUCKET_LOOKUP = "path"
          MINIO_USE_SSL       = true
        }

        metrics = { ENABLED = true }

        security = {
          INSTALL_LOCK      = true
          DISABLE_GIT_HOOKS = true
        }

        service = {
          DISABLE_REGISTRATION        = true
          REQUIRE_SIGNIN_VIEW         = true
          ENABLE_PASSWORD_SIGNIN_FORM = false
        }

        # The source itself is a DB row (the chart's oauth block); this is the account
        # behaviour that wraps it.
        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = true
          USERNAME                 = "nickname"
          ACCOUNT_LINKING          = "auto"
          UPDATE_AVATAR            = true
        }
      }
    }
  }
}

