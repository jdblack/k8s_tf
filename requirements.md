# requirements.md — stand up oCIS (ownCloud Infinite Scale) in the `documents` role

Written 2026-09-30, immediately after tearing FileBrowser Quantum out of this repo. It is written
*for the next agent run*, not for a human skimming. Everything under "measured" was measured on this
cluster; anything unverified is explicitly flagged. Read §7 before making design choices, and §8
before writing a single line: it contains the working config and the commands that produced the
numbers.

## 0. State of the world right now

* FileBrowser Quantum is **gone**: `modules/documents/`, `stacks/mantle/documents.tf` and 29 live
  resources (namespace `documents`, its three claims, the authentik app/groups/provider,
  ListenerSet/HTTPRoute, netpols, Velero schedule, PrometheusRule) were destroyed. `tofu plan` is
  clean, `fmt`/`validate` clean.
* The autopsy — why FileBrowser could not meet the sharing requirement — is kept in this directory as
  `implementation_plan.filebrowser.md`. Read it only for background; do not reintroduce FileBrowser.
* SeaweedFS bucket **`documents` still exists with its data** (the static PV was `Retain` and carried
  no `provisioned-by` annotation, so deleting the PV never called `DeleteVolume`): now holds
  `users/testblack/{20260929_125824.jpg, Screenshot 2026-09-28 at 7.42.27 PM.png}`,
  `users/testblack2/20260930_001051.jpg` and an empty `shared/`. Nothing mounts it today.
* Verification users used below and their password: `testblack`, `testblack2` / `tpslmaw`. They lived
  in FileBrowser's sqlite DB, which is gone — for oCIS you must create equivalent users yourself.

## 1. Openly stated requirements (the user said these, in this order)

1. **Drive-like sharing, not link-sharing.** A user's files are private by default; when they choose
   to share a file or folder with another user it must **appear in that person's account** (a "shared
   with you" surface, with per-file rights) — no out-of-band links, no admin action. This is exactly
   what FileBrowser could not do, and the reason it is being replaced.
2. **A shared tree that is read-only by default** for ordinary users; writes happen in personal
   spaces, or where an owner grants rights.
3. **A personal space per user**, writable by its owner only.
4. **No proprietary blob jail.** The user rejects app-controlled block stores (that is why Seafile was
   ruled out) and wants the bytes readable by other systems. Their words for the target: "data on a
   seaweedfs PVC". §2.1 records what that turns into for oCIS, from measurement.
5. **Lean runtime.** The objection to Nextcloud is explicit ("big bloated PHP pig"). Go, no external
   DB, one binary, no app farm. oCIS 8.2.0 qualifies: Go, single container, embedded IDM (boltdb) and
   NATS, **no MySQL/Postgres/Redis**, image 78 MB.
6. **Everything stays inside this repo's tofu conventions** (§4, §5).
7. **Identity through authentik**, like every other app here.
8. **Exposed under `*.vn.linuxguru.net`** behind the existing `private` gateway, with the usual
   cert-manager issuer, network policies, Velero schedule and Prometheus alerts.
9. The product is **oCIS (ownCloud Infinite Scale)** — not Nextcloud, not Seafile, not FileBrowser.

## 2. Decisions that were validated by measurement — don't re-derive them

### 2.1 Storage driver: `s3ng`. Metadata on Longhorn, blobs in SeaweedFS S3. Not the PVC.

`STORAGE_USERS_DRIVER=s3ng` means **decomposedfs metadata on a local POSIX filesystem + file content
as S3 objects**. It is the only arrangement that satisfied requirement 4 *and* stayed fast.

Measured on oCIS 8.2.0, identical workload (200 × 13-byte files over WebDAV, then one 100 MB file,
then the same 200 files 20-way parallel):

