# ntfy's config-file provisioning takes ONE comma-joined value per key
# (auth-users / auth-access / auth-tokens), so a given key has exactly ONE
# author. This module is that author, and it only ever provisions SERVICE
# ACCOUNTS -- the break-glass admin and the alerting publisher. Human users are
# created by the mantle stack against the running server (see
# modules/monitoring/ntfy_users): they become plain database rows, not config,
# so nothing here can clobber them (config provisioning only deletes users
# flagged `provisioned`).
#
# Two hard rules in ntfy's provisioning code, both of which are STARTUP ERRORS
# (a crashloop, not a warning):
#   1. maybeProvisionTokens: "user %s is not a provisioned user, refusing to add
#      tokens" -- so publisher_user MUST appear in auth-users below;
#   2. maybeProvisionGrants: "adding access control entries is not allowed for
#      admin roles" -- so the admin must NOT appear in auth-access. (Harmless
#      anyway: admins bypass ACLs entirely.)

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "htpasswd_password" "admin" {
  password = random_password.admin.result
}

resource "random_password" "publisher" {
  length  = 32
  special = false
}

resource "htpasswd_password" "publisher" {
  password = random_password.publisher.result
}

# A token must be exactly 32 characters: `tk_` + 29. Two independent checks
# enforce it in ntfy -- allowedTokenRegex (^tk_[-_A-Za-z0-9]{29}$) at
# provisioning time, and `len(token) != tokenLength` (32) in
# AuthenticateToken. Getting either wrong means auth fails with a 401.
resource "random_string" "publisher_token" {
  length  = 29
  special = false
}

locals {
  publisher_token = "tk_${random_string.publisher_token.result}"

  auth_users  = "${var.admin_user}:${htpasswd_password.admin.bcrypt}:admin,${var.publisher_user}:${htpasswd_password.publisher.bcrypt}:user"
  auth_access = "${var.publisher_user}:${var.alert_topic}:write-only"
  auth_tokens = "${var.publisher_user}:${local.publisher_token}:${var.publisher_user}"

  # Hash, not the values: used as a pod annotation so a credential change rolls
  # the pod (see locals.tf). The bcrypt hashes and the token are one-way /
  # write-only respectively, so the digest is safe to carry in the clear.
  auth_checksum = nonsensitive(sha256("${local.auth_users}|${local.auth_access}|${local.auth_tokens}"))
}

resource "kubernetes_secret_v1" "ntfy_auth" {
  metadata {
    name      = "${var.name}-auth"
    namespace = var.namespace
  }

  data = {
    NTFY_AUTH_USERS  = local.auth_users
    NTFY_AUTH_ACCESS = local.auth_access
    NTFY_AUTH_TOKENS = local.auth_tokens

    # The bare token, for consumers that need the credential on its own --
    # Alertmanager's http_config.authorization.credentials_file. Deliberately
    # not NTFY_-prefixed so ntfy's env parser ignores it (it is injected into
    # the pod as a harmless extra env var by envFrom).
    publisher_token = local.publisher_token
  }
}
