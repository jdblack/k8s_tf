module "forgejo" {
  source = "../../modules/forgejo"

  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  # authentik stays on the private gateway; OIDC discovery and the token exchange go there.
  oidc_issuer_base = var.deployment.auth.server
  host_network     = var.deployment.network.host_cidr
}

# The runner registers with the instance-wide registration token (Admin -> Actions -> Runners),
# minted here by the break-glass local admin over the API. GET is idempotent -- it returns the
# same token on every call -- so a refresh never diffs. The password is read and used inside the
# shell and never lands in state; only the token crosses, and it is in state anyway as the
# runner's registration Secret. (Deprecated in Forgejo 15; still served on 15.0.9.)
data "external" "forgejo_runner_token" {
  program = ["bash", "-c", <<-EOT
    set -eu
    ns="${module.forgejo.namespace}"
    secret="${module.forgejo.name}-admin"
    user=$(kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.username}' | base64 -d)
    pass=$(kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.password}' | base64 -d)
    curl -fsS -u "$user:$pass" \
      "https://${module.forgejo.fqdn}/api/v1/admin/actions/runners/registration-token" \
      | jq -c '{token}'
  EOT
  ]
}

# The Actions runner: its own namespace (it executes arbitrary repo code) and it polls the
# instance over its public name, through the same gateway as everyone else.
module "forgejo_runner" {
  source = "../../modules/forgejo-runner"

  instance_url       = "https://${module.forgejo.fqdn}"
  registration_token = data.external.forgejo_runner_token.result.token
}
