### Flow logs (calico-system)
`kubectl -n calico-system port-forward svc/whisker 8081:8081 &`
 - UI: `localhost:8081` | JSON: same host + `/whisker-backend/flows` | `?watch=true` = SSE tail
 - `filters` = url-encoded JSON, e.g. `--data-urlencode 'filters={"actions":["Deny"]}'`;
   keys: source_/dest_names(pace)s, protocols, dest_ports, actions, policies
 - `startTimeGte`/`startTimeLt` = epoch **seconds**
 - hints: `/whisker-backend/flows-filter-hints?type=SourceNamespace` (+Dest, *Name, PolicyTier/Name)
 - goldmane:7443 = mTLS + proto, skip it. Port-forward is host-sourced, so whisker's
   deny-all pod netpol does not block it.

 - Deny with empty `policies.enforced` = default deny, NOT a named policy. Don't read that field as "which policy blocked me".
 - `policies.pending` = staged netpol preview (see TODO.md).
