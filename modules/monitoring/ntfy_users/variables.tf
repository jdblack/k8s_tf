variable "namespace" { default = "monitoring" }

# Human users, keyed by username:
#
#   users = {
#     jblack = { role = "user", access = [{ topic = "alerts", permission = "read-write" }] }
#   }
#
# Supplied from tfvars (deployment.ntfy.users). Passwords are generated here and
# stored in the `ntfy-users` Secret; nothing is hashed in Terraform (the CLI
# takes the plaintext and ntfy bcrypts it server-side).
variable "users" {
  type = map(object({
    role   = optional(string, "user")
    access = optional(list(object({ topic = string, permission = string })), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for _, c in var.users : contains(["user", "admin"], c.role)])
    error_message = "role must be either 'user' or 'admin'."
  }

  # Admins bypass ACLs entirely, so access entries for them are dead weight. (On
  # the config-file path ntfy actually refuses to boot with them.)
  validation {
    condition     = alltrue([for _, c in var.users : c.role != "admin" || length(c.access) == 0])
    error_message = "an admin user cannot carry access entries (admins bypass ACLs)."
  }
}

# Name of the Deployment to exec into -- i.e. core's helm release name.
variable "release_name" { default = "ntfy" }

# Secret holding the generated human passwords, one key per username. Distinct
# from core's `ntfy-auth` (which carries the server's NTFY_AUTH_* env for the
# service accounts) so the two are never confused.
variable "secret_name" { default = "ntfy-users" }
