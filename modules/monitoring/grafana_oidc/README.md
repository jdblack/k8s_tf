# `grafana_oidc` — Grafana's authentik OIDC client (mantle half)

Creates the authentik side of Grafana's SSO and writes the credentials into the
Secret Grafana mounts. Instantiated by `stacks/mantle/monitoring.tf`; the Grafana
release itself is core's (`modules/monitoring/prometheus`).

## Why it is split across two stacks

Grafana's `$__file{}` config expander **hard-fails at startup** when the
referenced file is missing (the container exits), and core applies before mantle.
So the Secret *object* is created by core with placeholder values, and this
module patches only its *data*:

| Piece | Owner |
|---|---|
| Secret `grafana-oidc` (object + placeholder) | `stacks/core` → `modules/monitoring/prometheus/grafana.tf`, with `ignore_changes = [data]` |
| The real `client_id` / `client_secret` | `stacks/mantle` → here, via `kubernetes_secret_v1_data` |
| The authentik OIDC provider + application | here (`auth/authentik/oidc_provider`) |

Both `ignore_changes` (core) and touching only `data` (here) are load-bearing —
without them every core apply would blank mantle's credentials back to the
placeholder, or the two stacks would fight over the object.

## What it creates

- **`oidc_provider`** named `grafana`, `redirect_uri = https://grafana.<domain>/login/generic_oauth`,
  with the Grafana tile icon and open-in-new-tab.
- **`kubernetes_secret_v1_data`** on `grafana-oidc` in `monitoring`.
- **`terraform_data.reload`** — deletes the Grafana pod when the credentials
  change (`triggers_replace` is a hash of the pair, so steady-state applies are
  no-ops and the secret value never lands in state in the clear). Pod deletion
  rather than `rollout restart`, deliberately: a rollout would stamp an
  annotation on the Deployment that core's Helm release would then fight over.

Grafana resolves `grafana.ini` (and `$__file{}`) only at startup, hence the
bounce. Role mapping and the SSO-only UI live in core's `grafana.ini` — see
[`../prometheus/README.md`](../prometheus/README.md).

Variables: `namespace` (`monitoring`), `name` (`grafana`), `domain`.
