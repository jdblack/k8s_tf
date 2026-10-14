variable "deployment" { type = any }

# Allow-list of Forgejo repositories (`owner/name`) whose Actions get the Harbor push credentials
# as repo-level secrets. A POLICY list -- it cannot be derived, and it is the whole answer to
# "which repos may publish images" (T3.6/T3.7).
#
# An EMPTY list creates no secrets: safe, but also the integration's silent failure mode -- nothing
# errors, CI simply cannot push. Adding entries is the intended way to widen it.
#
# ⚠️ Each named repo needs its Actions UNIT enabled before a secret can land on it, and for
# PRE-EXISTING repos that is not the default. See modules/devops/forgejo/mantle/repos.tf.
# Moved to the `Linuxguru` org 2026-10-14. A transfer keeps the repo id, so these are the same
# repos -- but the `for_each` KEYS change, so the next apply recreates the four secrets in place.
variable "forgejo_registry_repos" {
  type    = list(string)
  default = ["Linuxguru/ellmephant", "Linuxguru/sighup"]
}