| | decomposedfs on **SeaweedFS CSI PVC** (FUSE) | decomposedfs on **Longhorn** | **s3ng: meta Longhorn + blobs SeaweedFS S3** |
|---|---|---|---|
| 200 small files, serial | 53 s (265 ms/file) | 31 s (155 ms/file) | **32 s (160 ms/file)** |
| 100 MB PUT | 100 MB/s | 138 MB/s | **117 MB/s** |
| 100 MB GET | 171 MB/s | 196 MB/s | 80 MB/s |
| 200 files, 20-way parallel | **0 ok / 200 failed (HTTP 500)** | 200 ok, 44 s | **200 ok, 41 s** |
| objects per uploaded file | 4 local | 4 local | 1 S3 object + ~3 local metadata files |

Why the FUSE PVC is disqualifying for oCIS (and for any app that writes many small files):

* Every parallel upload failed with
  `storage-users: error getting upload id: open …/storage/users/uploads/<uuid>: no such file or directory`.
  oCIS creates its upload file and immediately opens it; on that mount a freshly created path is not
  reliably visible to the next call. Sequentially everything works — the failure only shows up under
  concurrency, which is the normal case for sync clients and multiple humans.
* The same class of race killed first boot: `idm` wrote `ldap.key`, read it back as **0 bytes**, and
  died with `tls: failed to find any PEM data in key input`. Restarting (file now present) fixed it.
* oCIS's own microbenchmark (`ocis benchmark syscalls --path <file> --iterations 500`), same tool on
  both mounts:

  | test | SeaweedFS PVC | Longhorn | ratio |
  |---|---|---|---|
  | `stat` | 2.4 µs | 0.86 µs | 2.8× |
  | `fopen(ro) read close` | 56.6 µs | 9.1 µs | 6.3× |
  | `fopen(wo) write close` | 8.95 ms | 1.41 ms | 6.4× |
  | `lockedfile open(w,c,t)` — oCIS's upload lock | 1.48 ms | 5.4 µs | **275×** |
  | `xattr-set` — decomposedfs metadata | 1.37 ms | 3.7 µs | **370×** |

* What the mount *does* do correctly, so you don't have to test it again: `setfattr`/`getfattr`
  round-trip, atomic rename-to-place, `mv -f` replace-rename, cross-directory rename, directory
  rename, append, unlink-while-open, chmod, symlinks, hardlinks, real `flock` contention,
  read-after-write on an existing file. Throughput: ~77 small-file creates/s, 4 012 entries deleted in
  10 s, 256 MB write 642 MB/s, read 1.2 GB/s.

**Rule: the s3ng metadata root lives on Longhorn (RWO, ext4, xattrs). Never on the FUSE mount.**

### 2.2 The S3 side (SeaweedFS)

* In-cluster endpoint: **use the service IP** — `http://10.111.133.50:8333` (`svc/seaweedfs-s3` in
  `kube-storage`). With a hostname, minio-go switches to virtual-host style (`bucket.<host>`), which
  does not resolve here; an IP address keeps it path-style. (If you prefer a hostname, you will need a
  wildcard DNS entry for `*.seaweedfs-s3…` — not worth it.)
* Credentials: secret `kube-storage/seaweedfs-s3-secret`, keys `admin_access_key_id` /
  `admin_secret_access_key` (S3 identity `anvAdmin`: Admin+Read+Write) and `read_*` (read-only). The
  full identity list lives in `seaweedfs_s3_config` in that same secret. Reference them with
  `secretKeyRef`; never inline them in HCL or echo them into logs.
* **Give oCIS its own bucket.** `s3ng` has **no bucket-prefix option** — verified against the 8.3
  config reference, which lists only `root/region/access_key/secret_key/endpoint/bucket` plus
  `put_object_*`, and verified empirically: uploads produced objects keyed by the decomposedfs
  relative path (`<opaque-id>/ab/cd/ef/…`). Pointing it at the existing `documents` bucket would merge
  oCIS's namespace **into `/documents/users/` beside the personal folders**. Pick something like
  `ocis` (or `ocis-blobs`); creating it is `aws --profile k8s s3api create-bucket --bucket <name>`.
