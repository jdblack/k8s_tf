# Disaster recovery — Grafana

| | |
|---|---|
| PVC | `prometheus-grafana` in `monitoring` |
| Owner | `Deployment/prometheus-grafana` (kube-prometheus-stack) |
| Tiers | weekly + monthly, retain 2 each |

Grafana's `/var/lib/grafana`: the SQLite DB (users, orgs, API keys, annotation
history, saved queries) plus a local plugin cache. A revert restores *people and
history*, not configuration — dashboards, datasources and the authentik SSO
client are provisioned from this repo (`modules/monitoring/prometheus`, ConfigMaps
labelled `grafana_dashboard: "1"`; `modules/monitoring/grafana_oidc`) and will be
re-provisioned on start regardless. Configuration drifting back is not a symptom
to chase.

Scale `deploy/prometheus-grafana` to 0, revert, scale back to 1 — it is the only
writer.

Prometheus itself is untouched: its PVC and TSDB are separate, it keeps scraping
throughout, and the Grafana→Prometheus datasource is provisioned. What you lose
from a revert: API keys minted since the snapshot (dashboards that call them
break), and any annotation added since. After a revert, check that the SSO login
still lands on the expected org/role — the *Grafana* side of that mapping is in
this DB, while the authentik side is in the identity database.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../../storage/disaster_recovery.md`](../../storage/disaster_recovery.md).
