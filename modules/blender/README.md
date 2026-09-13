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
macOS SMB client -- TCP 445 --> samba-blender.<domain> = 192.168.0.103 (MetalLB VIP)
   |                                                      external-dns A record
   v
blender-samba pod   (dockurr/samba, /storage on a seaweedfs-csi PV, RWX, 1Pi)
```

Credentials: user `jblack`, password
`tofu -chdir=stacks/mantle output -raw blender_samba_pass`. The share is called
`blender`. It is LAN/WireGuard-reachable only (the A record is an RFC1918
address).

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
| `locals.tf` | `samba_name`, `samba_host`, `mdns_name`, `samba_vip` |

## Why `mdns.tf` exists, and why it is hostNetwork

Three facts, all checked against the live cluster rather than assumed:

1. **Finder's "Network"/"Shared" list is Bonjour-only.** Unicast DNS can never
   populate it: `samba-blender.<domain>` resolved and `:445` accepted
   connections for months while Finder showed nothing at all. macOS has no
   NetBIOS/WSD browsing left to fall back on.
2. **Nothing was advertising.** `dockurr/samba` runs `smbd` and nothing else —
   no `avahi-daemon`, no `nmbd` (the binary ships, the entrypoint never starts
   it), and the live pod held no 5353 socket (`netstat`: 139/445 only). Samba's
   own mDNS support (`WITH_AVAHI_SUPPORT` *is* compiled in) does nothing without
   an avahi daemon on the bus, which the image doesn't ship.
3. **Multicast cannot leave a Calico pod netns.** mDNS is link-local
   (224.0.0.251:5353). The advertiser therefore runs `host_network = true` and
   emits on the node's LAN interface. Tested both ways: the identical config in
   a pod netns is invisible to the LAN; with hostNetwork the Mac sees `_smb._tcp`
   immediately, on its `en0` (verified with `dns-sd`).

What it publishes, all pointing at `samba-blender.<domain>:445`:

- `_smb._tcp` — the record Finder browses.
- `_device-info._tcp` with `model=MacSamba` — the icon, matching `fruit:model`.
  Cosmetic: without it the entry still appears, with a generic icon.
- A **static A record** (`/etc/avahi/hosts`, templated from the Service's VIP) so
  the SRV target resolves inside mDNS too, instead of depending on the client's
  unicast lookup succeeding. It is also why a VIP change rolls the pod — the
  ConfigMap is hashed into the pod template (`checksum/config`, same pattern as
  `modules/vaultwarden`), because a subPath-mounted ConfigMap is never refreshed
  in place.

It is an advertiser only: it never serves SMB, and the data path is untouched
(VIP → Service → pod, `externalTrafficPolicy: Cluster`).

## Things that look wrong and are not

1. **`host_network = true` on a workload.** The price: it sits in the node's
   network namespace, NetworkPolicy cannot select it (in either direction), 5353
   becomes a node-level port, and it is pinned to one node for its lifetime
   (drain that node and the advert disappears until it reschedules). Mitigations
   in place: 6 MB digest-pinned image, no API token, `NET_RAW` dropped (the
   capability that would otherwise allow LAN sniffing/spoofing), one replica, no
   probes. Blast radius if it dies: a missing Finder entry, nothing else. It is
   the first `hostNetwork` pod in this repo — keep it boring.
2. **An A record for a name unicast DNS already publishes.** Harmless duplicate,
   and it makes the advertisement self-contained: `dns-sd -G v4
   samba-blender.<domain>` answers from mDNS.
3. **`app = blender-mdns`, deliberately not `app = blender-samba`.** This one is
   load-bearing. That label is the samba Service's selector; a *hostNetwork* pod
   carrying it would register `<node-ip>:445` as an endpoint with nothing behind
   it, and with `etp=Cluster` kube-proxy would blackhole roughly half of all new
   SMB connections. Never reuse that label for anything host-networked.
4. **A digest-pinned third-party image with no version tag.** `flungo/avahi`
   publishes only `latest`/`main`, so a tag pin would be neither reproducible
   nor reviewable. Bump the digest deliberately (see `variables.tf` for the
   one-liner that lists the current ones).

## Operational notes

- **Kill switch:** `mdns_enabled = false` removes the ConfigMap and Deployment
  and nothing else. The share is unaffected either way.
- **No probes, on purpose** (matching the rest of this repo). `restartPolicy`
  handles a crash; a wedged advertiser only costs the sidebar entry.
- **`disallow-other-stacks=yes`:** if a node ever runs its own mDNS stack this
  pod CrashLoops loudly instead of duelling over 5353. That is the signal to set
  `mdns_node_selector` and pin it somewhere clean.
- **NetworkPolicy blindness is expected.** If `blender` ever grows a
  `security.tf`, the advertiser is outside it in both directions. Not an
  oversight — just don't go looking for the pod in the firewall graph.
- **If a namespace firewall lands here**, remember the SMB LoadBalancer is
  `etp=Cluster` and needs the node CIDR in its guest list (see
  `.clinedocs/calico-netpols.md`). The advertiser is unaffected.
- **subPath asymmetry:** changes to `smb.conf` need a pod restart (nothing
  hashes it), while the advertiser rolls itself when its ConfigMap changes.

## Verifying

```sh
# from the Mac — is the record on the wire, and does it resolve?
dns-sd -B _smb._tcp local                   # expect "Blender" on the en0 interface
dns-sd -L "Blender" _smb._tcp local         # -> samba-blender.<domain>:445
dns-sd -G v4 samba-blender.vn.linuxguru.net # -> 192.168.0.103, answered via mDNS

# what the advertiser thinks it did
kubectl -n blender logs deploy/blender-mdns | grep -E 'established|startup complete'

# the share itself (the path that never changed)
nc -vz 192.168.0.103 445
smbutil view -N //samba-blender.vn.linuxguru.net
```

Finder caches discovery both ways: if the entry doesn't show up, `killall
Finder`. It appears under the Bonjour instance name **"Blender"**, not the DNS
name, in the "Network" location and the Shared/"Connected servers" area. If it
vanishes after `mdns_enabled = false` or a pod restart, that is the advert being
withdrawn (avahi sends mDNS goodbyes), not the share breaking.
