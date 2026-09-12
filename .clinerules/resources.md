## Resources (debug)

Instructions
 - Please maintain key tool resources in this file.
 - Stay as terse as possible
 - No temp info

- The stack uses calico, authentik, cert-man, api-gateway
- **Calico flow logs**: Whisker UI https://whisker.vn.linuxguru.net (SSO `platform` grp); live-only, Goldmane keeps no history.
- **Goldmane gRPC** (same data, scriptable): pf `svc/goldmane` 7443; mTLS certs = secrets `node-certs` + `goldmane-key-pair`; proto `calico/v3.31.2/goldmane/proto/api.proto`; grpcurl needs `-proto`, flags before addr.
- **Grafana**: https://grafana.vn.linuxguru.net (monitoring ns)
- **authentik API**: token in `kube-auth/authentik-tfdeploykey` (`api_key`); base https://auth.vn.linuxguru.net/api/v3/ . Token is `akadmin` — read-only unless asked.
- **tfvars**: `/Users/jblack/.tfenvs/k8s.tfenv` ; stacks `core`→`mantle`→`apps`, runner `tofu`.
- **Storage is longhorn and seaweedfs
- **Firewall modules in  modules/network/firealls

