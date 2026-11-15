# dbt version

Same result as the plain DuckDB walkthrough (`services` and `services_per_month`), but the SQL
lives in dbt models. dbt opens a DuckDB connection, installs the extensions, creates the S3 secret,
attaches the Iceberg catalog, then runs each model as `CREATE TABLE AS` into it. dbt adds dependency
ordering (`ref`), tests and docs.

This uses **dbt 2** (the native `dbt` binary, e.g. `brew install dbt`), which supports Iceberg
catalogs through `catalogs.yml`. See the
[dbt docs](https://docs.getdbt.com/docs/build/iceberg/adapters/duckdb-iceberg-support?version=2).
The older Python `dbt-core` + `dbt-duckdb` adapter does not read `catalogs.yml`.

| Plain DuckDB | dbt |
|---|---|
| `duckdb-init.sql` (extensions, secret) | `extensions` and `secrets` in `profiles.yml` |
| `ATTACH ... AS s3_tables` | `catalogs.yml` |
| `CREATE TABLE s3_tables.duckdb.x AS ...` | `models/x.sql` (just the `select`) |
| table names and order by hand | `{{ ref('services') }}` |
| the namespace in every table name | `+schema` and `+catalog_name` in `dbt_project.yml` |

## Run

Provision with OpenTofu first (see the parent README), then from this directory:

```bash
# Option A/B: S3 Tables endpoint (default)
export S3T_WAREHOUSE="$(tofu -chdir=../tofu output -raw table_bucket_arn)"

# Option C: Glue endpoint instead
# export S3T_WAREHOUSE="$(tofu -chdir=../tofu output -raw glue_warehouse)"
# export S3T_CATALOG_API=glue

dbt build --profiles-dir .                            # run models, then tests
dbt run   --profiles-dir . -s services_per_month      # one model
```

`AWS_REGION` (default `eu-central-1`) and `S3T_NAMESPACE` (default `duckdb`) must match your tofu values.

## Delete the tables

dbt has no drop command. This project has a macro that drops the table of every model:

```bash
dbt run-operation drop_models --args '{dry_run: true}' --profiles-dir .   # preview
dbt run-operation drop_models --profiles-dir .                            # drop
```

Run it before `tofu destroy`.

## Notes

- `catalogs.yml` sets `stage_create_tables: false`, `disable_multi_table_commit: true` and
  `purge_requested: true`. S3 Tables and the Glue endpoint reject staged `CREATE TABLE AS` and
  multi-table commits, and S3 Tables only allows drops with purge. With them, the stock `table`
  materialization works: no custom macro is needed.
- `macros/generate_schema_name.sql` uses the namespace as the schema as-is. Without it dbt would
  build `main_duckdb`.
- dbt prints a "schema-wide relation listing is disabled" warning on each run. The builds still pass.
