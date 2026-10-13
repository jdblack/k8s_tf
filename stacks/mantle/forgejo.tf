# The Forgejo instance is built by `stacks/core` now; this stack keeps only what reaches *into* the
# running service. Two things do: the OIDC groups, which the umbrella `admin`/`user` groups nest
# (admins.tf / users.tf), and the runner's registration token.
#
# The groups are created by the authentik blueprint `core` applies, so they are read by name rather
# than produced by a module. The worker applies that blueprint asynchronously (start-up, or the
# 60-min scan), so a plan that beats it fails loudly -- the wanted failure mode.
data "authentik_group" "forgejo_admin" {
  name = "forgejo-admin"
}

data "authentik_group" "forgejo_user" {
  name = "forgejo-user"
}

# The runner registers with the instance-wide registration token (Admin -> Actions -> Runners),
# minted here by the break-glass local admin over the API. GET is idempotent -- it returns the
# same token on every call -- so a refresh never diffs. The password is read and used inside the
# shell and never lands in state; only the token crosses, and it is in state anyway as the
# runner's registration Secret. (Deprecated in Forgejo 15; still served on 15.0.9.)
data "external" "forgejo_runner_token" {
  program = ["bash", "-c", <<-EOT
    set -eu
    ns="devops-forgejo"
    secret="forgejo-admin"
    user=$(kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.username}' | base64 -d)
    pass=$(kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.password}' | base64 -d)
    curl -fsS -u "$user:$pass" \
      "https://git.${var.deployment.cluster.domains.private}/api/v1/admin/actions/runners/registration-token" \
      | jq -c '{token}'
  EOT
  ]
}

# The Actions runner: its own namespace (it executes arbitrary repo code) and it polls the
# instance over its public name, through the same gateway as everyone else.
module "forgejo_runner" {
  source = "../../modules/devops/forgejo-runner"

  instance_url       = "https://git.${var.deployment.cluster.domains.private}"
  registration_token = data.external.forgejo_runner_token.result.token
}
