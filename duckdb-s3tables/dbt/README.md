# dbt version

Same result as the plain DuckDB walkthrough (`services` and `services_per_month`), but the SQL
lives in dbt models. dbt-duckdb opens a DuckDB connection, installs the extensions, creates the S3
secret and runs the `ATTACH` from `profiles.yml`, then runs each model as `CREATE TABLE AS` into the
attached catalog. dbt adds dependency ordering (`ref`), tests and docs.

| Plain DuckDB | dbt |
|---|---|
| `duckdb-init.sql` (extensions, secret) | `extensions` and `secrets` in `profiles.yml` |
| `ATTACH ... AS s3_tables` | `attach` in `profiles.yml` |
| `CREATE TABLE s3_tables.duckdb.x AS ...` | `models/x.sql` (just the `select`) |
| table names and order by hand | `{{ ref('services') }}` |
| `+database: s3_tables`, `+schema: duckdb` | `dbt_project.yml` |

## Run

Provision with OpenTofu first (see the parent README), then from this directory:

```bash
uv sync

# Option A: S3 Tables endpoint
export S3T_WAREHOUSE="$(tofu -chdir=../tofu output -raw table_bucket_arn)"
# Option C: Glue endpoint instead
# export S3T_WAREHOUSE="$(tofu -chdir=../tofu output -raw glue_warehouse)"
# export S3T_ENDPOINT_TYPE=glue

uv run dbt build --profiles-dir .          # run models, then tests
uv run dbt run   --profiles-dir . -s services_per_month   # one model
```

`S3T_NAMESPACE` (default `duckdb`) must match the `namespace` variable in tofu.

## Delete the tables

dbt has no drop command (`dbt clean` only removes local folders). This project has a macro
that drops the table of every model:

```bash
uv run dbt run-operation drop_models --args '{dry_run: true}' --profiles-dir .   # preview
uv run dbt run-operation drop_models --profiles-dir .                            # drop
```

Run it before `tofu destroy`.

A custom `table` materialization (`macros/table_no_rename.sql`) drops each table, commits, then recreates it.
The stock one renames, and DuckDB-Iceberg rejects `CREATE OR REPLACE`, `DROP ... CASCADE`, and a rename
or a drop mixed with table updates in one transaction. A table is briefly missing during a rebuild.
