# Playing with Lance from DuckDB

Reading and writing Lance datasets in the `lancedemo` table bucket directly over
SeaweedFS S3 — no catalog needed when you know the dataset path. Server side:
`modules/storage/seaweedfs` (`s3.lancePort = 9101` on the s3 gateway).

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
-- write two rows (this creates the dataset)
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

DuckDB creates and maintains the dataset entirely over S3 — there is no catalog
step and no `lance.<domain>` host. (The Lance Namespace REST still runs on the s3
gateway's 9101 port for clients that need name-based discovery, but it is not
exposed.)
