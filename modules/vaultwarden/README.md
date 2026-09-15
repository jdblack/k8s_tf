# `vaultwarden` — self-hosted Bitwarden server on the private gateway

Hand-rolled, no chart: Deployment + PVC + Service + Secret, so this module owns
the `Recreate` strategy, the config Secret and the deliberately absent admin
panel. Snapshotting is *not* decided here — it is cluster policy in
[`../storage/longhorn_jobs.tf`](../storage/longhorn_jobs.tf).

```
https://vaultwarden.linuxguru.net   ->  private gateway (MetalLB VIP, .100 today)
                                    ->  vaultwarden:80 (ClusterIP, RWO PVC /data)
```

LAN and WireGuard only. **Not** reachable from the internet: the A record is an
RFC1918 address and the public gateway has no listener for the host (fails
closed with TLS `unrecognized name`). The cert is publicly trusted.

## Two deliberate choices

1. **A publicly-trusted cert on a private gateway.** The issuer is the
   deployment default (`letsencrypt`; DNS-01/route53 is its only solver), so
   issuance needs no inbound reachability and no phone installs a CA. This host
   was simply the first one on it — every host is now. The gateway-shim
   mechanism is unchanged (`cert-manager.io/cluster-issuer` annotation →
   `Certificate` `cert-<fqdn>` → TLS `certificateRefs`), so moving the
   `ListenerSet` to the public gateway later is a one-line change with zero
   client reconfiguration (clients pin the server URL).
2. **The hostname is `linuxguru.net`, with a Terraform-managed A record.** The
   `*.linuxguru.net` wildcard points at the WAN IP and external-dns owns
   `vn.linuxguru.net` only, so nothing automatic can publish this host. `dns.tf`
   ([`../network/dns/route53_record`](../network/dns/route53_record/README.md))
   creates an authoritative `A`, ttl 60, whose value is read off the private
   gateway's live data-plane Service (`stacks/mantle/vaultwarden.tf`) — the VIP
   floats, so the record tracks it instead of freezing an address. Without the
   record, LAN clients follow the wildcard out to the internet and hairpin into
   the public gateway.

**No authentik proxy outpost here, on purpose.** Clients are not browsers — they
POST to `/identity/connect/token`, call `/api/*` with bearer tokens, and hold a
`/notifications/hub` websocket. An outpost 302s those to a login page and breaks
every client. `/admin` is disabled instead (`ADMIN_TOKEN` unset — see
`secret.tf`), and config lives in Terraform.

## Files

| File | What |
|---|---|
| `namespace.tf` | its own `vaultwarden` namespace (one netpol blast radius) |
| `secret.tf` | the whole env config; **no `ADMIN_TOKEN`** |
| `deployment.tf` | `kubernetes_deployment_v1` (`replicas = 1`, `strategy = Recreate`) + the `vaultwarden-data` PVC |
| `service.tf` | ClusterIP `80` — no LoadBalancer, so no LAN path bypasses the gateway |
| `listener.tf` | `expose`: ListenerSet on the `private` gateway + HTTPRoute to the Service |
| `dns.tf` | the authoritative Route53 A record |
| `security.tf` | egress `basic_internet`; ingress `limited_ingress` = self + `kube-network`, no CIDRs |
| `disaster_recovery.md` | what a restore costs here; mechanics in [`../storage/disaster_recovery.md`](../storage/disaster_recovery.md) |

`strategy = Recreate` is required (RWO PVC; a rolling update deadlocks waiting
for the old pod to release the volume), and the pod template carries a
`checksum/config` annotation from the config Secret so a setting change actually
rolls the pod — Kubernetes never restarts pods for a Secret alone.

## Configuration (env, in `secret.tf`)

