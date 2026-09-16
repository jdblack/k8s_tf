# `blender` — Samba on the LAN, with the Bonjour advertisement macOS needs

One Samba container over a SeaweedFS CSI volume, published on the LAN through
MetalLB, plus a second, tiny workload (`mdns.tf`) whose only job is to put the
share in Finder.

```
Finder "Network" / "Shared"
   ^  mDNS  _smb._tcp + _device-info._tcp + A    (UDP 5353, link-local only)
   |
   mdns advertiser  (hostNetwork, 1 replica)      <- discovery ONLY, never SMB
   |
macOS SMB client -- TCP 445 --> samba-blender.<domain> = MetalLB VIP (.103 today)
   |                                                      external-dns A record
   v
blender-samba pod   (dockurr/samba, /storage on a seaweedfs-csi PV, RWX, 1Pi)
```

Credentials: user `jblack`, password
`tofu -chdir=stacks/mantle output -raw blender_samba_pass`. The share is called
`blender`, and is LAN/WireGuard-reachable only (the A record is RFC1918).

## Files

| File | What |
|---|---|
| `namespace.tf` | the `blender` namespace |
| `secret.tf` | samba user + generated `random_password` |
| `smb.conf` | `[global]` (fruit/streams_xattr, `fruit:model = MacSamba`) + the `[blender]` share on `/storage` |
| `configmap.tf` | that file, mounted at `/etc/samba/smb.conf` (subPath) |
| `deployment.tf` | the samba pod |
| `storage.tf` | PV + PVC, `ReadWriteMany`, `seaweedfs-csi`, 1Pi, reclaim `Retain` |
| `service.tf` | `LoadBalancer` 445 + the external-dns hostname annotation |
| `mdns.tf` + `mdns.service` | the Bonjour advertisement — the rest of this README |
| `egress.tf` | the share's `NetworkPolicy`: DNS plus its own namespace, nothing else |
| `locals.tf` | `samba_name`, `samba_host`, `mdns_name`, `samba_vip` |

## Why `mdns.tf` exists, and why it is hostNetwork

Three facts, all checked against the live cluster rather than assumed:

1. **Finder's "Network"/"Shared" list is Bonjour-only.** Unicast DNS can never
   populate it: `samba-blender.<domain>` resolved and `:445` accepted
   connections for months while Finder showed nothing. macOS has no
   NetBIOS/WSD browsing left to fall back on.
2. **Nothing was advertising.** `dockurr/samba` runs `smbd` and nothing else —
   no `avahi-daemon`, no `nmbd` (the binary ships, the entrypoint never starts
   it), and the live pod held no 5353 socket. Samba's own mDNS support
   (`WITH_AVAHI_SUPPORT` *is* compiled in) does nothing without an avahi daemon
   on the bus, which the image doesn't ship.
3. **Multicast cannot leave a Calico pod netns.** mDNS is link-local
   (224.0.0.251:5353), so the advertiser runs `host_network = true` and emits on
   the node's LAN interface. Tested both ways: the identical config in a pod
   netns is invisible to the LAN; with hostNetwork the Mac sees `_smb._tcp`
   immediately (verified with `dns-sd`).

What it publishes, all pointing at `samba-blender.<domain>:445`:

- `_smb._tcp` — the record Finder browses.
- `_device-info._tcp` with `model=MacSamba` — the icon, matching `fruit:model`.
  Cosmetic: without it the entry still appears, with a generic icon.