* SeaweedFS here is **single-copy**: master `-defaultReplication=001`, filer
  `-defaultReplicaPlacement=001`; volumes are 1 GB (`-volumeSizeLimitMB=1000`), volume servers run
  `-readMode=proxy -compactionMBps=50`. Longhorn is 3-replica by design (see the longhorn fix commit).
  So blobs in S3 are the least-protected copy in the system: decide explicitly whether to raise
  replication for the oCIS bucket, or to treat S3 as a cache with Longhorn/low-level copies as truth.
* Measured S3 behaviour worth designing around: one object per uploaded file; `put_object_disable_multipart`
  defaults to true (single PUT — fine at 100 MB); big-file write 117 MB/s, read 80 MB/s (reads are the
  slowest of the three configurations because they traverse the gateway); one transient
  `425 Too Early` on a `GET` issued immediately after upload (retry succeeds) — expect to retry in
  sync clients and in automation.
* From your laptop the same gateway is reachable as `https://s3.vn.linuxguru.net` through the `k8s`
  AWS profile in `~/.aws/config` (which sets `request_checksum_calculation` /
  `response_checksum_validation = when_required`, required by SeaweedFS). Use it for bucket
  inspection/creation; the workload itself must use the in-cluster service.

### 2.3 The oCIS config surface that actually matters

These are the only settings needed for a working instance (verified twice, including on `s3ng`):

```
OCIS_URL=https://<host>:9200          # MUST be https:// — the embedded IDP refuses anything else
OCIS_INSECURE=true                    # relaxed/self-signed TLS between its own services
PROXY_TLS=true                        # standalone: oCIS terminates TLS itself.
                                      # behind our gateway set false (upstream compose does exactly that)
OCIS_BASE_DATA_PATH=/data/ocis/data   # config, IDM boltdb, idp keys, NATS, metadata root
OCIS_CONFIG_DIR=/data/ocis/config
IDM_ADMIN_PASSWORD=<secret>           # sets/overrides the admin password
PROXY_ENABLE_BASIC_AUTH=true          # WebDAV/curl scripts; OIDC still works alongside
OCIS_LOG_LEVEL=warning
STORAGE_USERS_DRIVER=s3ng
STORAGE_USERS_S3NG_ROOT=/data/ocis/data/storage/users
STORAGE_USERS_S3NG_ENDPOINT=http://10.111.133.50:8333
STORAGE_USERS_S3NG_REGION=default
STORAGE_USERS_S3NG_BUCKET=<dedicated bucket>
STORAGE_USERS_S3NG_ACCESS_KEY / _SECRET_KEY      # via secretKeyRef
```

Gotchas, all hit for real:

* **oCIS calls its own `OCIS_URL`** for the data service (`PUT https://<OCIS_URL host>/data`), so the
  pod must be able to resolve and reach that name. In testing: `hostAliases: 127.0.0.1` +
  `PROXY_TLS=true`. In production behind the gateway: the pod needs `ocis.<domain>` to resolve to the
  gateway (hostAliases to the gateway ClusterIP, or an in-cluster DNS record) — the internal call
  then leaves and re-enters through the gateway over TLS, which works. Symptom if you forget:
  every upload fails with `dial tcp: lookup <host>: no such host`, while the web UI loads fine.
* `ocis init` is not idempotent on its own: use `ocis init || true; exec ocis server` (upstream
  compose does the same). `ocis server` is the image's default CMD; calling `ocis` with **no argument
  prints help and exits 0** — a silent no-op that looks like a crash-loop.
* Wiping the IDM store on an existing data dir re-seeds the admin from `IDM_ADMIN_PASSWORD`; without
  that, basic auth fails with a bare `Authentication error` and nothing in the log.
* **Deletions go to trash**: removing 200 files changed nothing on disk/S3 until the trash is purged.
  Factor that into space planning and into any "durable delete" expectation.
