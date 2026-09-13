# `vaultwarden` — self-hosted Bitwarden server on the private gateway

A Bitwarden-compatible server, hand-rolled (no chart: the workload is a
Deployment + PVC + Service + Secret + a Longhorn RecurringJob, and a chart-owned
PVC could not carry the recurring-job-group label).

```
https://vaultwarden.linuxguru.net   ->  private gateway (192.168.0.100)
                                    ->  vaultwarden:80 (ClusterIP, RWO PVC /data)
```

LAN and WireGuard only. **Not** reachable from the internet: the A record is an
RFC1918 address and the public gateway has no listener for the host (it fails
closed with TLS `unrecognized name`). The cert is publicly trusted.

## Two things that look wrong and are not

1. **`cert_issuer = "letsencrypt"` on a private gateway.** Every other
   private-gateway app uses the `linuxguru-ca` issuer. This one uses the public
   issuer, whose only solver is `dns01/route53` — so issuance needs no inbound
   reachability, and no phone has to install a CA. The gateway-shim mechanism is
   unchanged (`cert-manager.io/cluster-issuer` annotation → `Certificate`
   `cert-<fqdn>` → TLS `certificateRefs`), so moving the `ListenerSet` to the
   public gateway later is a one-line change with **zero client
   reconfiguration** — Bitwarden clients pin the server URL.
2. **The hostname is `linuxguru.net`, with a Terraform-managed A record.** The
   `*.linuxguru.net` wildcard points at the WAN IP, and external-dns is
   authoritative for `vn.linuxguru.net` only, so nothing automatic can publish
   this host. `dns.tf` → [`../network/dns/route53_record`](../network/dns/route53_record/README.md)
   creates an authoritative `A → 192.168.0.100`, ttl 60. Without it, LAN clients
   follow the wildcard out to the internet and hairpin into the public gateway.

Also note: **there is no authentik proxy outpost here, on purpose.** The clients
are not browsers — they POST to `/identity/connect/token`, call `/api/*` with
bearer tokens, and hold a `/notifications/hub` websocket. An outpost 302s those
to a login page and breaks every client. `/admin` is disabled instead
(`ADMIN_TOKEN` unset — see `secret.tf`), and config lives in Terraform.

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
| `backup.tf` | Longhorn `RecurringJob` (nightly snapshot, retain 7) |

`strategy = Recreate` is required: the PVC is RWO, and a rolling update would
deadlock waiting for the old pod to release the volume. The pod template also
carries a `checksum/config` annotation derived from the config Secret, so a
`tofu apply` that changes any setting actually rolls the pod — Kubernetes does not
restart pods when only a Secret changes.

## Configuration (env, in `secret.tf`)

| env | value | why |
|---|---|---|
| `DOMAIN` | `https://vaultwarden.linuxguru.net` | cookies, attachment URLs, websocket URL |
| `DATA_FOLDER` | `/data` | matches the PVC mount |
| `ROCKET_PORT` | the module's `port` | keeps app port == Service/container port |
| `ENABLE_WEBSOCKET` | `true` | live client sync; rides the **same** port on 1.3x |
| `SIGNUPS_ALLOWED` | `false` (module var `signups_allowed`) | no self-registration — see "First-run bootstrap" |

