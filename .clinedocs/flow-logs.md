### Flow logs (calico-system)
`kubectl -n calico-system port-forward svc/whisker 8081:8081 &`
 - UI: `localhost:8081` | JSON: same host + `/whisker-backend/flows` | `?watch=true` = SSE tail
 - the JSON body is `{"total":{...},"items":[...]}` — **`items`, not `flows`**. A `jq '.flows[]'`
   prints nothing and looks exactly like "no such traffic".
 - **Absence of a flow is not absence of traffic.** Long-lived connections (the apiserver watches
   every controller holds) are not emitted, so API clients cannot be enumerated from here — the
   ClusterIP path never shows up as a dest namespace.
   - **Measured 2026-09-17, the scrape case.** Prometheus (ns `monitoring`) scrapes every
     `kube-storage` SeaweedFS pod on `:9327` — 13/13 targets `up` — and `dest_ports: [{"value":9327}]`
     returns **zero** flow records. Prometheus keeps the connection open, so there is no flow to see.
     A guest found this way is invisible until a policy denies it, and then it appears minutes later as
     a dead target rather than as a Deny at the moment of the change; ask Prometheus
     (`up{namespace=...}`) about scrape guests, not Whisker. Prometheus is not the only keep-alive
     client: any long-lived S3/DB client hides the same way, which is why the ingress rule for the
     scrape service was written from `up` and not from a test apply.
 - **The result set is capped (~570 items), so the window is only as long as the busiest pod needs
   to fill it.** One namespace returned 568 items spanning 105 s (`totalPages: 1`); the same query
   with `startTimeGte` 12 h back returned 566, because a torrent client's ~550 flows/hour crowded
   out everything quieter. Narrow per source/dest, don't widen the window and assume full coverage.
 - `dest_port` is **post-DNAT**: `media`'s outpost dials `sonarr.media.svc:80` and the flow reads
   `sonarr-…:8989`, the target pod's port. Same reason a rule permitting only a Service's ClusterIP
   permits nothing at all (see `firewalls/egress/README.md`).
 - The flow object carries **no `dest_ip`** — off-cluster peers are only ever `dest_name` =
   `PRIVATE NETWORK` / `PUBLIC NETWORK` with `dest_namespace` = `-`, so "which LAN host?" is not
   answerable from Whisker. Fields worth having: `protocol`, `dest_port`, `action`, `bytes_out`,
   `source_labels`, `policies.enforced[].trigger.name`, `start_time`.
 - `filters` = url-encoded JSON. Keys: source_/dest_names(pace)s, protocols, dest_ports,
   actions, policies. **Two shapes**, and a wrong one silently matches nothing:
    - `actions` = bare strings: `--data-urlencode 'filters={"actions":["Deny"]}'`
    - every other key = `[{"value":X}]`:
      `{"source_namespaces":[{"value":"kube-auth"}]}` | `{"protocols":[{"value":"tcp"}]}`
      | `{"dest_ports":[{"value":6443}]}`  <- int, `"6443"` errors
   A bare string/object is a hard error naming the Go type (`v1.FilterMatch[string]`,
   `FilterMatches[T]`) -- that's the *good* failure. A wrong key inside the object
   (`{"values":[...]}`, `{"key":...}`) returns `{"totalPages":0}` with NO error; that's the
   footgun. An empty result usually means a misspelled filter, not an absence of flows.
 - `startTimeGte`/`startTimeLt` = epoch **seconds**
 - hints: `/whisker-backend/flows-filter-hints?type=SourceNamespace` (+Dest, *Name, PolicyTier/Name).
   `DestPort` is NOT one of them (`dest_ports` is still a valid *filter* key) — allowed values are
   Unspecified, DestNamespace, SourceNamespace, PolicyName, PolicyKind, PolicyNamespace, DestName,
   SourceName, PolicyTier.
 - goldmane:7443 = mTLS + proto, skip it. Port-forward is host-sourced, so the tigera
   operator's deny-all pod netpol on whisker does not block it.

 - Deny with empty `policies.enforced` = default deny, NOT a named policy. Don't read that field as "which policy blocked me" -- the deciding rule's policy is at `policies.enforced[].trigger` (`trigger.name` / `trigger.namespace`). EndOfTier name="" + a trigger name = the tail deny of that policy (in `calico-system` this is the operator's `default-deny`; the only policy this repo owns there is `whisker-*-tier`).
 - **With several policies on one pod, the `Deny` record names *one* of them — and which one moves when you add another.** Measured 2026-09-16 in `media`: the same failing dial (a Service port nothing listens on) recorded `trigger.name = sonarr-egress`/`bazarr-egress` before `media-baseline-egress` existed and `media-baseline-egress` after it, with identical behaviour — that is the tail `EndOfTier` deny of a pod every selecting policy declines. The `Allow` side moves the same way (`sonarr` → coredns flipped from `sonarr-egress` to `media-baseline-egress` while staying `Allow`). So read the `action` and the peer, never "policy X is what blocks me" from a name alone. `rule_index`/`policy_index` are there for this. **Those per-app names are history as of 2026-09-17** — `sonarr-egress` and the other five app policies were deleted when `media` moved to a namespace profile, so the records still name them while the objects are gone. That is the same trap one level up: a name in a flow is not a live object.
- `policies.pending` = staged netpol preview. Nothing in this repo stages policies since the firewall layer was deleted (2026-09-16), so this field should read empty nearly always.
 - Off-cluster / unnamed peers: `dest_name` = `PRIVATE NETWORK` / `PUBLIC NETWORK` with `dest_namespace` = `-`. Reachability to an RFC1918 dest that still reads as PRIVATE = an `ipBlock … except` on the deciding policy, not a missing netpol.
- **The API server's own traffic is invisible here** (watches never end, so neither does the connection — see above), and the flow that *does* appear is not what you'd expect: a pod's dial to `https://10.96.0.1:443/api` is recorded as `<control-plane node IP>:6443` on the **`PRIVATE NETWORK`** peer, because kube-proxy DNATs before the policy chain runs. So "does this pod talk to the API?" is **not** a flow-log question. Two checks answer it:
  - the pod's **RBAC** — `kubectl -n <ns> get sa`, then follow the Role/ClusterRole bindings; a sidecar with `--leader-election`, or a registrar with `events`/CRD verbs, is an API client by construction;
  - a **live socket table** — `/proc/net/tcp` + `/proc/net/tcp6` read *inside* the pod. The table is net-namespace-scoped, not process-scoped, so one container's read covers every container in the pod, and a long-lived watch shows as an ESTABLISHED row to `…:192B` (6443 = `0x192B` in hex): `sh -c 'cat /proc/net/tcp /proc/net/tcp6 | grep -ci 192b'`. Distroless containers have no shell — pick one that does, or read the pod's netns another way.
  - **Both, not either.** Measured 2026-09-17 in `kube-storage`: the SeaweedFS chart binds a `pods` CRUD ClusterRole to the SA that master/volume/filer run as, and those pods hold *zero* 6443 sockets and carry no k8s flag in `/proc/1/cmdline` — RBAC a chart ships is not traffic a pod makes. The same read showed nothing for the CSI `driver-registrar` either, and that one *is* an API client (it creates CRDs at startup): a socket table shows long-lived and in-flight connections, **not write-once calls**. Absence of a socket is evidence about the present, not about startup.
