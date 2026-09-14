## Resources
Very Terse list of key tools available
 - Tools:  authentik, grafana, cert-man, prometheus, api-gateway
 - Storage:  longhorn, seaweedfs
 - tofu: stacks/(core|mantle|apps) — apply in that order

## Docs — read the narrowest doc that answers the question
 - `README.md` — the map: stack split + order, hostname table, module index,
   conventions. `TODO.md` — open work.
 - `modules/<mod>/README.md` — per-app detail (media, blender, vaultwarden,
   cert_manager, network/{firewalls,gateway}, whisker, seaweedfs_admin,
   dns/route53_record, monitoring, auth). Read only the one you're touching;
   not every module has one, and none of them is required context up front.

## Extended instructions live in .clinedocs/ — load only when needed
 - Calico Whisker flow queries :  flow-logs.md
 - Calico netpol invariants :  calico-netpols.md
