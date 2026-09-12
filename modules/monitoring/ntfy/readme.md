# ntfy

Push notification server, deployed from the **core** stack into the
`monitoring` namespace, exposed on the **public** gateway as
`ntfy.<domain>`.

Chart: [`oci://codeberg.org/wrenix/helm-charts/ntfy`](https://codeberg.org/wrenix/helm-charts)
`0.5.22` (ntfy `v2.28.0`). There is no official ntfy chart; wrenix is the most
complete one and is a plain `helm_release`, like `smartctl`.

## Auth model

ntfy's auth is entirely its own — **no OIDC, no SAML, no header trust** — and it
is the layer that protects the data for *every* client type (browser, Android
app, Alertmanager). authentik is deliberately **not** in front of this app: the
web UI, the mobile app and Alertmanager share the same paths (the UI is a SPA at
`/app` that then calls `/<topic>/json`, `/<topic>/ws` and `/v1/*`), so a proxy
outpost could not gate "just the UI" — and any 302 to a login page breaks the
phone and the webhook. It would also only have protected an inert shell, since
`deny-all` already makes the API useless without credentials.

`auth-default-access = deny-all` is the load-bearing setting (ntfy's default is
`read-write` = every topic world-readable and world-writable). With it, and no
ACL entry for the anonymous `*` user, an anonymous client gets 403 on every
subscribe and publish path, and cannot even distinguish which topics exist.

### Service accounts (this module)

`auth-users` / `auth-access` / `auth-tokens` are each ONE comma-joined value, so
each has exactly ONE author. This module provisions only the two service
accounts:

| account | role | credential | why |
|---|---|---|---|
| `ntfyadmin` | `admin` | password (bcrypt, config) | break-glass. The web UI cannot create an admin (signup hardcodes `role=user`) and the admin API cannot create the *first* admin, so it has to come from config. |
| `alertmanager` | `user` | access token, `alerts` **write-only** | the publisher. Separate from the admin on purpose: ntfy access tokens grant **full access to the user account**, so an admin's token mounted into Alertmanager would be a full-admin credential. |

Two rules in ntfy's provisioning code are **startup errors** (crashloop, not
warnings), and the config above is shaped around them:

1. `maybeProvisionTokens` refuses a token whose user is not also config-
   provisioned — hence `alertmanager` appears in `auth-users`.
2. `maybeProvisionGrants` refuses an ACL entry for an **admin** — hence the
   admin has no `auth-access` entry (it would be redundant anyway: admins bypass
   ACLs).

The raw `tk_...` is also written to the secret as `publisher_token` (a
non-`NTFY_` key, so ntfy ignores it) for Alertmanager's
`http_config.authorization.credentials_file`.

### Human users (mantle)

Normal users are **not** in this module and never in the core stack. They are
created against the running server by
[`modules/monitoring/ntfy_users`](../ntfy_users/readme.md) in the **mantle**
stack, via `kubectl exec` + the ntfy CLI. Those users are plain database rows
(`provisioned = 0`), so this module's config can never clobber or delete them
(config provisioning only prunes users it created).

## Credentials

| credential | owned by | retrieve with |
|---|---|---|
| break-glass admin (`ntfyadmin`) | core / TF state | `tofu -chdir=stacks/core output -raw ntfy_admin_password` |
| human users (`jblack`, …) | the `ntfy-users` Secret (mantle) | `kubectl -n monitoring get secret ntfy-users -o go-template='{{index .data "jblack" | base64decode}}'; echo` |
| publisher token (`alertmanager`) | the `ntfy-auth` Secret (this module) | `kubectl -n monitoring get secret ntfy-auth -o go-template='{{index .data "publisher_token" | base64decode}}'; echo` |

The full set — every user at once, rotations, and where each one is used — is in
[../ntfy_users/readme.md](../ntfy_users/readme.md#retrieving-credentials).

The web UI is at `https://ntfy.<domain>/app`. `enableSignup` is off (nothing on
a public endpoint should be able to create accounts), so there is no sign-up
form — you log in with an account that already exists.

## Inspecting: there is no "list topics" API

ntfy has no topic registry and no `/v1/topics` endpoint — topics come into
existence the first time anything publishes or subscribes, so the server cannot
enumerate them. What you *can* ask it:

| question | how |
|---|---|
| which topics does this server care about? | the ACL — `kubectl -n monitoring exec deploy/ntfy -- ntfy access`. The granted topics *are* the topic list (here: `alerts`). |
| how many topics has it seen? | `ntfy_topics_total` on `:9000/metrics` — a count, no names. Scraped by the ServiceMonitor. |
| which topics have messages right now? | the message cache (below). |
| what am I subscribed to? | the app / web UI — that's per-account state, not server state. |

Topics with cached messages. The container has no `sqlite3` (alpine), so copy the
cache out and query it locally:

```bash
POD=$(kubectl -n monitoring get pod -l app.kubernetes.io/name=ntfy -o jsonpath='{.items[0].metadata.name}')
kubectl cp monitoring/$POD:/data/cache.db /tmp/ntfy-cache.db
sqlite3 -header -column /tmp/ntfy-cache.db \
  'select topic, count(*) msgs, datetime(max(time),"unixepoch","localtime") latest
     from messages group by topic order by msgs desc;'
```

The table is `messages` (plural), and the cache only holds `cache-duration`
(12h here). To read a topic's actual contents use the API instead — e.g.
`curl -u <user>:<pw> 'https://ntfy.<domain>/<topic>/json?poll=1&since=12h'`.

## Message size — read this before "alerts aren't arriving"

ntfy's default `message-size-limit` is **4K**, and an over-limit body is **not
truncated**: `handlePublishBody` routes it to `handleBodyAsAttachment`, which
returns HTTP 400 `"invalid request: attachments not allowed"` when no attachment
backend is configured. Alertmanager posts its full alert JSON to a topic path,
so a *multi-alert* incident would exceed 4K and be dropped, while single-alert
notifications worked — the worst kind of intermittent bug.

Hence `NTFY_MESSAGE_SIZE_LIMIT = 64K` (`var.message_size_limit`), roughly an
order of magnitude above a realistic batch. Alertmanager's `webhook_configs` has
no `max_alerts` knob, so this limit is the only lever.

## Persistence

One Longhorn RWO PVC at `/data`, holding `user.db` (users/ACLs/tokens) and
`cache.db` (12h message cache, so a phone that reconnects after being offline
can catch up). The chart defaults `updateStrategy` to `Recreate`, which is what
an RWO volume needs.

## Wire-up

- `envFrom` → the `ntfy-auth` Secret (service-account credentials).
- `podAnnotations["checksum/ntfy-auth"]` → puts a digest of the credentials in
  the pod template. Without it a rotated password/token would sit unused in the
  Secret until some unrelated restart, because `envFrom` is only read at
  container start.
- The **ServiceMonitor is created by `modules/monitoring/prometheus`**, not by
  this module's chart: the chart's template is gated on
  `.Capabilities.APIVersions.Has "monitoring.coreos.com/v1"`, so on a
  from-scratch build it would be silently skipped and never re-rendered.
- **Dependency direction:** `prometheus` depends on this module (it consumes the
  publish token), so this module must never depend on `prometheus`.

## Rebuild notes

- The hostname needs no DNS work: `*.linuxguru.net` is a wildcard alias to the
  router, and the router forwards 443 to the public gateway.
- `module.ntfy` depends on `module.storage` (Longhorn) as well as
  `network`/`cert_man`: without that edge a from-scratch build can hang on a
  Pending PVC, and everything downstream (prometheus, metrics-server, smartctl)
  blocks behind it.
