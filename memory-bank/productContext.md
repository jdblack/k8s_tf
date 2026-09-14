# Product Context — why this repo is shaped the way it is

## The problem it solves

One cluster, one operator (jblack), no CI, no cloud. Everything must be
reproducible from this repo plus one tfvars file, and a `tofu plan` must be a
meaningful drift check.

## Why three stacks (the load-bearing constraint)

OpenTofu **cannot configure a service in the same apply that creates it**, when
the configuration needs a provider that does not exist until that service is
serving, and whose credentials are minted from that same apply. Harbor,
authentik and Argo CD are all this shape. Hence three root modules, each with
its own state, applied in order:

| Stack | Owns | State Secret (`kube-system`) |
|---|---|---|
| `stacks/core` | network, storage, certs, authentik, monitoring, Harbor, Argo CD, VPN, Gateway API CRDs | `tfstate-default-core` |
| `stacks/mantle` | everything needing a provider core just built: media, blender, vaultwarden, seaweedfs-admin, whisker, Grafana/Harbor/Argo SSO | `tfstate-default-mantle` |
| `stacks/apps` | ArgoCD app-of-apps (`ai`; two wordpress deployments parked as `*.tf.disabled`) | `tfstate-default-deployment` |

Order matters on a fresh cluster: `core` installs the Gateway API CRDs, and
`mantle`'s HTTPRoutes are `kubernetes_manifest`s that need those CRDs at **plan**
time. A stale `tfstate-default-fuckbatz` Secret also sits in `kube-system`
(unreferenced, safe to delete).

## UX / access model

Three access patterns, chosen by **what the clients are**, not preference:

| Pattern | Used by | Why |
|---|---|---|
| authentik **proxy outpost** (gateway → outpost → app) | arr apps, qbittorrent web UI, SeaweedFS admin UI, whisker | app speaks no OIDC, clients are browsers |
| authentik **OIDC** | Grafana, Harbor, Argo CD, Argo Workflows | app speaks OIDC natively |
| **no auth in front** | `auth.` itself, SeaweedFS master/S3, plex, vaultwarden | non-browser clients, or the service *is* the IdP |

Only two ways in: **public** gateway (`192.168.0.101`, WAN-forwarded) and
**private** gateway (`192.168.0.100`, LAN + WireGuard only). Both drop plain
HTTP — HTTPS is the only way through. Media apps sit on a third,
namespace-local gateway (`media-private`, `192.168.0.106`).

The full hostname table (host → gateway → fronted-by → cert issuer) lives in the
root `README.md` § "What is exposed where". Known gap: `ollama.vn.linuxguru.net`
has **no auth** and is created outside this repo.

## Deliberate compromises (documented, not accidental)

- **Secrets in tfvars.** `.gitignore` lists `terraform.tfvars`, but core/mantle's
  copies are **tracked anyway** — they carry the Route53 key, the bind9 TSIG
  secret and the Argo deploy key, and the stacks cannot plan without them. Treat
  them as secrets. `stacks/apps` has no tfvars at all.
- **Alertmanager has no receiver** (stock `null`). Alerts are visible in the UI
  only.
- **No authentik outpost on vaultwarden, on purpose** — clients aren't browsers.
- **`linuxguru-ca` for every `.vn` host** — clients install `~/.ssl/ca.crt`.
  Retiring it is an open idea (`TODO.md`).
