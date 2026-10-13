# The NUMERIC repository id, which `forgejo_repository_action_secret` requires -- every code path
# in the provider calls getRepositoryByID, not a name lookup. Reading it here (rather than being
# handed it) means a repo named in `registry_repos` that does NOT exist fails at PLAN time, which
# is the wanted failure: a typo must not quietly create nothing.
#
# PRECONDITION -- the target repo's Actions UNIT must already be enabled, or the secret below
# cannot be written. Forgejo hides the actions-secrets API behind the unit (`reqOwner(unit.TypeActions)`),
# so a repo with it off returns 404. New repos get the unit by default; PRE-EXISTING ones do not
# and need a one-off `PATCH /api/v1/repos/<owner>/<repo> {"has_actions":true}` (done by hand for
# jblack/ellmephant). There is no narrow terraform-native way to do it: the provider's
# `forgejo_repository` resource rewrites the whole repository from defaults -- forcing every unit
# on, un-archiving archived repos -- which is far too broad a handle for a stack that is not the
# repo's owner. Keeping this out of terraform is the lesser evil.
data "forgejo_repository" "repo" {
  for_each = toset(var.registry_repos)

  owner = split("/", each.value)[0]
  name  = split("/", each.value)[1]
}

# The two secrets `docker login` needs. HARBOR_USER is Harbor's rendered robot name
# (`robot$library+forgejo`); HARBOR_TOKEN is the robot's secret, which the provider fills from the
# create response -- so both materialise in the same apply and there is no ordering gap to chase.
# Both are marked sensitive by the provider, so neither leaks into plan output.
resource "forgejo_repository_action_secret" "harbor_user" {
  for_each = data.forgejo_repository.repo

  repository_id = each.value.id
  name          = "HARBOR_USER"
  data          = harbor_robot_account.forgejo.full_name
}

resource "forgejo_repository_action_secret" "harbor_token" {
  for_each = data.forgejo_repository.repo

  repository_id = each.value.id
  name          = "HARBOR_TOKEN"
  data          = harbor_robot_account.forgejo.secret
}