| `INVITATIONS_ALLOWED` | `false` | no org invites |
| `SENDS_ALLOWED` | `false` | no Bitwarden "Send" |
| `PASSWORD_HINTS_ALLOWED` | `false` | unauth endpoint off |
| `EMERGENCY_ACCESS_ALLOWED` | `false` | unauth endpoint off |
| `LOGIN_RATELIMIT_SECONDS` / `_MAX_BURST` | `60` / `10` | brute-force brake, per client thanks to `X-Real-IP` (which NGF sets, and which is vaultwarden's default `IP_HEADER`) |
| `ADMIN_TOKEN` | **unset** | no admin panel. Unset ⇒ `/admin` returns a plain-text `200` saying the panel is disabled, and every `/admin/*` API path (diagnostics, users, login) `404`s. If ever set, use an argon2 hash, never plaintext |

**No metrics.** vaultwarden 1.37.3 has no `/metrics` and no `PROMETHEUS_ENABLED`
(the metrics build feature was dropped upstream); the only health route is
`GET /alive`. There is therefore no ServiceMonitor here — re-check upstream in a
later release before adding one (and then add `monitoring` to the ingress guest
list in `security.tf`).

Rate-limited login works as intended because NGF sets `X-Real-IP`, so requests
arrive with the real client address rather than the gateway's.

## Backups

The `RecurringJob` snapshots the volume nightly and keeps 7. The join is by
**group**, and it takes two labels on the PVC (Longhorn ignores PVC group labels
unless the PVC is explicitly opted in as the label source — see
[`20230517-set-recurring-job-to-pvc.md`](https://github.com/longhorn/longhorn/blob/master/enhancements/20230517-set-recurring-job-to-pvc.md)):

| PVC label | Why |
|---|---|
| `recurring-job.longhorn.io/source: enabled` | opts the PVC in as the recurring-job label source for its volume. **Without it the group label is ignored** and the volume keeps its own `default` group, so the job never fires. The value must be `enabled`: longhorn-manager compares against `types.LonghornLabelValueEnabled`, and the enhancement doc's `enable` is silently ignored (the volume controller only debug-logs *"Ignoring recurring job labels … due to missing source label"*). |
| `recurring-job-group.longhorn.io/vaultwarden: enabled` | the group membership; Longhorn syncs it onto the volume, where the job's `spec.groups = ["vaultwarden"]` matches it. |

Because the PVC label source *overrides* the volume's own labels, the CSI-added
`recurring-job-group.longhorn.io/default` label is dropped once the source label
lands — the volume ends up in the `vaultwarden` group only.

Verify with `kubectl -n longhorn-system get volumes.longhorn.io <vol> -o jsonpath='{.metadata.labels}'` — the `recurring-job-group.longhorn.io/vaultwarden` label must appear on the **volume**, not just the PVC.

**Snapshots are cluster-local.** They belong to the volume, so:

- losing the cluster (or its disks) loses them,
- `tofu destroy` of this module deletes the PVC, and the `longhorn`
  StorageClass is `reclaimPolicy: Delete` — the snapshots go with it.

Until an offsite S3 `backupTarget` exists (see `TODO.md`), **export from a client
before any destroy**, and treat the cluster as one failure domain. Note that
attachment blobs are not in the client cache and not in a standard export.

## Offline behaviour (accepted design, not a bug list)

- **Works offline from cache**: reading/copying items, search, autofill, and TOTP
  codes (the seeds live in the vault).
- **Does NOT work offline**: creating/editing items (Bitwarden clients have no
  offline write queue), attachment downloads (not cached), and new-device
  enrolment / re-login (always needs the server).
- **Cache loss = lockout**: a reinstall, iOS storage eviction, or an invalidated
  session means no access until you are home or on WireGuard. Keep two enrolled
  clients (phone + laptop) so losing one does not strand you.
- **WireGuard is the escape hatch** (`modules/network/wireguard`: full tunnel,
  pushes `192.168.0.2` as DNS). Caveat: it is UDP-only on
  `home.linuxguru.net:51820`, so a network that blocks UDP defeats it.
- **A phone/laptop is not a backup**: attachment blobs are not in the client
  cache and not in a standard export.

## Verifying

```sh
dig +short vaultwarden.linuxguru.net                 # 192.168.0.100

echo | openssl s_client -connect vaultwarden.linuxguru.net:443 \
  -servername vaultwarden.linuxguru.net 2>/dev/null | openssl x509 -noout -issuer -subject
# -> issuer=... O=Let's Encrypt ...   subject=CN=vaultwarden.linuxguru.net

curl -sI https://vaultwarden.linuxguru.net/          # 200 (web vault)
curl  -s  https://vaultwarden.linuxguru.net/admin    # 200 text/plain: "The admin
                                                     # panel is disabled, please
                                                     # configure the 'ADMIN_TOKEN'"
curl -s -o /dev/null -w '%{http_code}\n' \
     https://vaultwarden.linuxguru.net/admin/diagnostics   # 404 - no admin API

kubectl -n vaultwarden get listenerset,certificate,pvc,pod
kubectl -n longhorn-system get recurringjobs.longhorn.io
```

DNS propagation: the A record is created with TTL 60. If `dig` still returns the
WAN IP you are seeing the wildcard — wait a minute, don't "fix" it.

The `A` record and the `ListenerSet` are independent; browsers need both (cert
`Ready` in ~30-90 s, DNS inside the 60 s TTL). The ListenerSet briefly reports
`InvalidCertificateRef: Secret vaultwarden/cert-vaultwarden.linuxguru.net does
not exist` and then flips to `Accepted/Programmed=True` on its own — no
`depends_on` hacks needed.

Drift test (this is the "authoritative" requirement):

```sh
aws route53 change-resource-record-sets --hosted-zone-id Z3FM4Y4P2572E4 --change-batch \
 '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"vaultwarden.linuxguru.net",
  "Type":"A","TTL":60,"ResourceRecords":[{"Value":"192.168.0.99"}]}}]}'
tofu -chdir=stacks/mantle plan    # must want to change it back
tofu -chdir=stacks/mantle apply
```

## Operational notes

- **First-run bootstrap (there is no CLI user-create).** The first account is
  made through the web vault's registration form, which needs
  `SIGNUPS_ALLOWED=true`: set `signups_allowed = true` in
  `stacks/mantle/vaultwarden.tf`, apply, register at
  `https://vaultwarden.linuxguru.net/#/register`, then set it back to `false` and
  apply again. While it is true, anyone who can reach the host can create an
  account — the host is LAN/WireGuard-only, so that is a small, brief window, but
  don't leave it on.
- **Do you ever need the admin panel? No.** Everything it configures — and more —
  is in `secret.tf` here, and it is the one component that can silently diverge
  from Terraform: the panel writes `/data/config.json`, and **vaultwarden gives
  `config.json` precedence over these environment variables**. Enable it only for
  a one-off (e.g. inviting a second user as an alternative to a signup window,
  which needs an `ADMIN_TOKEN`), then remove the token again — otherwise a panel
  edit will look like it "didn't stick" after the next `apply`, or worse, will
  stick while Terraform still claims ownership.
- **Rollback caution**: `tofu destroy -target=module.vaultwarden` deletes the
  PVC and, with it, the snapshots (see "Backups"). Export from a client first.
- The AWS credentials come from `var.deployment.cert` — the least-privilege
  `lg-route53` key `modules/cert_manager` already uses for the DNS-01 solver.
  It needed one addition for this module: `route53:GetHostedZone`, because
  `aws_route53_record` reads the zone on every CRUD path (see
  [`../network/dns/route53_record/README.md`](../network/dns/route53_record/README.md),
  Trap 1). It remains scoped to the one zone — don't widen it further.
- Fresh-cluster ordering: `stacks/core` before `stacks/mantle` (the HTTPRoute
  needs the Gateway API CRDs at plan time), and Longhorn's CRD must exist before
  `backup.tf` applies — both hold in the documented stack order.
- Cert issuance has one sharp edge: `challenge.spec.solver` is a frozen snapshot,
  so editing the `ClusterIssuer` does not fix an in-flight challenge. Delete the
  CertificateRequest/Order/Challenge chain; if a Challenge is stuck
  `Terminating`, strip its finalizer
  (`kubectl patch challenge <name> -n vaultwarden --type=merge -p '{"metadata":{"finalizers":null}}'`).
