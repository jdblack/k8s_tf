# ntfy_users

Human ntfy users, created from the **mantle** stack against the running server.

## Why not config-file provisioning?

ntfy's config keys (`auth-users`, `auth-access`, `auth-tokens`) are each **one
comma-joined value**, so each key has exactly one author. Core owns them, for the
service accounts (`modules/monitoring/ntfy`). Normal users therefore cannot live
there too — two stacks writing the same key would flap, or two `envFrom` sources
would silently shadow each other.

So humans are created the other way ntfy supports: **per-user operations against
the server**, via `kubectl exec` + the ntfy CLI (which edits `/data/user.db`
directly — no admin credential, it is the server's own tool). Those users are
plain database rows with `provisioned = 0`, which is also why core's config can
never delete them: config provisioning only prunes users it created.

## Everything is now individual

For the record, because this shaped the design: ntfy *does* manage users
individually — they are rows in `user.db`, and there is a full admin API
(`GET/POST/PUT/DELETE /v1/users`, plus the admin access endpoints) and a per-user
CLI (`ntfy user add|remove|change-pass|change-role`, `ntfy access …`,
`ntfy token …`). It is only the *config-file importer* that is a single blob.

## Usage

Add users to tfvars (mantle reads the same file as core):

```hcl
ntfy = {
  users = {
    jblack = {
      role   = "user"
      access = [{ topic = "alerts", permission = "read-write" }]
    }
  }
}
```

then `tofu -chdir=stacks/mantle apply`.

Nothing is bcrypted in Terraform: the CLI takes the plaintext (`NTFY_PASSWORD`)
and ntfy hashes it server-side at its own cost.

## Retrieving credentials

Human passwords live in the `ntfy-users` Secret, one key per username. The
break-glass admin is separate (it belongs to the core stack) — see
[../ntfy/readme.md](../ntfy/readme.md#credentials).

```bash
# one user (`; echo` just gives a clean trailing newline)
kubectl -n monitoring get secret ntfy-users \
  -o go-template='{{index .data "jblack" | base64decode}}'; echo

# every user at once
kubectl -n monitoring get secret ntfy-users -o json |
  python3 -c 'import sys,json,base64; [print(k,"=",base64.b64decode(v).decode()) for k,v in json.load(sys.stdin)["data"].items()]'
```

Where they get used:

- **Phone** (ntfy app): server `https://ntfy.<domain>`, then the username and
  password above, subscribing to the alert topic. Use the **F-Droid** build —
  no Firebase/APNS relay, the app holds its own connection.
- **Web UI**: `https://ntfy.<domain>/app`. `enableSignup` is off, so there is no
  sign-up form: you log in with an account that already exists.

### Rotating a password

Replace that user's `random_password`; the password change flows into
`triggers_replace`, so the provisioner re-runs and the CLI's `change-pass`
lands it (the Secret is rewritten first):

```bash
tofu -chdir=stacks/mantle apply -replace='module.ntfy_users.random_password.this["jblack"]'
```

Update the phone afterwards.

## Idempotency

Three layers, none of them bespoke:

1. **`terraform_data` + `triggers_replace`** — the provisioner runs on create and
   on replace only, so a steady-state `tofu apply` never touches the server. The
   trigger includes a hash of the password, so a rotation re-runs it.
2. **`--ignore-exists`** on `ntfy user add` — the CLI's own guard, no-op if the
   user is already there.
3. **Idempotent setters** — `change-pass` / `change-role` (so a rotated password
   in tfvars actually lands, which `--ignore-exists` alone would silently skip),
   and `ntfy access --reset` before re-granting, so a grant *removed* from tfvars
   really disappears instead of accumulating.

Deletion converges too: removing a user from tfvars destroys its
`terraform_data`, whose destroy-time provisioner runs `ntfy user remove`.

## Known limits

- **No drift detection.** Users live in ntfy's SQLite, so `tofu plan` cannot see
  them; if someone deletes a user out-of-band, nothing notices. Repair with
  `tofu -chdir=stacks/mantle apply -replace='module.ntfy_users.terraform_data.user["jblack"]'`.
  (The alternative — a provider with a real `Read` — was rejected as an
  unmaintained, unlicensed third-party dependency.)
- **Apply order.** This must run after `stacks/core` (it execs into the ntfy pod
  that core deploys, and guards with `rollout status`).
- The plaintext goes through the runner's memory (read from the Secret, piped on
  stdin) but never through a command line.