* oCIS is its own IdP by default (embedded `idp` + `idm`). Driving it from authentik instead is
  **unverified** — see §7.

## 3. Environment facts (verified on this cluster)

**Tooling**

* `tofu` 1.11.6 at `/opt/homebrew/bin/tofu`; `kubectl`, `helm`, `mpssh` present. `aws` CLI with
  profiles `default`, `k8s` (SeaweedFS S3), `backblaze`.
* Always `git --no-pager` (a global rule). Run tofu from `stacks/mantle`.
* `mpssh "<cmd>"` runs on every node, but **the command must stay short** — a few hundred characters
  is already "command too long". Put a script file somewhere and invoke that instead of inlining.
* The nodes have **no `setfattr`/`getfattr`**; the oCIS image does (Alpine base ships `attr`, `curl`,
  `tree`, `flock`, `stat`, `seq`). The old FileBrowser image had busybox without `cat`/`setfattr` and
  an `ls` without `-f`.
* `kubectl rollout restart` writes `kubectl.kubernetes.io/restartedAt` into the pod template, which
  appears as drift in the next `tofu plan`. Apply once afterwards to clear it, or nudge the pod
  another way.

**Storage**

* StorageClasses: `longhorn` (default, 3 replicas, longhorn 1.12.1), `longhorn-static`,
  `seaweedfs-csi` (RWX, `reclaimPolicy: Delete` for *dynamic* PVCs, `Immediate` binding, expansion
  allowed, driver `seaweedfs-csi-driver:1.4.32`).
* The seaweedfs CSI mount is a FUSE mount of a bucket path — inside a pod, `/documents` was
  `seaweedfs-filer:8888:/buckets/documents`, reported as 10.3T. SeaweedFS buckets are directories under
  `/buckets` in the filer, so a bucket can be made with mkdir or via the S3 API.
* The **static PV + `Retain`** pattern is how a bucket is exposed without risking it: PV with
  `csi { driver = "seaweedfs-csi-driver"; volume_handle = "<bucket>" }`, a matching label (the old
  module used `seaweed_id`), a claim with a `selector` on that label, and
  `persistentVolumeReclaimPolicy = "Retain"`. Deleting such a PV does **not** delete the bucket (no
  `pv.kubernetes.io/provisioned-by` annotation) — that is exactly why the `documents` bucket survived
  this teardown.
* SeaweedFS topology: filer `seaweedfs-filer.kube-storage:8888`, S3 `seaweedfs-s3` ClusterIP
  `10.111.133.50:8333`, plus `seaweedfs-master`, six `seaweedfs-volume`, `seaweedfs-admin`. Buckets in
  use: `backupstore` (Velero), `blender-blender`, `documents`, `movies-archive`, `photos`, plus
  per-PVC dynamic ones.

**Networking / exposure / identity / observability**

* Per-app namespaces carry **restricted egress** (Calico netpols from
  `modules/network/firewalls/{ingress,egress}`). The old `documents` namespace could not reach the S3
  service — so plan oCIS's egress policy to allow the S3 endpoint (and authentik), or run
  cross-namespace experiments from a permissive namespace (that is why the s3ng test ran in
  `kube-storage`).
* Exposure goes through `modules/network/gateway/expose` → `ListenerSet`/`HTTPRoute` on the shared
  `private` gateway in `kube-network`, with `cert_issuer = var.deployment.cert_manager.external_issuer`.
  App hostnames are `*.<deployment.cluster.domains.private>` = `*.vn.linuxguru.net`. The old app used
  `docs.`; for oCIS pick something like `cloud.` or `files.` and keep it stable — it is baked into
  `OCIS_URL`, the authentik redirect URI and stored state.
* authentik lives at `auth.<domain>`. `modules/auth/authentik/oidc_provider` now also supports
  `bind_app` (binds **both** its own `-admin` and `-user` groups), `meta_launch_url`, and exposes
  `admin_group_id` / `user_group_id`. Those three files are modified-but-uncommitted on purpose; keep
  them.
