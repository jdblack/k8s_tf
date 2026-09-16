# firewalls

`NetworkPolicy` builders, one call = one object. Everything here governs **this repo's own
pods'** traffic; the Calico *tier* machinery (which is what the operator's own deny lives in)
is elsewhere, in `../whisker`.

| Module | What it renders |
|---|---|
| `egress/` | Per-pod **egress**: unconditional DNS + own-namespace floor, plus namespace / API-server / cluster / internet / raw-CIDR peers. `policyTypes: ["Egress"]` only. |

Two things are deliberately *not* here, and are instead hand-written in the app module that
needs them:

- **Ingress.** A `NetworkPolicy` that types `Ingress` is a deny-all-inbound for the pods it
  selects, and there is no shape of ingress policy that is safe as a default.
- **Port-scoped peering** to another namespace's pods (the authentik-outpost hops:
  `namespace + pod selector → namespace + pod selector, one port`). Widening it to a
  whole-namespace peer would be a privilege increase, so it stays spelled out per call site.

**Reaching the LAN.** `deployment.network.host_cidr` (tfenv) is the only declaration of the LAN
anywhere — nothing in-cluster stores a netmask — so an egress call site passes it as a CIDR
peer: `to_cidrs = [var.deployment.network.host_cidr]`. Inside an app module, the stack has to
pass `host_cidr` down first.

See `../README.md` for the namespace layout and `.clinedocs/calico-netpols.md` for
the tier rules that decide whether any of this traffic survives `calico-system`.
