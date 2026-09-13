# TODO: vaultwarden (private gateway, `vaultwarden.linuxguru.net`)

Handoff doc for a fresh context. **The design is settled — implement it, don't
re-derive it.** Anything marked **verified** was tested against the live cluster on
2026-09-13 (a throwaway `certtest` host, built and torn down). Read this whole file
first: a couple of decisions look wrong until you read why, and two of them — the
hostname and the absence of an authentik gate — will get "corrected" by a
well-meaning reader and break every Bitwarden client if they are.

> **Status 2026-09-14: implemented and verified live.** `modules/vaultwarden/`,
> `modules/network/dns/route53_record/`, `stacks/mantle/vaultwarden.tf`, and the
> AWS provider in `stacks/mantle/providers.tf` (lock file regenerated; `aws ~> 6.0`
> → 6.64.0). Landing it took **three applies**, because the design hit two real
> gaps plus one environment assumption. Five corrections, all verified against the
> running system and all fixed in code/docs:
>
> 1. **`monitoring.tf` dropped** — 1.37.3 has no `/metrics` and no
>    `PROMETHEUS_ENABLED` (the metrics build feature is gone upstream; only
>    `GET /alive` remains), so a ServiceMonitor would scrape nothing.
> 2. **`route53:GetHostedZone` is genuinely required** — the policy was missing it
>    and `aws_route53_record` cannot work without it. See Trap 1; the action is now
>    granted (still scoped to the one zone).
> 3. **The Longhorn PVC label also needs `recurring-job.longhorn.io/source: enabled`**
>    — without it Longhorn ignores the PVC's group label and the job never fires.
>    Note the value is `enabled`, *not* the `enable` that Longhorn's own
>    enhancement doc states.
> 4. **AWS provider v6 renamed `secret_access_key` → `secret_key`.**
> 5. **`/admin` does not 404** on 1.37.3 — with `ADMIN_TOKEN` unset it returns a
>    200 `text/plain` "panel is disabled" notice, and the admin API paths 404.
>
> Everything else held exactly as written: the `.vn`-hostname rejection, the
> private gateway + public cert pairing, the drift test, and the rollback
> cautions. Verified outcome — DNS `192.168.0.100` from bind9 *and* Route 53,
> Let's Encrypt cert for `vaultwarden.linuxguru.net`, `/` → 200, admin API 404,
> ListenerSet `Accepted/Programmed=True`, Certificate `Ready=True`, PVC `Bound`,
> volume labelled `recurring-job-group.longhorn.io/vaultwarden`, drift test
> reverted by `apply`, `tofu plan` clean, all 17 certificates `True`. Details in
> "Verification / acceptance criteria" and `modules/vaultwarden/README.md`.

## Goal

Self-hosted Bitwarden server (vaultwarden) in the local cluster at:

    https://vaultwarden.linuxguru.net

on the **private** gateway (`192.168.0.100`) — reachable from the LAN and over
WireGuard, **not** from the internet — with a **publicly-trusted letsencrypt**
cert so phones need no private-CA install.

## Decisions — do not re-litigate