* Monitoring is Prometheus Operator: rules need `release = prometheus` to be loaded (see the old
  `monitoring.tf` pattern: `kubectl_manifest` + `PrometheusRule`). A ServiceMonitor only if the app
  exposes metrics — oCIS does (its services have metrics endpoints), which the old app could not offer.
* Backups: `modules/storage/backup/schedule` (Velero) against Longhorn claims; SeaweedFS/bucket data is
  deliberately outside Velero. Old `filebrowser-data` backups still sit in `s3://backupstore` —
  harmless, delete when convenient. For oCIS you need Velero on the **metadata PVC** *and* a story for
  the **blob bucket** (versioning or an S3-level copy): the two halves must be restored consistently.

## 4. Where the code goes, and in what style

Mirror the shape of the app that was just removed (`implementation_plan.filebrowser.md` documents it;
the deleted tree was `modules/documents/{providers,variables,locals,namespace,workload,volumes,auth,
ingress,egress,listener,backup,monitoring}.tf` plus a nested `modules/documents/<app>/` holding the
workload). For oCIS:

```
modules/ocis/                  # app-level: namespace, claims, netpols, ingress, auth, backup, alerts
  providers.tf variables.tf locals.tf namespace.tf volumes.tf auth.tf
  ingress.tf egress.tf listener.tf workload.tf backup.tf monitoring.tf
  ocis/                        # workload only: providers, variables, locals, config, deployment, service
stacks/mantle/ocis.tf          # module "ocis" { source = "../../modules/ocis"; ... }
```

Conventions that are not negotiable in this repo:

* **Every input is a variable with a sensible default** (`namespace`, `name`, `domain`, `cert_issuer`,
  `hostname = null` → `coalesce`, `image`, `image_tag`, sizes, `oidc_app_name`, `icon = null`, …), so the
  stack file states only what is environment-specific (hostname, icon, issuer).
* Resource names use descriptive names;; labels are `{ "app.kubernetes.io/name" = var.name }`; comments are terse,
  one line, and explain **why**. If a comment is needed to explain *what*, rewrite the code.
* Runtime config is rendered from `locals` into a ConfigMap with
  `annotations["checksum/config"] = sha256(jsonencode(...))` on the pod template, so changing config
  rolls the deployment by itself. Any `ocis.yaml` should be generated, never baked into an image, and
  mounted read-only.
* Secrets: `kubernetes_secret_v1` fed by `sensitive = true` variables. Kubernetes has no
  cross-namespace secret references, so to reuse `seaweedfs-s3-secret` either read it with
  `data "kubernetes_secret_v1"` and write an app-namespace copy (value lands in tofu state — say so in
  a comment), or keep oCIS's S3 credentials in a separate secret created out-of-band.
* Static PV + `Retain` for anything backed by a SeaweedFS bucket (§3); Longhorn for stateful metadata.
* Gate every claim of success: `tofu fmt -recursive -check .`, `tofu validate`, `tofu plan` from
  `stacks/mantle` must be clean, and a post-apply plan must say **No changes**. `apply` output should
  be quoted verbatim in your summary.
* Do not touch the `terraform.tfvars` symlinks. Apps belong in `stacks/mantle`. `mpssh`, Longhorn and
  SeaweedFS are the sanctioned plumbing.

## 5. Order of work (and what each step must prove)

(Note: this should all be done by terraform, not by hand!) 

1. **Storage first.** Create the dedicated S3 bucket; copy the S3 credentials into the app namespace
   (or decide on the out-of-band secret). Create the Longhorn PVC for the metadata root (2–5 Gi is
   plenty at this scale).
2. **Module scaffold** — `providers/variables/locals/namespace`, plus the nested `ocis/` workload
   variables, so names and namespaces exist before anything references them.
3. **Network + exposure** (`listener.tf`, `ingress.tf`, `egress.tf`) — including egress **to the S3
   endpoint**; apply and prove hostname/cert/route before any app state exists.
