# Disaster recovery — the authentik database

| | |
|---|---|
| PVC | `data-authentik-postgresql-0` in `kube-auth` |
| Owner | `StatefulSet/authentik-postgresql` (bitnami postgresql, 1 replica) |
| Tiers | daily + weekly + monthly, retain 2 each |

This is the cluster's identity database: users, groups, applications, providers,
outpost tokens, and every OIDC client secret. Lose it and `auth.vn` is gone —
and so is every SSO login in front of Grafana, Harbor, Argo CD, the outpost apps
and whisker. Group *membership* is deliberately not in Terraform ("Terraform
owns structure, the UI owns people"), so an apply cannot regenerate it: this
snapshot is the only route back to a working identity provider.

**Order matters.** The writers are `authentik-server` and `authentik-worker`.
Scale the worker, then the server, then the StatefulSet to 0, revert, then bring
them back in reverse. Postgres does its own crash recovery over the reverted data
directory on start — expect `recovery` in its logs and wait for `pg_isready`
before the server pod starts serving (otherwise every OIDC provider sees a 500
while it is still recovering).

Everything written since the target snapshot is gone: new users, new providers,
rotated client secrets, live sessions. Sessions are cheap (re-login);
provider secrets are not, so check `argon2`/OIDC client secrets afterwards if
you reverted past a rotation.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../../../storage/disaster_recovery.md`](../../../storage/disaster_recovery.md).