- A **static A record** (`/etc/avahi/hosts`, templated from the Service's VIP) so
  the SRV target resolves inside mDNS too. It is also why a VIP change rolls the
  pod — the ConfigMap is hashed into the pod template (`checksum/config`, same
  pattern as `modules/vaultwarden`), because a subPath-mounted ConfigMap is
  never refreshed in place.

It is an advertiser only: it never serves SMB, and the data path is untouched
(VIP → Service → pod, `externalTrafficPolicy: Cluster`).

## Things that look wrong but aren't

1. **`hostNetwork` + `hostPort` on 5353.** A hostNetwork pod joins no namespace,
   so NetworkPolicy cannot select it (either direction), 5353 becomes a
   node-level port, and it is pinned to one node for its lifetime (drain that
   node and the advert disappears until it reschedules). Mitigations in place:
   6 MB digest-pinned image, no API token, `NET_RAW` dropped (the capability that
   would otherwise allow LAN sniffing/spoofing), one replica, no probes. Blast
   radius if it dies: a missing Finder entry, nothing else. It is the first
   `hostNetwork` pod in this repo — keep it boring.
2. **An A record for a name unicast DNS already publishes.** Harmless duplicate,
   and it makes the advertisement self-contained: `dns-sd -G v4
   samba-blender.<domain>` answers from mDNS.
3. **`app = blender-mdns`, deliberately not `app = blender-samba`.** Load-bearing:
   that label is the samba Service's selector, and a *hostNetwork* pod carrying
   it would register `<node-ip>:445` as an endpoint with nothing behind it — with
   `etp=Cluster`, kube-proxy would blackhole roughly half of all new SMB
   connections. Never reuse that label for anything host-networked.
4. **Third-party images are pinned.** `dockurr/samba` by version tag
   (`samba_image` in `variables.tf`), `flungo/avahi` by digest — it publishes
   only `latest`/`main`, so a tag pin would be neither reproducible nor
   reviewable. Both `variables.tf` defaults carry the one-liner that lists the
   current tags/digests.

## Operational notes

- **Kill switch:** `mdns_enabled = false` removes the ConfigMap and Deployment
  and nothing else. The share is unaffected either way.
- **No probes, on purpose** (matching the rest of this repo). `restartPolicy`
  handles a crash; a wedged advertiser only costs the sidebar entry.
- **`disallow-other-stacks=yes`:** if a node ever runs its own mDNS stack this
  pod CrashLoops loudly instead of duelling over 5353. That is the signal to set
  `mdns_node_selector` and pin it somewhere clean.
- **Egress policy: `blender-egress`** (`egress.tf`, via `../network/firewalls/egress`). The share
  initiates nothing, so the policy is DNS plus this namespace and nothing else — no API, no
  internet, no LAN. It selects `app = blender-samba` rather than the namespace, so it says
  exactly what it covers; the advertiser is hostNetwork, where pod policy does not apply.
  SMB, the VIP and the advert are all *inbound*, and replies ride the established flow, which
  policy does not re-evaluate. The `etp=Cluster` caveat — a LAN client's connection can arrive
  SNATed from a node IP — is a concern for an *ingress* allow-list, if one ever lands here; this
  egress policy needs no node CIDR.
- **subPath asymmetry:** changes to `smb.conf` need a pod restart (nothing hashes
  it), while the advertiser rolls itself when its ConfigMap changes.

## Verifying

```sh
# from the Mac — is the record on the wire, and does it resolve?
dns-sd -B _smb._tcp local                    # expect "Blender" on the en0 interface
dns-sd -L "Blender" _smb._tcp local          # -> samba-blender.<domain>:445
dns-sd -G v4 samba-blender.vn.linuxguru.net  # -> the VIP (.103 today), via mDNS

kubectl -n blender logs deploy/blender-mdns | grep -E 'established|startup complete'

# the share itself (the path that never changed). The VIP floats -- read it back
# with `dig +short samba-blender.vn.linuxguru.net` rather than trusting a literal.
nc -vz 192.168.0.103 445
smbutil view -N //samba-blender.vn.linuxguru.net   # "server rejected the authentication" IS
                                                   # the pass: no creds sent, and `valid users`
                                                   # means an anonymous list is refused anyway
```

Finder caches discovery both ways: if the entry doesn't show up, `killall
Finder`. It appears under the Bonjour instance name **"Blender"**, not the DNS
name. If it vanishes after `mdns_enabled = false` or a pod restart, that is the
advert being withdrawn (avahi sends mDNS goodbyes), not the share breaking.