4. **Identity** (`auth.tf` via `modules/auth/authentik/oidc_provider` with `bind_app = true`,
   `meta_launch_url`, icon) — then add group memberships by hand in authentik.
5. **Workload** — ConfigMap/Secret + Deployment + Service. Expect two config rounds: `OCIS_URL`/TLS and
   the s3ng block. Verify in logs that it says `driver=s3ng` and reaches S3 (no `dial tcp` errors).
6. **Operations** — Velero schedule on the metadata PVC, PrometheusRule(s) with `release = prometheus`,
   and (bonus, oCIS supports it) a ServiceMonitor for its metrics endpoint.
7. **Acceptance** — §6, and record the numbers you get; they are the baseline for the next change.

## 6. Acceptance tests (what "it works" means here)

How to drive it — verified:

* Session for scripts: `PROXY_ENABLE_BASIC_AUTH=true` + `curl -k -u admin:<IDM_ADMIN_PASSWORD>`. There is
  **no `/api/auth/login`** here; that was FileBrowser. OIDC also works and coexists.
* WebDAV base that answered: `https://<host>:9200/dav/files/<username>/` (207 on PROPFIND).
  `/dav/spaces/` answers **405** to PROPFIND — that is normal, not a permission problem. Space IDs come
  from `GET /graph/v1.0/me/drives` (200 with basic auth); a personal drive id looks like
  `<opaque>$<opaque>`.
* Upload: `curl -sk -u u:p -T <file> "<base>/<path>"` → expect **201**; DELETE a folder → **204**.
* oCIS's own tools are the best yardstick:
  `ocis benchmark syscalls --path <a-file> --iterations 500` (a *directory* fails the write tests with
  `is a directory`) and `ocis benchmark client -X PROPFIND -u u:p -j <jobs>` for HTTP load.

Checks, in the order they matter:

1. **Ingest rate** — 200 × 13-byte files over WebDAV, serial, and again with
   `xargs -P 20`. Baseline to beat/hold: ~160 ms/file serial, **all 200 succeeding** under 20-way
   parallelism. Any HTTP 500 with `no such file or directory` means metadata landed on a FUSE mount —
   go back to §2.1.
2. **Bulk transfer** — 100 MB PUT and GET: ~117 MB/s write, ~80 MB/s read with s3ng. Retry once on
   `425 Too Early`; if it never succeeds, that is a real bug to chase.
3. **Placement proof, not assumption** — after ~400 uploads:
   `aws --profile k8s s3 ls --recursive s3://<bucket> | wc -l` must equal the number of uploads (one
   object per file), while `find <metadata root> -type f | wc -l` grows by ~3 per upload and the whole
   metadata tree stays in the megabytes. That is the "blobs in S3, metadata locally" contract.
4. **The actual product requirement — sharing between two humans** (needs two accounts; create them via
   the IDM admin API or `IDM_CREATE_DEMO_USERS=true` on a test instance — *unverified which*):
   * A uploads a file into their personal space.
   * A shares it with B; B must see it **in their own account** (Shares / "shared with you"), open it,
     and download it. This is the behaviour FileBrowser could not provide, so test it explicitly and
     screenshot/log it.
   * B must **not** be able to write into A's personal space without a granted right.
   * Create the read-only shared tree as a **project space** shared with a group at the *viewer* role;
     confirm group members can read and cannot write, and that non-members cannot see the space at all.
5. **Identity** — once authentik is wired: log in through authentik, confirm the launchpad tile
   (`meta_launch_url`, icon), group-based access, and that a user outside the bound groups cannot log in.
6. **Operations** — Velero schedule present and Enabled on the metadata PVC; PrometheusRule loaded
   (label `release=prometheus`); if you wire the metrics endpoint, show a scrape in the Prometheus UI.
   Delete a file and confirm the trash behaviour (§2.3) so nobody is surprised later.

## 7. Open questions — decide these deliberately, do not let them default