| Decision | Choice | Why |
|---|---|---|
| Module path | `modules/vaultwarden/` | App-named top-level module, like `blender` / `harbor` / `cert_manager`. **Not** `modules/security/*` (that dir is an empty leftover from the removed `trivy-operator`; its namespace `kube-security` only survives because it's in state). **Not** `modules/auth/*` (that is the authentik *platform* other modules consume). Naming: `vaultwarden`, not `vault_warden` — app-named modules keep upstream spelling (`qbittorrent`, `seaweedfs`, `longhorn`, `plex`). |
| Chart vs hand-rolled | **hand-rolled**, no helm chart | The workload is 5 resources: Deployment + PVC + Service + Secret + RecurringJob. Precedent: `modules/media/qbittorrent` and `modules/blender` (both `kubernetes_deployment_v1` + PVC + Service, no chart). The available charts render an `Ingress` (useless here), cannot render an NGF `ListenerSet`, and a chart-owned PVC cannot carry the Longhorn recurring-job-group label. |
| Stack | `stacks/mantle/vaultwarden.tf` | A user service, not platform. `README.md`: core = "infrastructure foundation (network, storage, certs, platform services)", mantle = "workload layer". Bonus: mantle already configures the `authentik` provider, so OIDC SSO would be a local addition rather than cross-stack plumbing. |
| Exposure | private gateway + `letsencrypt` | LAN/WG only, publicly-trusted cert. Same hostname + cert as the public option, so moving the `ListenerSet` to the `public` gateway later is a one-line change **with zero client reconfiguration** (Bitwarden clients pin the server URL). |
| authentik | **no proxy outpost** | The clients are not browsers: they POST to `/identity/connect/token`, call `/api/*` with bearer tokens, and hold a `/notifications/hub` websocket. The outpost 302s unauthenticated requests to a login page, which breaks every client. `/admin` is instead disabled outright (no `ADMIN_TOKEN`). |
| Namespace | own `vaultwarden` namespace | Not the orphaned `kube-security`. Own namespace = one netpol blast radius, like `blender`. |
| Backup | Longhorn snapshot `RecurringJob` now; S3 `backupTarget` deferred | There is **no** `RecurringJob` and no `backupTarget` anywhere in TF or the cluster today. Snapshot-only is cluster-local — see `backup.tf` under "Module layout" and the S3 item under "Out of scope". |
| Hostname + cert | `vaultwarden.linuxguru.net` + `letsencrypt` | Settled. Private gateway, publicly-trusted cert, so no CA install on phones. Proven end-to-end (see "Verified facts"). |
| DNS | **Terraform-managed `aws_route53_record`**, authoritative (`allow_overwrite = true`) | external-dns is scoped to `vn.linuxguru.net`, so it ignores this hostname. The record must exist, or LAN clients follow the wildcard → WAN IP → public gateway → no listener. See "DNS: the A record". |
| Hostname obscurity | **rejected** | "Nobody can reach it unless they guess the name" fails, because any publicly-trusted cert is published to Certificate Transparency logs within minutes. Receipt: `certtest.linuxguru.net` — a name that existed for ~10 minutes — was already in CT indexes hours later, next to decommissioned names (`ntfy.`, `keycloak.`, `jellyfin.`, `chef.`). What actually blocks the internet is the **private gateway**, not the name. Don't re-open this. |

## Is this a workaround? No.

The gateway/route/cert machinery is **stock house style**. If you diff this module
against `modules/media/plex/listener.tf`, the shape is identical:

| Element | House standard | vaultwarden | Different? |
|---|---|---|---|
| `expose` module call | `source = ../../network/gateway/expose` | same | no |
| ListenerSet + `cert-manager.io/cluster-issuer` annotation | from `listener_set` submodule | same | no |
| shim-provisioned secret name | `cert-<fqdn>` | `cert-vaultwarden.linuxguru.net` | no — same rule |
| cross-namespace `ReferenceGrant` | auto-created by `expose` | same | no |
| `backend_name` / `backend_port` | app Service | same | no |
| netpols | `basic_internet` + `limited_ingress` | same | no |
| `cert_issuer` value | `linuxguru-ca` (private gw apps) / `letsencrypt` (public gw apps) | `letsencrypt` | **value differs**, mechanism identical |
| cert reachability requirement | none (DNS-01) | none | no |
| DNS | automatic (external-dns → bind9, `vn` zone) | **Terraform-managed `aws_route53_record`** | **yes — the only real deviation**, and it drags in the AWS provider (new to this repo) |
| client CA trust | install `linuxguru-ca` on every device | none (public CA) | strictly better |

So there are exactly two things to know, and neither is a hack:

1. **`cert_issuer = "letsencrypt"` on a private gateway.** That is just a
   variable; the same issuer already serves every public-gateway app, and it only
   works regardless of reachability because its solver is DNS-01. No new
   mechanism is introduced — two existing patterns are paired for the first time.
2. **A Route53 `A` → `192.168.0.100`, managed by Terraform.** This is DNS
   *targeting*, not gateway trickery: without it the `*.linuxguru.net` wildcard
   sends clients to the WAN IP → router → `.101` (public gateway), which has no
   listener for the host. It exists only because we want a `linuxguru.net` name on
   the private gateway, and because external-dns manages only the `vn` zone. The
   credentials for it already exist and are least-privilege — see "Credentials".

Why it *feels* unfamiliar: nothing in the cluster does this combination today.
All 16 private-gateway certs use `linuxguru-ca`, and the single `letsencrypt`
cert (`plex`) sits on the public gateway. This is the first pairing — which is
exactly why it was tested end-to-end before being written down.

The alternative — `vaultwarden.vn.linuxguru.net`, where external-dns publishes
automatically — is *more* of a workaround: a public cert there needs the
`hostedZoneID` fix plus a propagation-nameserver flag (see "Out of scope"), and
the no-flags fallback is the private CA, which every client device must then
trust.

## Verified facts (live, 2026-09-13)

A throwaway `certtest` (namespace, hello-world nginx, ListenerSet on the private
gateway, one Route53 record) was built and then torn down. It proved:

- **letsencrypt issues for a host that is unreachable from the internet.**
  `certtest.linuxguru.net` → private gateway → `HTTP/2 200` with
  `issuer=C=US, O=Let's Encrypt, CN=YR1`, `subject=CN=certtest.linuxguru.net`.
  The `letsencrypt` ClusterIssuer's only solver is `dns01/route53`, so validation
  is a Route53 TXT record (`_acme-challenge.<host>`) — **no inbound reachability
  is required**. The `_acme-challenge` TXT was observed live during issuance.
- **It fails closed from the internet**: `openssl s_client -connect <WAN
  ip>:443 -servername certtest.linuxguru.net` → `tlsv1 unrecognized name` (the
  public gateway has no listener for the host).
- **DNS/zone layout**
  - `linuxguru.net` is a Route53 zone, id `Z3FM4Y4P2572E4` (== `deployment.cert.R53_ZONEID`).
  - `*.linuxguru.net` is a wildcard `A` → `113.161.41.162` (WAN IP); the router
    forwards 443 → `192.168.0.101` (the **public** gateway). Hairpin NAT works
    (from the LAN: `curl -I https://plex.linuxguru.net/` → `HTTP/2 401, server: nginx`).
  - `bind9` (192.168.0.2) has **no** `linuxguru.net` zone — it recurses to
    Route53 for those names. It *is* authoritative for `vn.linuxguru.net`
    (`grafana.vn.linuxguru.net` → `192.168.0.100`).
  - **Consequence**: for a private-gateway host you must override DNS per host,
    or LAN clients resolve the wildcard → WAN IP → hairpin → public gateway →
    no listener → TLS failure (reproduced: `unrecognized name`). Wildcard TTL is
    **60 s**, so this is quick to change and quick to revert.
- **The gateway-shim flow is automatic.** cert-manager creates a `Certificate`
  named `cert-<fqdn>` (see `modules/network/gateway/listener_set/main.tf`) from
  the `cert-manager.io/cluster-issuer` annotation. The ListenerSet briefly shows
  `InvalidCertificateRef: Secret <ns>/cert-<fqdn> does not exist`, then flips to
  `Accepted/Programmed=True` on its own. **No `depends_on` hacks** — the cert
  can issue before the listener is even programmed.
- **Gotcha: `challenge.spec.solver` is a frozen snapshot.** Editing the
  ClusterIssuer does *not* fix an in-flight challenge; you must delete the
  CertificateRequest/Order/Challenge chain. A Challenge stuck `Terminating` loops
  on a failing finalizer and blocks its Order forever — strip the finalizer with
  `kubectl patch challenge <name> -n <ns> --type=merge -p '{"metadata":{"finalizers":null}}'`.

## DNS: the A record

`modules/vaultwarden/dns.tf` calls a new shared submodule
(`modules/network/dns/route53_record/`, in the `firewalls/*` / `gateway/expose`
library style):

```hcl
resource "aws_route53_record" "this" {
  zone_id         = var.zone_id          # literal Z3FM4Y4P2572E4 — see trap 1
  name            = var.name             # vaultwarden.linuxguru.net
  type            = "A"
  ttl             = 60                   # matches the wildcard's TTL
  records         = var.records          # ["192.168.0.100"]
  allow_overwrite = true                 # ← the authoritative/replacing behaviour
}
```

The requirements were explicit — *"authoritative, replace old A records on that
name"* — and resolve as follows:

1. **`allow_overwrite = true`** is what makes it replace rather than refuse.
   Without it the AWS provider **errors** on a pre-existing record with the same
   name+type (deliberate, to avoid clobbering whoever put it there). With it, the
   first apply overwrites whatever is present, *including a multi-value
   round-robin set* — which collapses to our single IP.
2. **Drift is detected and reverted** — the provider refreshes the record set on
   every plan, so a console edit shows up as an in-place update and the next
   `apply` restores `192.168.0.100`. That is the "authoritative" property; it's
   also the acceptance test (see "Verification").
3. **TTL 60** to match the existing wildcard, so changes and reverts settle fast.
4. **Edge case it does *not* cover**: if the name ever holds a `CNAME`, Route 53
   rejects an `A` beside it (`InvalidChangeBatch`). Delete the CNAME first. Worth
   one line in the submodule README.
5. The record supersedes the wildcard for that one name (closest match wins) —
   same mechanism the `certtest` proved works.

**Trap 1 — `GetHostedZone` is needed by the RESOURCE, not just by a data source.**
`route53:GetHostedZone` is (was) denied to `lg-route53`. Verified:

```
$ aws route53 get-hosted-zone --id Z3FM4Y4P2572E4        # as lg-route53
An error occurred (AccessDenied) ... not authorized to perform:
route53:GetHostedZone on resource: arn:aws:route53:::hostedzone/Z3FM4Y4P2572E4
```

Passing the literal `zone_id` from `var.deployment.cert.R53_ZONEID` is still
right — but it is **not sufficient**. The AWS provider's `resourceRecordCreate`
(`internal/service/route53/record.go`) calls `findHostedZoneByID()` as its first
action, to read the zone **name** it needs for the computed `fqdn` attribute, and
the same call sits on the read/update/delete paths:

```go
zoneID := cleanZoneID(d.Get("zone_id").(string))
zoneRecord, err := findHostedZoneByID(ctx, conn, zoneID)
if err != nil { return ... "reading Route 53 Hosted Zone (%s): %s" }
```

So the first apply failed with exactly
`reading Route 53 Hosted Zone (Z3FM4Y4P2572E4): ... AccessDenied: ...
route53:GetHostedZone`. The "not necessary" call this doc used to make was
unfounded: the `certtest` wrote its record with the **AWS CLI**
(`ChangeResourceRecordSets`, which *was* granted) and never exercised the
resource. **Resolved:** `GetHostedZone` was added to `dyndns_linuxguru` (policy
version v4), scoped to that one zone ARN — see "Credentials".

## Credentials — existed, but needed one added action

`deployment.cert` in `~/.tfenvs/k8s.tfenv` already carries `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION = us-west-2`, `R53_ZONEID = Z3FM4Y4P2572E4`.
That key resolves to a purpose-built principal:

```
arn:aws:iam::169232240393:user/lg-route53      (one active key, created 2025-01-08)
```

with managed policy `dyndns_linuxguru`:

```json
{"Statement": [
  {"Sid":"VisualEditor0","Effect":"Allow",
   "Action":["route53:ChangeResourceRecordSets","route53:ListResourceRecordSets",
             "route53:GetHostedZone"],
   "Resource":"arn:aws:route53:::hostedzone/Z3FM4Y4P2572E4"},
  {"Effect":"Allow","Action":["route53:GetChange"],"Resource":"arn:aws:route53:::change/*"},
  {"Effect":"Allow","Action":"route53:ListHostedZonesByName","Resource":"*"}
]}
```

(`route53:GetHostedZone` is the 2026-09-14 addition, policy **version v4**; v1–v3
had the other three only.)

Verified live with those credentials:

| Call | Result |
|---|---|
| `ListHostedZonesByName` | ✓ `linuxguru.net. / Z3FM4Y4P2572E4` |
| `ListResourceRecordSets` | ✓ — only three A records exist: `*.linuxguru.net`, `home.linuxguru.net`, `*.vn.linuxguru.net` |
| `GetHostedZone` | ✗ AccessDenied → Trap 1 above |
| `sts:GetCallerIdentity` | ✓ — the AWS provider calls this on every plan, so it won't trip |

**Correction (2026-09-14).** `ChangeResourceRecordSets` was already granted on
exactly that zone, but the record still could not be created: the provider
resource also needs `route53:GetHostedZone` (Trap 1), which was *not* granted, so
"needs no AWS-side changes at all" was wrong. Policy version **v4** adds that one
action, still scoped to `arn:aws:route53:::hostedzone/Z3FM4Y4P2572E4`. Verified
afterwards: `aws route53 get-hosted-zone --id Z3FM4Y4P2572E4` as `lg-route53`
returns `linuxguru.net.`, and the record then created cleanly. That is the **only**
AWS-side change this build required.

- **No new secret exposure** — the same values are *already* in Terraform state
  via `kubernetes_secret_v1.certman_route53_secret`
  (`modules/cert_manager/external_cert.tf` builds the in-cluster solver Secret
  from them).
- **Rotation stays one step** — one tfvars edit + apply updates the in-cluster
  cert-manager Secret and the DNS provider together.
- The key is zone-scoped: it cannot touch `emtho.com`, create zones, or delete the
  hosted zone. Don't replace it with a broader key "to make things easier".

## Module layout

```
new  modules/network/dns/route53_record/{main,variables,providers}.tf + README.md
new  modules/vaultwarden/{providers,variables,locals,namespace,secret,deployment,
                          service,listener,dns,security,backup}.tf + README.md
                          # no monitoring.tf -- see the corrections note above
new  stacks/mantle/vaultwarden.tf
edit stacks/mantle/providers.tf          # + hashicorp/aws, + provider "aws"
edit stacks/mantle/.terraform.lock.hcl   # regenerated by `tofu init` — commit it
```

`modules/network/dns/route53_record/` — `zone_id`, `name`, `records`, `ttl`
(default 60), `type` (default `"A"`), `allow_overwrite` (default `true`). Single
purpose, like `firewalls/allow_api`. *If you'd rather not add a directory, put the
raw `aws_route53_record` in `modules/vaultwarden/dns.tf` — same result.*

### `stacks/mantle/providers.tf`

```hcl
required_providers {
  aws = { source = "hashicorp/aws", version = "~> 6.0" }   # pin; `tofu init` resolves it
}
provider "aws" {
  access_key        = var.deployment.cert.AWS_ACCESS_KEY_ID
  secret_access_key = var.deployment.cert.AWS_SECRET_ACCESS_KEY
  region            = var.deployment.cert.AWS_REGION
}
```

Child modules inherit this default config — no `providers = {}` plumbing. Run
`tofu -chdir=stacks/mantle init` afterwards and commit the updated lock file.

### `stacks/mantle/vaultwarden.tf`

```hcl
module "vaultwarden" {
  source             = "../../modules/vaultwarden"
  namespace          = "vaultwarden"
  domain             = var.deployment.domains.public             # linuxguru.net
  cert_issuer        = var.deployment.cert_authorities.public    # letsencrypt
  zone_id            = var.deployment.cert.R53_ZONEID
  private_gateway_ip = var.deployment.network_ingress.private_ip # 192.168.0.100
  image_tag          = "<pinned>"                                # no :latest
}
```

### Inside `modules/vaultwarden/`

Copy shapes from the files listed under "Read these first".

- `providers.tf` — `kubernetes`, `kubectl`, `random` (see `modules/blender/providers.tf`);
  `aws` comes from the parent.
- `namespace.tf` / `secret.tf` — `modules/blender/` patterns. Secret holds the env
  config; **no `ADMIN_TOKEN`** (unset ⇒ `/admin` disabled entirely). Config lives
  in TF, not in an admin panel.
- `deployment.tf` — `kubernetes_deployment_v1`, `replicas = 1`, labels
  `app.kubernetes.io/name = "vaultwarden"`, image `vaultwarden/server:<pinned>`,
  port 80, single volume mounted at `/data`.
  **`strategy { type = "Recreate" }`** — the PVC is RWO, and a RollingUpdate can
  deadlock waiting for the old pod to release the volume.
  Skip `securityContext` unless you've confirmed the image's default user (it has
  historically run as root).
- PVC (same file, as `qbittorrent` does): `vaultwarden-data`,
  `storage_class_name = "longhorn"`, `ReadWriteOnce`, `~2Gi` (expansion is
  allowed), and **labelled** `recurring-job-group.longhorn.io/vaultwarden = "enabled"`
  — that label is what joins the volume to the RecurringJob. Owning the PVC is one
  reason not to use a chart.
- `service.tf` — ClusterIP `80 → 80`, plus `lifecycle { ignore_changes = [metadata[0].annotations] }`
  (qbittorrent's pattern). Websockets ride the same port on 1.3x; if the pinned
  version wants a separate one (3012), add it to both the container and the Service.
- `listener.tf` — `expose` with `name = "vaultwarden"`, `domain`, `cert_issuer`,
  `gateway_name = "private"`, `gateway_namespace = "kube-network"`,
  `backend_name = "vaultwarden"`, `backend_port = 80`. The ListenerSet hostname
  becomes `vaultwarden.<domain>` and the shim provisions `cert-vaultwarden.linuxguru.net`.
- `dns.tf` — calls the `route53_record` submodule with `zone_id`, `name =
  "vaultwarden.${var.domain}"`, `records = [var.private_gateway_ip]`.
- `security.tf` — egress `basic_internet` (`allow_to_services = false`,
  `allow_to_k8sapi = false`); ingress `limited_ingress` with
  `allowed_ingress_namespaces = [var.namespace, "kube-network"]` and **no CIDRs**
  (the gateway is the only path in, unlike media's LoadBalancer apps).
- `backup.tf` — `kubectl_manifest` `RecurringJob` (`longhorn.io/v1beta2`,
  `recurringjobs.longhorn.io`): `groups = ["vaultwarden"]`, `task = "snapshot"`,
  `cron = "0 3 * * *"`, `retain = 7`, `concurrency = 2`. Confirm the field set with
  `kubectl explain recurringjob.spec`.
- `monitoring.tf` — **not implemented.** ~~(optional) `ServiceMonitor` +
  `PROMETHEUS_ENABLED = "true"`, mirroring `modules/storage/seaweedfs/monitoring.tf`.~~
  Verified against the 1.37.3 source: no `/metrics` route and no
  `PROMETHEUS_ENABLED` (the metrics feature is gone upstream; `GET /alive` is the
  only health route), so a ServiceMonitor would have nothing to scrape. Re-check in
  a later release, then add it **and** `"monitoring"` to the ingress guest list.

### env (verify names against the pinned version's release notes)

| env | value | why |
|---|---|---|
| `DOMAIN` | `https://vaultwarden.linuxguru.net` | cookies, attachment URLs, websocket URL |
| `DATA_FOLDER` | `/data` | |
| `SIGNUPS_ALLOWED` | `false` | no self-registration |
| `INVITATIONS_ALLOWED` | `false` | |
| `SENDS_ALLOWED` | `false` | |
| `PASSWORD_HINTS_ALLOWED` | `false` | |
| `EMERGENCY_ACCESS_ALLOWED` | `false` | |
| `LOGIN_RATELIMIT_MAX_BURST` / `LOGIN_RATELIMIT_SECONDS` | e.g. `10` / `60` | brute-force brake |
| `ADMIN_TOKEN` | **unset** | unset ⇒ `/admin` disabled. If ever needed, use an argon2 hash, never plaintext |
| `PROMETHEUS_ENABLED` | ~~`true`~~ | **stale**: 1.37.3 has no metrics build feature and no `/metrics` route, so this does nothing. No `monitoring.tf` shipped. |

Traffic arrives from the gateway data plane; vaultwarden's default `IP_HEADER` is
`X-Real-IP`, which NGF sets — so per-client rate limiting works as intended.

## Implementation sequence

1. `stacks/mantle/providers.tf` — add the AWS provider. Then
   `tofu -chdir=stacks/mantle init` and commit the regenerated lock file.
2. `modules/network/dns/route53_record/` — the submodule (+ README).
3. `modules/vaultwarden/` — the module (+ README).
4. `stacks/mantle/vaultwarden.tf` — the module call.
5. `tofu -chdir=stacks/mantle plan` → **stop and let the user review it.** The
   first apply writes to a production DNS zone and issues a public cert; both
   deserve eyes before they happen.
6. `tofu -chdir=stacks/mantle apply`.
7. Verify (next section), then run the drift test.
8. Commit, conventional style, e.g.
   `feat(vaultwarden): add vaultwarden on the private gateway with a TF-managed A record`
   — module + stack + **lock file** together. Doc-only updates can be their own
   `docs:` commit.

Ordering notes:

- The `A` record and the `ListenerSet` are independent; create them in either
  order. Browser testing needs *both* the cert (`Ready`, ~30-90 s) and DNS
  resolving to `192.168.0.100` (TTL 60 s). If DNS still shows the WAN IP, you are
  seeing the wildcard — wait a minute, don't "fix" it.
- **Rollback caution**: `tofu destroy -target=module.vaultwarden` takes the PVC
  with it, and the `longhorn` storage class is `reclaimPolicy: Delete` — the
  snapshots go too (they belong to the volume). Once there's real data in the
  vault, export from a client *before* any destroy, and treat the S3
  `backupTarget` follow-up as the thing that makes destruction survivable.
## Verification / acceptance criteria

```sh
dig +short vaultwarden.linuxguru.net                 # 192.168.0.100

echo | openssl s_client -connect vaultwarden.linuxguru.net:443 \
  -servername vaultwarden.linuxguru.net 2>/dev/null | openssl x509 -noout -issuer -subject
# → issuer=... O=Let's Encrypt ...  subject=CN=vaultwarden.linuxguru.net

curl -sI https://vaultwarden.linuxguru.net/          # 200 (the web vault)
curl  -s https://vaultwarden.linuxguru.net/admin     # 200 text/plain: "admin
                                                     # panel is disabled" — see below
curl -s -o /dev/null -w '%{http_code}\n' \
     https://vaultwarden.linuxguru.net/admin/diagnostics   # 404 — no admin API

kubectl -n vaultwarden get listenerset,certificate,pvc,pod
kubectl -n longhorn-system get recurringjobs.longhorn.io
```

- [x] `https://vaultwarden.linuxguru.net/` → **200** over a letsencrypt cert
      (`issuer=C=US, O=Let's Encrypt, CN=YR1`,
      `subject=CN=vaultwarden.linuxguru.net`), no browser warning, from the LAN.
      `dig` → `192.168.0.100` from **both** bind9 and Route 53's authoritative NS.
- [x] From a non-LAN network: no response at all. (The fail-closed half was
      proved from the LAN via hairpin to the WAN IP:
      `openssl s_client -connect 113.161.41.162:443 -servername
      vaultwarden.linuxguru.net` → `tlsv1 unrecognized name` — the public gateway
      has no listener for the host. The A record itself is RFC1918.)
- [x] Admin is not exposed — **this criterion was mis-stated.** On 1.37.3 an
      unset `ADMIN_TOKEN` does not make `/admin` 404: it answers `200` with
      `text/plain` — *"The admin panel is disabled, please configure the
      'ADMIN_TOKEN' variable to enable it"*. The admin **API** does 404
      (`/admin/diagnostics`, `/admin/users`, `/admin/login`), `ADMIN_TOKEN` is
      absent from the container env, and `/admin` is not an SPA catch-all
      (a nonsense path 404s).
- [x] ListenerSet `Accepted=True, Programmed=True`; Certificate
      `Ready=True` ("Certificate is up to date and has not expired"); PVC `Bound`
      (2Gi, `longhorn`); pod `1/1 Running`.
- [x] `kubectl -n longhorn-system get recurringjobs.longhorn.io` shows
      `vaultwarden-snapshot` (`["vaultwarden"]`, task `snapshot`, `0 3 * * *`,
      retain 7, concurrency 2) **and** the volume carries the group label — after
      the source-label fix (correction 3 above). Longhorn's own log lines:
      `Adding Volume pvc-… recurring job label recurring-job-group.longhorn.io/vaultwarden: enabled`
      and `Removing Volume pvc-… recurring job label recurring-job-group.longhorn.io/default`
      (the PVC label source overrides the volume's own labels, as documented).
- [x] **Drift test (the "authoritative" requirement) passed**: pointing the
      record at `192.168.0.99` out-of-band made `tofu plan` show
      `- "192.168.0.99" / + "192.168.0.100"` (`0 to add, 1 to change, 0 to
      destroy`), and `apply` restored `192.168.0.100`.
      ```sh
      aws route53 change-resource-record-sets --hosted-zone-id Z3FM4Y4P2572E4 --change-batch \
       '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"vaultwarden.linuxguru.net",
        "Type":"A","TTL":60,"ResourceRecords":[{"Value":"192.168.0.99"}]}}]}'
      tofu -chdir=stacks/mantle plan     # must want to change it back
      tofu -chdir=stacks/mantle apply
      ```
- [x] `tofu -chdir=stacks/mantle plan` clean after apply ("No changes. Your
      infrastructure matches the configuration."), and **all 17** certificates
      `True` — the 16 pre-existing ones untouched.

## Offline behaviour (goes in the module README)

This is the accepted design, not a bug list:

- **Works offline from cache**: reading/copying items, search, autofill, and TOTP
  codes (the seeds live in the vault).
- **Does NOT work offline**: creating/editing items (Bitwarden clients have no
  offline write queue — they error out), attachment downloads (not cached), and
  new-device enrollment / re-login (always needs the server).
- **Cache loss = lockout**: reinstall, iOS storage eviction, or an invalidated
  session means no access until home or on WireGuard. Keep two enrolled clients
  (phone + laptop) so one loss doesn't strand you.
- **WireGuard is the escape hatch** (`modules/network/wireguard`: full tunnel,
  pushes `192.168.0.2` as DNS). Caveat: UDP-only on `home.linuxguru.net:51820`,
  so a network that blocks UDP defeats it.
- **A phone/laptop is not a backup**: attachment blobs aren't in the client cache
  and aren't in standard exports. Export from a client occasionally and keep the
  file off the cluster.

## Out of scope / deferred follow-ups

- **S3 backup target**: point Longhorn `backupTarget` at the SeaweedFS S3 endpoint
  and flip the RecurringJob to `task = "backup"`. Snapshots alone don't survive
  losing the cluster (or the house), and SeaweedFS is still in-cluster — a real
  offsite target is the end goal for a secrets store.
- **letsencrypt for `.vn` names** (would let the cluster retire `linuxguru-ca` and
  the mobile CA-install chore): needs the `hostedZoneID` fix (below) **plus**
  probably `--dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
  --dns01-recursive-nameservers-only` in `modules/cert_manager/locals.tf`, because
  cert-manager's propagation self-check resolves through bind9 for the `vn`
  subtree. Partially proven: with `hostedZoneID` set, the TXT *was* written to
  Route53; the test was torn down before validation finished.
- **authentik SSO**: vaultwarden has native OIDC (`SSO_ENABLED`, `SSO_AUTHORITY`,
  `SSO_CLIENT_ID/SECRET`); wire it with `modules/auth/authentik/oidc_provider`
  (the provider is already configured in mantle). It does **not** remove the
  master password (zero-knowledge design), and `SSO_ONLY` would make an authentik
  outage lock you out of your password manager. Not recommended for v1.
- **Cleanup**: `modules/security/` is an empty leftover dir and
  `stacks/mantle/security.tf` holds an unused `kube-security` namespace. Unrelated
  to this work, but they are the reason this module is not `modules/security/vaultwarden`.
- **Dead config**: `deployment.dyndns_host` in `k8s.tfenv` (same `lg-route53` key,
  `FQDN = home.linuxguru.net`, `R53_ZONEID`) is a defunct dynamic-DNS setup —
  the site has a static IP now, and **no `.tf` file references it**. Safe to delete
  whenever; out of scope for this change.

## Bugs found nearby during testing (not this task — review separately)

`modules/cert_manager/external_cert.tf`:

- `zoneid = var.data["R53_ZONEID"]` is **not a valid field**. cert-manager logged
  `Warning: unknown field "spec.acme.solvers[0].dns01.route53.zoneid"` and pruned
  it, so the line has never pinned anything. Real route53 solver fields:
  `accessKeyID`, `accessKeyIDSecretRef`, `auth`, `hostedZoneID`, `region`, `role`,
  `secretAccessKeySecretRef`. Fix: rename to `hostedZoneID`.
- `http01 : {}` under `spec.acme` is also not a valid field (valid keys:
  `caBundle`, `disableAccountKeyGeneration`, `email`, `enableDurationFeature`,
  `externalAccountBinding`, `preferredChain`, `privateKeySecretRef`, `profile`,
  `server`, `skipTLSVerify`, `solvers`). Harmless but misleading: it reads like an
  HTTP-01 fallback exists when the only solver is DNS-01.
- **Open question**: external-dns did **not** create a bind9 record for the test's
  `certtest.vn.linuxguru.net` HTTPRoute despite the
  `external-dns.alpha.kubernetes.io/hostname` annotation (7+ minutes, nothing
  appeared). Worth understanding before relying on automatic `.vn` DNS for a new app.

## Read these first

- `README.md` — stack split, gateway/`expose` philosophy, the media + authentik patterns
- `modules/network/gateway/expose/README.md` and `modules/network/gateway/listener_set/main.tf`
  — the cert annotation, `cert-<fqdn>` naming, auto-created `ReferenceGrant`s
- `modules/media/plex/listener.tf` — reference caller for public gateway + letsencrypt
- `modules/media/qbittorrent/{deployment,service,listener}.tf` — hand-rolled app reference
- `modules/blender/{namespace,storage,secret,deployment}.tf` — namespace + PVC + secret patterns
- `modules/media/security.tf` and `modules/network/firewalls/limited_ingress/README.md` — netpol house style
- `modules/storage/seaweedfs/{monitoring,security}.tf` — ServiceMonitor + ingress guest list
- `TODO.md` — namespace-ingress rollout and owed notes