| env | value | why |
|---|---|---|
| `DOMAIN` | `https://vaultwarden.linuxguru.net` | cookies, attachment URLs, websocket URL |
| `DATA_FOLDER` | `/data` | matches the PVC mount |
| `ROCKET_PORT` | the module's `port` | keeps app port == Service/container port |
| `ENABLE_WEBSOCKET` | `true` | live client sync; rides the **same** port on 1.3x |
| `SIGNUPS_ALLOWED` | `false` (var `signups_allowed`) | no self-registration — see "First-run bootstrap" |
| `INVITATIONS_ALLOWED` | `false` | no org invites |
| `SENDS_ALLOWED` | `false` | no Bitwarden "Send" |
| `PASSWORD_HINTS_ALLOWED` | `false` | unauth endpoint off |
| `EMERGENCY_ACCESS_ALLOWED` | `false` | unauth endpoint off |
| `LOGIN_RATELIMIT_SECONDS` / `_MAX_BURST` | `60` / `10` | brute-force brake, per client because NGF sets `X-Real-IP` (vaultwarden's default `IP_HEADER`) |
| `ADMIN_TOKEN` | **unset** | no admin panel: `/admin` returns plain-text `200` "panel is disabled", every `/admin/*` API path `404`s. If ever set, use an argon2 hash, never plaintext |

**No metrics.** 1.37.3 has no `/metrics` and no `PROMETHEUS_ENABLED` (the build
feature was dropped upstream); the only health route is `GET /alive`, hence no
ServiceMonitor. Re-check upstream before adding one — and then also add
`monitoring` to the ingress guest list in `security.tf`.

## Snapshots

Cluster policy, not app config: `vaultwarden-data` is enrolled in
`daily` + `weekly` + `monthly` (retain 2 each) by
[`../storage/longhorn_jobs.tf`](../storage/longhorn_jobs.tf) and labelled by
[`../storage/snapshot_labeler.tf`](../storage/snapshot_labeler.tf), which writes
the group label onto the Longhorn **Volume CR** — never onto this PVC, because a
PVC carrying `recurring-job.longhorn.io/*` *replaces* its volume's whole group
set instead of merging, silently de-enrolling it from every tier. This module
did exactly that (per-app `backup.tf`, retain 7, group named after the app, plus
the `source: enabled` PVC label) until 2026-09-16. Retirement rationale: uniform
tiers beat per-app sentiment, and every Bitwarden client already holds a full
copy of the vault.

Restore mechanics (revert needs maintenance mode; the manager API is
in-cluster only) are in
[`../storage/disaster_recovery.md`](../storage/disaster_recovery.md); what a
vaultwarden restore specifically costs is in
[`disaster_recovery.md`](disaster_recovery.md).

**Snapshots are cluster-local**: they belong to the volume, and destroying this
module deletes the PVC (`longhorn` StorageClass is `reclaimPolicy: Delete`).
Until an offsite S3 `backupTarget` exists, **export from a client before any
destroy** and treat the cluster as one failure domain. Attachment blobs are in
neither the client cache nor a standard export.

## Offline behaviour (accepted design, not a bug list)

- **Works offline from cache**: reading/copying items, search, autofill, TOTP
  codes (the seeds live in the vault).
- **Does NOT work offline**: creating/editing items (no offline write queue in
  the clients), attachment downloads, new-device enrolment / re-login.
- **Cache loss = lockout**: a reinstall, iOS storage eviction or an invalidated
  session means no access until you are home or on WireGuard. Keep two enrolled
  clients (phone + laptop) so losing one does not strand you.
- **WireGuard is the escape hatch** (`modules/network/wireguard`: full tunnel,
  DNS `192.168.0.2`). It is UDP-only on `home.linuxguru.net:51820`, so a network
  that blocks UDP defeats it.
- **A phone/laptop is not a backup**: see the export caveat above.

## Verifying

```sh
dig +short vaultwarden.linuxguru.net                 # the private gateway's VIP (.100 today)

echo | openssl s_client -connect vaultwarden.linuxguru.net:443 \
  -servername vaultwarden.linuxguru.net 2>/dev/null | openssl x509 -noout -issuer -subject
# -> issuer=... O=Let's Encrypt ...   subject=CN=vaultwarden.linuxguru.net

curl -sI https://vaultwarden.linuxguru.net/          # 200 (web vault)
curl -s https://vaultwarden.linuxguru.net/admin      # 200 text/plain "panel is disabled"
curl -s -o /dev/null -w '%{http_code}\n' \
     https://vaultwarden.linuxguru.net/admin/diagnostics   # 404 - no admin API

kubectl -n vaultwarden get listenerset,certificate,pvc,pod
kubectl -n longhorn-system get volumes.longhorn.io -o json | \
  grep -A2 vaultwarden | grep recurring-job-group
# must show daily/weekly/monthly=enabled and NOT .../vaultwarden (retired group)
```

DNS TTL is 60, so if `dig` still returns the WAN IP you are seeing the wildcard
— wait a minute, don't "fix" it. The `A` record and the `ListenerSet` are
independent; browsers need both (cert `Ready` in ~30-90 s, DNS inside the TTL).
The ListenerSet briefly reports `InvalidCertificateRef: Secret
vaultwarden/cert-vaultwarden.linuxguru.net does not exist` then flips to
`Accepted/Programmed=True` on its own — no `depends_on` hacks.

Drift test (this is the "authoritative" requirement):

```sh
aws route53 change-resource-record-sets --hosted-zone-id Z3FM4Y4P2572E4 --change-batch \
 '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"vaultwarden.linuxguru.net",
  "Type":"A","TTL":60,"ResourceRecords":[{"Value":"192.168.0.99"}]}}]}'
tofu -chdir=stacks/mantle plan    # must want to change it back
tofu -chdir=stacks/mantle apply
```

## Operational notes

- **First-run bootstrap (there is no CLI user-create).** Set `signups_allowed =
  true` in `stacks/mantle/vaultwarden.tf`, apply, register at
  `https://vaultwarden.linuxguru.net/#/register`, set it back to `false`, apply.
  While true, anyone who can reach the host can create an account — a small
  window (LAN/WireGuard only), but don't leave it on.
- **The admin panel is never needed.** Everything it configures is in
  `secret.tf`, and it is the one component that can silently diverge from
  Terraform: it writes `/data/config.json`, and **vaultwarden gives that file
  precedence over these env vars**. Enable it only for a one-off (e.g. inviting a
  user, which needs an `ADMIN_TOKEN`), then remove the token — otherwise a panel
  edit looks like it "didn't stick" after the next apply, or worse sticks while
  TF claims ownership.
- **Rollback caution**: destroying this module deletes the PVC and with it the
  snapshots. Export from a client first.
- AWS credentials come from `var.deployment.cert` — the least-privilege
  `lg-route53` key `modules/cert_manager` already uses, plus
  `route53:GetHostedZone`, because `aws_route53_record` reads the zone on every
  CRUD path ([`../network/dns/route53_record/README.md`](../network/dns/route53_record/README.md)).
  It stays scoped to the one zone — don't widen it.
- Fresh-cluster ordering: `stacks/core` before `stacks/mantle`. Snapshot
  enrolment happens in `stacks/core`, which runs *before* this PVC exists —
  re-apply `stacks/core` after `stacks/mantle` so the labeler finds the volume
  (it warns and skips otherwise).
- Cert issuance sharp edge: `challenge.spec.solver` is a frozen snapshot, so
  editing the `ClusterIssuer` does not fix an in-flight challenge. Delete the
  CertificateRequest/Order/Challenge chain; if a Challenge is stuck
  `Terminating`, strip its finalizer
  (`kubectl patch challenge <name> -n vaultwarden --type=merge -p '{"metadata":{"finalizers":null}}'`).