1. **oCIS vs its community fork.** `owncloud/ocis` v8.2.0 (Kiteworks) has releases this month and
   maintained Helm charts (`owncloud/ocis-charts`, pushed 2026-09-25). `opencloud-eu/opencloud` is the
   post-acquisition community fork (6k stars, same lineage, pushed the same day) whose only official
   deployment is Docker Compose — its community Helm charts are hobby-grade. The measurements in §2 were
   taken on **oCIS 8.2.0**. If the plan is charts + k8s, oCIS is the pragmatic pick; confirm with the
   user before building.
2. **authentik wiring — unverified.** By default oCIS runs its *own* IdP + IDM and manages users itself.
   Driving it from authentik means investigating `OCIS_OIDC_ISSUER`, excluding its embedded `idp`
   (`OCIS_EXCLUDE_RUN_SERVICES=idp`), `PROXY_AUTOPROVISION_ACCOUNTS`, `PROXY_USER_OIDC_CLAIM` and
   `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc`. Prove it in a throwaway namespace *before* making it the design.
   Keeping the built-in IDM is a legitimate answer if SSO parity is not required.
3. **Blob durability.** SeaweedFS here is single-copy (`001`). Either raise replication for the oCIS
   bucket, enable S3 versioning plus an off-site copy, or consciously accept that the metadata
   (3-replica Longhorn) is more durable than the data.
4. **Bucket name and the 3 orphaned files** in `documents` — re-home them into a space, or abandon
   (they are two photos and a screenshot from testing).
5. **Office / co-editing.** oCIS supports Collabora over WOPI. In scope now or later? The old plan
   deferred OnlyOffice; the same seam exists here.
6. **Quotas, trash retention, `share_folder` policy, and auto-provisioning behaviour** for new users —
   pick values instead of inheriting defaults.
7. **Is any of the shared-tree model needed at all** beyond the project-space viewer role? The user's
   earlier "flat root, read-only by default" idea maps onto exactly one thing in oCIS: a project space
   shared with a group as *viewer*. Start there, not with per-user shares of a shared directory.

## 8. Appendix — the setup that produced the numbers, so you can reproduce it in minutes

The s3ng test ran as a **single Pod** in `kube-storage` (chosen because that namespace has unrestricted
egress), with a 2 Gi Longhorn PVC for metadata. Trimmed manifest — copy, set `<bucket>`, apply:

```yaml
apiVersion: v1
kind: Pod
metadata: { name: ocis, namespace: <ns> }
spec:
  restartPolicy: Never
  securityContext: { fsGroup: 1000 }          # Longhorn volume must be writable by uid/gid 1000
  hostAliases:                                 # OCIS_URL must resolve inside the pod
    - ip: "127.0.0.1"
      hostnames: ["ocis.test"]
  containers:
    - name: ocis
      image: owncloud/ocis:8.2.0               # 78 MB, Alpine base (attr/curl/tree included)
      command: ["/bin/sh", "-c", "ocis init || true; exec ocis server"]
      env:
        - { name: OCIS_URL, value: "https://ocis.test:9200" }
        - { name: OCIS_INSECURE, value: "true" }
        - { name: PROXY_TLS, value: "true" }
        - { name: OCIS_BASE_DATA_PATH, value: "/data/ocis/data" }
        - { name: OCIS_CONFIG_DIR, value: "/data/ocis/config" }
        - { name: IDM_ADMIN_PASSWORD, value: "ocistestpw" }
        - { name: PROXY_ENABLE_BASIC_AUTH, value: "true" }
        - { name: OCIS_LOG_LEVEL, value: "warning" }
        - { name: STORAGE_USERS_DRIVER, value: "s3ng" }
        - { name: STORAGE_USERS_S3NG_ROOT, value: "/data/ocis/data/storage/users" }
        - { name: STORAGE_USERS_S3NG_ENDPOINT, value: "http://10.111.133.50:8333" }
        - { name: STORAGE_USERS_S3NG_REGION, value: "default" }
        - { name: STORAGE_USERS_S3NG_BUCKET, value: "<bucket>" }
        - name: STORAGE_USERS_S3NG_ACCESS_KEY
          valueFrom: { secretKeyRef: { name: seaweedfs-s3-secret, key: admin_access_key_id } }
        - name: STORAGE_USERS_S3NG_SECRET_KEY
          valueFrom: { secretKeyRef: { name: seaweedfs-s3-secret, key: admin_secret_access_key } }
      volumeMounts: [{ name: data, mountPath: /data }]
  volumes:
    - name: data
      persistentVolumeClaim: { claimName: <longhorn-pvc> }
```

