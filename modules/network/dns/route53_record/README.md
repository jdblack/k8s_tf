# `route53_record` — a Terraform-authoritative Route53 record

One `aws_route53_record`, for the hosts external-dns cannot publish. Single
purpose, like [`../../firewalls/allow_api`](../../firewalls/allow_api/README.md).

```hcl
module "dns" {
  source  = "../network/dns/route53_record"
  zone_id = var.zone_id            # literal Z3FM4Y4P2572E4
  name    = "vaultwarden.linuxguru.net"
  records = ["192.168.0.100"]      # the private gateway
}
```

## Why this exists (i.e. why not external-dns)

- `external-dns` runs the **rfc2136** provider against bind9 with
  `domainFilters = ["vn.linuxguru.net"]` (`modules/network/charts.tf`). It is
  authoritative for `.vn` names only and **ignores** the
  `external-dns.alpha.kubernetes.io/hostname` annotation on a `linuxguru.net`
  host — so the route's annotation is harmless, not a conflict.
- `linuxguru.net` lives in **Route53**, where `*.linuxguru.net` is an `A` record
  pointing at the WAN IP. A host served by the **private** gateway therefore
  needs its own record, or clients get: wildcard → WAN IP → router → public
  gateway → no listener → TLS `unrecognized name`.

## "Authoritative" — what that actually means

| Want | How |
|---|---|
| Replace an existing record (including a multi-value round-robin set) | `allow_overwrite = true` (default). Without it the provider **errors** on a name+type collision rather than clobbering. |
| Revert out-of-band edits | The provider refreshes the record set on every plan, so a console edit appears as an in-place update and the next `apply` restores `records`. That is the whole authoritative property — and it is the drift test. |
| Fast settling | `ttl = 60`, matching the wildcard. |

## Traps

1. **The key needs `route53:GetHostedZone` — and not only for a `data` source.**
   `resourceRecordCreate` (provider source `internal/service/route53/record.go`)
   calls `findHostedZoneByID` as its *first* action, to read the zone **name**
   that the computed `fqdn` is derived from:

   ```go
   zoneID := cleanZoneID(d.Get("zone_id").(string))
   zoneRecord, err := findHostedZoneByID(ctx, conn, zoneID)
   if err != nil { return ... "reading Route 53 Hosted Zone (%s): %s" }
   ```

   Passing a literal `zone_id` does **not** avoid that call, and it sits on every
   create/read/update/delete path — so a policy with only
   `ChangeResourceRecordSets` + `ListResourceRecordSets` fails with:

   ```
   reading Route 53 Hosted Zone (Z3FM4Y4P2572E4): ... AccessDenied: ...
   not authorized to perform: route53:GetHostedZone
   ```

   (verified live 2026-09-13). `GetHostedZone` was therefore added to the
   `dyndns_linuxguru` policy, scoped to that single zone ARN. Keep passing the
   literal id regardless — `data "aws_route53_zone"` is an *extra* lookup you do
   not need, and `ListHostedZonesByName` is not a substitute.
2. **A `CNAME` at the same name blocks the `A` record** — Route 53 rejects it
   with `InvalidChangeBatch`. Delete the CNAME first.
3. Closing match wins over the wildcard: the more specific record supersedes
   `*.linuxguru.net` for that one name, which is the intended behaviour.

## Credentials

The caller's `aws` provider is configured from `var.deployment.cert`
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION`) — the same values
`modules/cert_manager/external_cert.tf` already uses to build the in-cluster
DNS-01 solver Secret, so this adds **no new secret exposure**. That principal is
`arn:aws:iam::169232240393:user/lg-route53`, with the managed policy
`dyndns_linuxguru`:

| Action | Resource |
|---|---|
| `route53:ChangeResourceRecordSets`, `route53:ListResourceRecordSets`, **`route53:GetHostedZone`** | `arn:aws:route53:::hostedzone/Z3FM4Y4P2572E4` |
| `route53:GetChange` | `arn:aws:route53:::change/*` |
| `route53:ListHostedZonesByName` | `*` |

`GetHostedZone` was added (2026-09-13, policy version v4) because the record
resource calls it unconditionally — see Trap 1. It is still **zone-scoped**: the
key cannot touch other zones, create zones, or delete the hosted zone — **do not
swap it for a broader key.**
