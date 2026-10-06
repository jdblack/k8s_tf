# Playing with Lance from DuckDB

Quickstart for the Lance Namespace REST that SeaweedFS serves at
`lance.seaweedfs.vn.linuxguru.net`, and for reading/writing Lance datasets in
the `lancedemo` table bucket. The server side lives in
`modules/storage/seaweedfs` (`s3.lancePort = 9101`, `module.expose_lance`).

## 1. A DuckDB with Lance

`lance` is a **core** DuckDB extension — install it *without* `FROM community`
(the community repo stopped building it after 1.5.0, so `FROM community` 404s on
1.5.6). Install once:

```
duckdb -c "INSTALL lance; INSTALL httpfs;"
```

`LOAD lance;` gives `__lance_scan`, `lance_vector_search`, `lance_fts`, … .

## 2. Point DuckDB at SeaweedFS S3

Use the S3 identity — the `k8s` AWS profile — and a `TYPE LANCE` secret:

```sql
LOAD lance; LOAD httpfs;
CREATE SECRET sw (
  TYPE LANCE, PROVIDER config, SCOPE 's3://lancedemo/',
  ACCESS_KEY_ID     '<aws configure get aws_access_key_id     --profile k8s>',
  SECRET_ACCESS_KEY '<aws configure get aws_secret_access_key --profile k8s>',
  REGION 'vn',
  ENDPOINT 'https://s3.vn.linuxguru.net',
  VIRTUAL_HOSTED_STYLE_REQUEST false
);
```

## 3. Super-simple demo — write, then read

A table bucket only accepts objects under `<namespace>/<table>/data|metadata`,
so the dataset lives at `s3://lancedemo/<namespace>/<table>/`:

```sql
-- write two rows
COPY (SELECT 1::BIGINT AS id, 'alpha'::VARCHAR AS s
      UNION ALL SELECT 2::BIGINT, 'beta')
  TO 's3://lancedemo/jblack/lancedemo/' (FORMAT lance, mode 'overwrite');

-- read them back
SELECT * FROM __lance_scan('s3://lancedemo/jblack/lancedemo/') ORDER BY id;
```
```
┌───────┬─────────┐
│  id   │    s    │
│ int64 │ varchar │
├───────┼─────────┤
│     1 │ alpha   │
│     2 │ beta    │
└───────┴─────────┘
```

Gotchas:

- Writing at the bucket root → `403 AccessDenied`; a table bucket wants
  `<namespace>/<table>/…`.
- `SELECT * FROM 's3://…/lancedemo'` (no `.lance` suffix) → "Table does not
  exist"; use `__lance_scan('s3://…')` for those paths.
- Writing objects does **not** register the table in the Lance catalog
  (see below) — that is a separate declare step.

## 4. The catalog (optional)

The namespace REST wants an OAuth2 token whose client credentials *are* the S3
keys:

```sh
BASE=https://lance.seaweedfs.vn.linuxguru.net
AK=$(aws configure get aws_access_key_id     --profile k8s)
SK=$(aws configure get aws_secret_access_key --profile k8s)

TOKEN=$(curl -s -X POST "$BASE/oauth/token" \
  -d grant_type=client_credentials -d client_id="$AK" -d client_secret="$SK" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -s -H "Authorization: Bearer $TOKEN" "$BASE/v1/namespace/%24/list"
```

Routes: `/v1/namespace/{id}/list`, `/v1/table/{id}/describe`, `/v1/table` …,
where a table identifier is `bucket.namespace.table`.