The workload, exactly as measured (inside that pod; `B=https://ocis.test:9200`, `AUTH=admin:ocistestpw`):

```sh
# create a space/dir and a payload
curl -sk -o /dev/null -u $AUTH -X MKCOL "$B/dav/files/admin/bench"
printf small-payload > /tmp/s.txt ; dd if=/dev/zero of=/tmp/big.bin bs=1M count=100

# 200 serial small files, counting outcomes (do NOT skip the status count - silent failures cost me an hour)
t0=$(date +%s); i=0; ok=0; fail=0
while [ $i -lt 200 ]; do
  c=$(curl -sk -o /dev/null -w "%{http_code}" -u $AUTH -T /tmp/s.txt "$B/dav/files/admin/bench/f$i.txt")
  case "$c" in 201|204) ok=$((ok+1));; *) fail=$((fail+1));; esac; i=$((i+1))
done; echo "serial ok=$ok fail=$fail $(( $(date +%s)-t0 ))s"

# 100 MB up/down with throughput
curl -sk -o /dev/null -w "put=%{http_code} %{speed_upload}B/s\n" -u $AUTH -T /tmp/big.bin "$B/dav/files/admin/bench/big.bin"
curl -sk -o /dev/null -w "get=%{http_code} %{speed_download}B/s\n" -u $AUTH "$B/dav/files/admin/bench/big.bin"

# 20-way parallel (this is the case that 100%-failed on the FUSE PVC)
curl -sk -o /dev/null -u $AUTH -X MKCOL "$B/dav/files/admin/par"
p0=$(date +%s)
seq 1 200 | xargs -P 20 -I{} curl -sk -o /dev/null -w "%{http_code}\n" -u $AUTH -T /tmp/s.txt "$B/dav/files/admin/par/p{}.txt" > /tmp/codes.txt
echo "parallel ok=$(grep -c '20[14]' /tmp/codes.txt) fail=$(grep -vc '20[14]' /tmp/codes.txt) $(( $(date +%s)-p0 ))s"

# storage-level microbenchmark (file path, not a directory)
ocis benchmark syscalls --path /data/ocis/bench.dat --iterations 500
```

Counting what landed where:

```sh
aws --profile k8s s3 ls --recursive s3://<bucket> | wc -l        # 401 for 401 uploads = 1 object/file
find /data/ocis/data/storage -type f | wc -l                     # ~3 metadata files per upload
du -sh /data/ocis/data/storage                                   # stays in the MBs
```

Reference numbers (oCIS 8.2.0, this cluster, 2026-09-30): serial 200 files 32 s (s3ng) vs 31 s
(decomposedfs on Longhorn) vs 53 s (on the FUSE PVC); 20-way parallel 200/200 (s3ng and Longhorn) vs
0/200 (FUSE PVC); 401 S3 objects for 401 uploads with 1270 metadata files / 7.9 MB local; 100 MB PUT
117 MB/s, GET 80 MB/s (one transient `425`).

Cleanup etiquette that this session learned the hard way: delete the test Pod, the test PVC and any
temporary bucket when done, remove stray directories you created in shared buckets, and re-run
`tofu plan` at the end to prove you left no drift. Bucket deletion needs the objects gone first —
`s3 rm --recursive` then `s3api delete-bucket`; a leftover `PRE` entry means objects remain.






