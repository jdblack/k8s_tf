# `media` — the arr stack, its gateway, and its authentik outpost

One namespace (`media`) holding sonarr / radarr / prowlarr / bazarr (helm charts,
each in its own submodule), plex, a hand-rolled qbittorrent, the namespace-local
**`media-private` NGF gateway** (`api_gateway.tf`, VIP from the MetalLB pool,
currently `.106` — like every gateway in this repo, none is IP-pinned in code),
and the shared authentik outpost.

Non-HTTP ingress: plex also listens on its own LoadBalancer, and qBittorrent
peers connect to the `qbittorrent-torrent` VIP on port `21010` (currently
`192.168.0.105`) — never through authentik.

## Pins, and who owns what on `/media`

- **Chart versions** are the `helm_version` defaults in each app module's
  `variables.tf` (sonarr `2.2.3`, radarr `3.6.4`, prowlarr `3.8.4`, bazarr
  `2.3.1`). qbittorrent is hand-rolled and pins an image tag instead — `image` /
  `image_tag` in `modules/media/qbittorrent/variables.tf`; its deployment uses
  `strategy: Recreate` for the same reason the charts do (one replica + a
  ReadWriteOnce config PVC: a RollingUpdate can land the surge pod on another
  node and deadlock on the volume).
- **Every app that mounts the shared `media` PVC runs as `1000:1000`**
  (`securityContext` in each app's `locals.tf`) so that files one app writes stay
  readable *and* writable by the others. The chart default group is 65534, which
  is what used to leave one app unable to touch the others' files. Prowlarr
  never mounts the PVC and keeps the chart default. Change one, change all.

## Authentik in front of the apps (arr + qbittorrent web UI)

None of these speak OIDC, so authentik fronts them as a **proxy outpost**
(`modules/auth/authentik/proxy_outpost`):

```
browser -> sonarr.vn.linuxguru.net (media-private gateway, TLS)
         -> authentik outpost (media namespace, :9000)   <- no session = 302 to auth.vn.linuxguru.net
         -> sonarr:80 (X-authentik-* headers injected)
```

- `auth.tf` wires it up: per-app authentik proxy providers + applications + the
  shared `media-proxy` outpost, all bound to the **`media`** group. The *arr
  apps' chart-generated HTTPRoutes are disabled and each app module renders its
  own route to the outpost instead (`listener.tf`, via the `auth_backend`
  variable); the port differs per app (arr charts `:80`, qbittorrent web UI
  `:8080`). qbittorrent is hand-rolled (no chart) so it already owned its route —
  it uses the same `gateway/expose` call and arguments as the arr apps.
- **Access control** = membership in the `media` group in authentik, managed by
  hand in the UI (TF never touches users — same as harbor/argo). Nobody can see
  the apps until you add them.
- Adding another protected app: add it to the `auth_apps` map in `auth.tf` and
  instantiate its module (with `auth_backend`) in `arr_stack.tf`.

## qbittorrent is a special case — only the web UI is fronted

- The **torrent port (21010) is deliberately NOT behind the outpost** — peers
  can't log in. It lives on its own `qbittorrent-torrent` LoadBalancer Service,
  whose VIP floats like everything else here (`qbittorrent_torrent_lb_ip` is
  unset in `stacks/mantle/terraform.tfvars`; set it there to re-pin). **This is
  the one address DNS cannot cover**: the home router forwards WAN 21010 to it,
  and name resolution is not in the path of an inbound NAT rule. MetalLB holds an
  address for the life of its Service, so an ordinary `apply` never moves it —
  but if this Service is ever *recreated* (destroy/apply, cluster rebuild) it
  takes a new pool IP and the router forward has to be re-pointed.
- The **web UI is a ClusterIP Service** (`qbittorrent:8080`), so it is only
  reachable through the gateway/outpost — no LAN-side IP that bypasses authentik.
- The *arr apps must point their qBittorrent **download client at `qbittorrent`
  port `8080`** (the in-cluster Service). Using the LB IP, or the authenticated
  `qbittorrent.<domain>` hostname, breaks: the latter hits authentik and gets a
  login redirect, not the API.

## One-time per-app setup (not in Terraform, redone after a rebuild)

sonarr/radarr/prowlarr run with `AuthenticationMethod = External` (config.xml,
set once through their own API) so there's no second login prompt. On a
from-scratch rebuild the app config PVCs start fresh and this must be redone:

```sh
kubectl -n media exec deploy/<app> -- sh -c 'KEY=$(grep -o "<ApiKey>[^<]*" /config/config.xml | sed "s/<ApiKey>//" | head -1); CFG=$(curl -s -H "X-Api-Key: $KEY" http://localhost:<port>/api/v3/config/host); curl -s -X PUT -H "X-Api-Key: $KEY" -H "Content-Type: application/json" -d "$(echo "$CFG" | jq ".authenticationMethod=\"external\"")" http://localhost:<port>/api/v3/config/host'
```

Ports: sonarr 8989, radarr 7878, prowlarr 9696 (`api/v1`).

qBittorrent has no trusted-header auth, so it can't use `External`. Instead it
**bypasses its own login for the pod CIDR** (Calico `10.244.0.0/16`): the outpost
proxies from a pod, so there's no second prompt. Set once in
`/config/qBittorrent/qBittorrent.conf` under `[Preferences]`:
`WebUI\AuthSubnetWhitelistEnabled=true` and
`WebUI\AuthSubnetWhitelist=10.244.0.0/16`. Editing the file while qBittorrent
runs is **not** enough — it rewrites the file from memory on a graceful exit — so
patch it and then hard-kill the pod so the new one reads the patch:

```sh
kubectl -n media delete pod -l app.kubernetes.io/name=qbittorrent --grace-period=0 --force
```

(`WebUI\ServerDomains=*` is already set, so host-header validation doesn't block
the proxy. The web UI Service being ClusterIP-only is why this whitelist doesn't
weaken external exposure.)

## NetworkPolicy: one namespace profile plus three pod-scoped exceptions

Four `Egress` policies, from 2026-09-17. The rule they implement, stated as three lines: **the
namespace may talk to itself, it may reach the internet, and it is granted neither the LAN nor the
cluster.** The gateway is the only thing here that gets the API server.

`Ingress` is one call, added the same day: **the floor is the whole guest list** — own namespace plus the
node addresses — for every pod here except the three whose door is not a pod (below). So the door list is
short by construction: LAN clients and torrent peers reach their LoadBalancers, the gateway data plane
reaches the outpost and the apps (same namespace, so the self rule carries it), and nothing else in the
cluster may open a connection here at all.

| Policy | Selects | May dial |
|---|---|---|
| `media-baseline-egress` | `podSelector: {}` — every pod, present and future | own namespace, DNS, the public internet |
| `ngf-egress` | `app.kubernetes.io/name=nginx-gateway-fabric` (control plane) | ... plus the API server |
| `ngf-cert-generator-egress` | `job-name=ngf-nginx-gateway-fabric-cert-generator` (the chart's hook pod) | ... plus the API server |
| `authentik-outpost-egress` | `app.kubernetes.io/name=authentik-outpost` | ... plus kube-auth's `authentik`/`server` pod, `:9000` only |
| `media-ingress` | every pod *except* `app.kubernetes.io/name` `plex-media-server`, `qbittorrent`, `media-private-media-private` | may be *dialled by* own namespace and the node addresses, nothing else |

**The three exclusions are the interesting half of `media-ingress`, and each is a pod whose callers are
not pods:** plex (`:32400` through its own LoadBalancer, from the LAN and from `PUBLIC NETWORK`, plus the
`public` gateway for the web UI — the only two cross-namespace inbound peers this namespace has),
qbittorrent (the same shape on `:21010`), and the `media-private` data plane, which is the LAN front door
for every arr UI. All three LoadBalancers are `externalTrafficPolicy: Local`, so a LAN client's address
survives to the pod and no peer list can state it; the other gateway data planes in the cluster are left
just as open (`network/netpols.tf` curates neither `private-private` nor `public-public`). Excluding a pod
is not "restricting it differently" — a carve leaves it exactly as open as it was, since policies only
union — so this is a decision to keep three WAN-facing doors as they are, not a tightening of them. The
expression is a single `NotIn`, which also matches a pod that lacks the key entirely: the hand-made
`utility` pod and anything created here later land *inside* the curtain without being written down
(`../network/firewalls/ingress/README.md`, `.clinedocs/calico-netpols.md`).

The guest list is the floor, so the flows that make the apps work are not written down and must be
checked by shape instead: `bazarr -> sonarr :8989`, `sonarr`/`radarr -> qbittorrent :8080`, the
outpost's config fetch, and the data plane walking the app Services on `:80` are all **in-namespace**, and
the one of those Whisker ever shows is the data plane's gRPC to the control plane on `:8443` — nginx
holds its upstreams open, and a connection that never ends is never emitted into the flow log.

Calico unions the rules of every policy selecting a pod, so the first row is a floor and the other
three only add. That is what makes the shape cheap — and it is why **the six apps and the gateway
data plane lost their calls on 2026-09-17**: `sonarr-egress` and friends (one per app submodule) and
`media-private-dataplane-egress` all rendered self + DNS + internet, i.e. exactly the floor, so they
were no-ops. The app submodules no longer carry an `egress.tf` at all, which means the answer to
"what may sonarr dial?" is now "whatever the namespace may dial". Losing per-app granularity is the
deliberate price of doing this at the namespace level, so it is recorded rather than hidden.

What the floor cannot give back **as it stands**: a pod-scoped call only *adds* to a floor, so the
internet grant cannot be subtracted by writing another policy — `ngf-egress` and the outpost peer
widen, never narrow. Subtracting means a **move**: the floor drops `allow_internet` and each app
submodule carries its own, which is exactly how `harbor-trivy-egress`,
`cert-manager-controller-egress` and argo's gateway peers subtract for one pod. That is expressible,
not impossible — it is declined on object count (six app calls to replace one floor), and the
consequence is named rather than hidden: the **NGF control plane, the outpost and any future pod here
hold the public internet** (`0.0.0.0/0` minus RFC1918). Revisit it the day either of those two stops
being trusted.

Read off the live cluster (Whisker, `source_namespaces=media`) rather than assumed, with one
exception: the NGF control plane's API access never appears in a flow log, because long-lived watch
connections are not emitted. That peer is a construction argument, verified by restarting the
control plane under the policy and watching it do a full sync (version banner, seven config updates,
reconnect to the nginx agent) with the Gateway still `Accepted=True Programmed=True`.

Two of the four exist because of something a namespace profile cannot know about:

- **The cert-generator hook pod is a pod no chart label covers.** The NGF chart renders that Job's
  `spec.template` with annotations and **no `labels` at all**, so its pod carries only
  `job-name=<fullname>-cert-generator` (checked against a live Job pod — v1.35 sets `job-name` and
  `batch.kubernetes.io/job-name`), and `ngf-egress` selects the controller label, so it never covered
  it. Before the floor existed the hook fell through to default-allow — the only reason NGF upgrades
  kept working after the firewall layer was deleted on 2026-09-16 — and under the floor alone it dies
  in the pre-upgrade hook (measured: `rc=28` against `https://10.96.0.1:443/api`, where a
  controller-labeled pod gets `403`, same second). `ngf-cert-generator-egress` is that pod's call, and
  the Job name comes from the gateway module's `cert_generator_job_name` output rather than a
  hardcoded chart internal, so it follows a renamed release.
- **The outpost's identity peer is the only cross-namespace grant here**, and it is one pod selector
  on one port: `kube-auth`'s `authentik`/`server` pod on `:9000`, which is the port the flow logs
  name. It used to be `to_namespaces = ["kube-auth"]` — every pod in the identity namespace on every
  port, the database and the worker included.

## What a compromised app can reach (measured 2026-09-17)

A throwaway `alpine` pod carrying **sonarr's exact labels** (so it inherits sonarr's policy
byte-for-byte) swept the cluster with `nc -z`. This is the lateral-movement surface a single owned
app has, and it is the acceptance test for any future narrowing:

| Target | Result |
|---|---|
| API server `10.96.0.1:443`, node `192.168.0.74:6443`, gateway VIP `192.168.0.100:443` | **blocked** |
| `kube-auth` (postgres 5432, authentik 443), `kube-storage` (s3 8333, admin 9000), `monitoring` (prometheus 9090), `devops-harbor` (core 80) | **blocked** |
| every pod in `media` — sonarr 80, plex 32400, qbittorrent 8080, prowlarr, bazarr, outpost 9000, **NGF control plane 9113**, the gateway data plane | **OPEN, every port** |
| public internet (`1.1.1.1:443`) | OPEN |

Two conclusions, both structural rather than lucky:

- **The internet grant cannot pivot.** `allow_internet` renders `0.0.0.0/0` minus RFC1918, so no
  ClusterIP (10.96/10.0), no node, no LoadBalancer VIP and no other namespace's pod is in it. What
  the apps need it for (indexers, metadata, notifications, Plex, torrent peers) is exactly the
  public space, and the exclusion is the whole reason it is safe to hand out to every pod.
- **The `self` rule is the lateral surface, and it is a flat all-ports namespace.** Every app can
  dial every pod here on every port. The two that matter are not apps: the **NGF control plane** (the
  only pod in `media` with API access and a ServiceAccount — its metrics port answers, and the agent
  port the data planes use is inside the same all-ports grant) and the **outpost** (the auth proxy,
  and the only pod here with a reach into `kube-auth`). The outpost's side has since been narrowed to
  one pod on one port; the flat `self` rule has **not** been narrowed and is no longer planned —
  declined by rule 3 (`../network/firewalls/README.md`), because the enumerated version trades one
  readable object for a dozen nobody will re-read. Accepted consequence: every media pod reaches every
  other one on any port, `9113` and `9000` included. If it is ever narrowed, replace `self` with
  explicit `egress_peer` calls for the integrations that exist — and use the **container** ports,
  because egress is evaluated post-DNAT (the Service is `sonarr:80`, the container is 8989, so a policy
  naming 80 permits nothing).

The same sweep from an **unlabeled** pod (the `utility` case, so only the floor applies) is the
namespace's actual default: internet `OPEN`, and every internal target above **blocked** — which is
the three-line rule above, tested rather than asserted.


Five things worth knowing before extending the list:

- **No storage peer is needed, and that is not obvious.** The `/media` PVC is a seaweedfs CSI bind
  mount, so the FUSE client doing the I/O is the `seaweedfs-csi-mount` DaemonSet in `kube-storage`,
  not the app pod's netns — nothing in `media` has a flow to `kube-storage` at all.
- **`allow_internet` is not the same as unrestricted.** It renders `0.0.0.0/0` with RFC1918 and
  link-local excluded, so anything pointed at a `*.vn.linuxguru.net` hostname (split-horizon to a
  LAN VIP), at Plex by LAN IP, or at the router needs `to_cidrs`. Two live consequences: a
  qBittorrent peer on a private address cannot be dialled, and UPnP/NAT-PMP to the router is off
  the table. Plex's NAT-PMP (5351/udp) reads as a PUBLIC address in the flow logs, which is why
  the internet rule covers it — that is evidence, not an assumption about the router.
- **The apps' configs are invisible to Terraform** (they live on the config PVCs), so the peers
  above were checked through the apps' own APIs: no notifications at all in sonarr/radarr, and
  every indexer there is `http://prowlarr.media/N/`, i.e. in-cluster. A LAN-pointing integration
  added later fails *silently* — its traffic simply does not leave — so it needs a `to_cidrs` entry
  here when it appears.
- **`utility` is why the floor exists, and it is still closed to everything internal.** The pod is
  hand-made — no owner, no Terraform, one label (`app: utility`) — so no per-pod call selected it and
  it fell through to the namespace profile, which is the Kubernetes default-allow one. Measured: it
  got **200** from `https://vaultwarden.linuxguru.net` (`192.168.0.100`, the private gateway VIP) and
  could dial the API server on 6443, while sonarr and the outpost in the same namespace timed out on
  the same URL at the same moment. The floor closed that: measured again after the change, an
  unlabeled pod reaches the internet and this namespace and **nothing** else — LAN, VIP, API server,
  kube-auth, kube-storage, harbor and monitoring all time out. The invariant that comes out of it:
  **a pod in this namespace is closed to the cluster by default**, so a debug box or an integration
  that needs a LAN host or a cluster peer has to say so in a call site — being unmanaged no longer
  inherits reach, it inherits the floor.
- **The floor binds helm hook pods too, and one of them needs the API.** NGF's cert-generator Job
  (`pre-install,pre-upgrade`, on by chart default) renders a pod template with **no pod labels**, so
  its pod carries only `job-name=ngf-nginx-gateway-fabric-cert-generator`. `ngf-egress` selects the
  controller label and never covered it, and the floor alone leaves it DNS + self + internet — which
  kills the hook, i.e. the 2026-08-31 incident re-armed by policy instead of by oversight. Measured
  2026-09-16 with two labeled `curlimages/curl` pods: the `job-name` one got `rc=28` on
  `https://10.96.0.1:443/api` where the `app.kubernetes.io/name=nginx-gateway-fabric` one got `403`.
  After `ngf-cert-generator-egress` landed, the same `job-name` pod gets **`403`** — reachable, and
  unauthorized exactly as it should be. The lesson to keep: hook Jobs, CronJobs and `kubectl run`
  one-offs are what a namespace-wide policy binds silently, so enumerate a namespace's *transient*
  pods before changing its floor.

Two known asymmetries, recorded rather than hidden. The **public** gateway in `kube-network` dials
Plex across namespaces and has no policy at all — that namespace is still default-allow throughout;
its *control plane* pods are rule-1 work, while its *data plane* is a recorded decline (its legitimate
reach is the whole pod CIDR, every backend anyone deploys). And the floor's internet grant is
namespace-wide, so no pod here is internet-less today — subtracting it is a floor change, not
another policy, and is declined above.
