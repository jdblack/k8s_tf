### Flow logs (calico-system)
`kubectl -n calico-system port-forward svc/whisker 8081:8081 &`
 - UI: `localhost:8081` | JSON: same host + `/whisker-backend/flows` | `?watch=true` = SSE tail
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
 - hints: `/whisker-backend/flows-filter-hints?type=SourceNamespace` (+Dest, *Name, PolicyTier/Name)
 - goldmane:7443 = mTLS + proto, skip it. Port-forward is host-sourced, so whisker's
   deny-all pod netpol does not block it.

 - Deny with empty `policies.enforced` = default deny, NOT a named policy. Don't read that field as "which policy blocked me" -- the deciding rule's policy is at `policies.enforced[].trigger` (`trigger.name` / `trigger.namespace`). EndOfTier name="" + trigger.name="namespace-firewall" = that netpol's tail deny.
 - `policies.pending` = staged netpol preview (see TODO.md).
 - Off-cluster / unnamed peers: `dest_name` = `PRIVATE NETWORK` / `PUBLIC NETWORK` with `dest_namespace` = `-`. Reachability to an RFC1918 dest that still reads as PRIVATE = an `ipBlock … except` in a namespace firewall, not a missing netpol.
