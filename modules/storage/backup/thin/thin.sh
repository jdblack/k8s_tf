#!/bin/sh
# Retention for the daily chains: keep 2 dailies, then the newest backup in each of four windows
# (2-9d, 9-16d, 16-46d, 46-76d) => 6 points per target, ~76d deep. Velero's TTL is only a
# backstop, so nothing here races it. Deletion goes through DeleteBackupRequest, never
# `velero backup delete --all/--selector`: the controller is what removes the data too.
set -eu

NS=${VELERO_NAMESPACE:-kube-backup}
DRY_RUN=${DRY_RUN:-true}
MAX_DELETIONS=${MAX_DELETIONS:-50}

now=$(date -u +%s)

raw=$(kubectl -n "$NS" get backups.velero.io -o jsonpath='{range .items[*]}{.metadata.labels.velero\.io/schedule-name}{"\t"}{.status.startTimestamp}{"\t"}{.status.phase}{"\t"}{.metadata.name}{"\n"}{end}')

if [ -z "$raw" ]; then
  echo "no backups listed, refusing to act"
  exit 1
fi

plan=$(printf '%s\n' "$raw" | sort -k1,1 -k2,2r | awk -v now="$now" '
function days_from_civil(y, m, d,   yy, era, yoe, doy, doe) {
  yy = y - (m <= 2 ? 1 : 0)
  era = int(yy / 400)
  yoe = yy - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function epoch(ts,   y, mo, d, h, mi, s) {
  y = substr(ts, 1, 4) + 0; mo = substr(ts, 6, 2) + 0; d = substr(ts, 9, 2) + 0
  h = substr(ts, 12, 2) + 0; mi = substr(ts, 15, 2) + 0; s = substr(ts, 18, 2) + 0
  return days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s
}
{
  target = $1; ts = $2; phase = $3; name = $4

  if (target != prev) { prev = target; rank = 0 }
  rank++

  age = (now - epoch(ts)) / 86400
  keep = 0; why = ""

  if (rank <= 2) {
    keep = 1; why = "daily"
  } else {
    if (age < 9) win = "week-1"
    else if (age < 16) win = "week-2"
    else if (age < 46) win = "month-1"
    else if (age < 76) win = "month-2"
    else win = ""
    if (win != "" && !seen[target "|" win]++) { keep = 1; why = win }
  }

  # Anything mid-flight, or not a plain success, is left alone.
  if (phase != "Completed") { keep = 1; why = "unfinished" }

  printf "%s\t%s\t%s\t%.1f\t%s\n", keep ? "keep" : "delete", target, name, age, why
}')

echo "== retention plan, dry_run=$DRY_RUN, $(date -u +%FT%TZ)"
printf '%s\n' "$plan" | awk -F'\t' '{ printf "%-6s %-24s %-45s age=%-7s %s\n", $1, $2, $3, $4, $5 }'

deletes=$(printf '%s\n' "$plan" | awk -F'\t' '$1 == "delete" { printf "%06d\t%s\n", $4 * 10, $3 }' | sort -rn | cut -f2)

if [ -z "$deletes" ]; then
  echo "nothing to delete"
  exit 0
fi

wanted=$(printf '%s\n' "$deletes" | wc -l)
if [ "$wanted" -gt "$MAX_DELETIONS" ]; then
  echo "plan wants $wanted deletions; taking the $MAX_DELETIONS oldest"
  deletes=$(printf '%s\n' "$deletes" | head -n "$MAX_DELETIONS")
fi

if [ "$DRY_RUN" = "true" ]; then
  printf '%s\n' "$deletes" | sed 's/^/would delete /'
  exit 0
fi

printf '%s\n' "$deletes" | while IFS= read -r name; do
  [ -n "$name" ] || continue
  kubectl -n "$NS" create -f - >/dev/null <<EOF
apiVersion: velero.io/v1
kind: DeleteBackupRequest
metadata:
  generateName: thin-
  namespace: $NS
spec:
  backupName: $name
EOF
  echo "requested deletion of $name"
done
