# duckdb-s3tables

DuckDB writing and reading Apache Iceberg tables in Amazon S3 Tables.

## 1. Provision

```bash
cd tofu
tofu init && tofu apply
```

Creates:
- an S3 table bucket and a `duckdb` namespace
- the Glue integration (`s3tablescatalog`), only needed for connect option C
- an IAM policy for DuckDB

Optionally attach the policy to your identity:

```bash
aws iam attach-user-policy --user-name <you> --policy-arn "$(tofu output -raw iam_policy_arn)"
```

Values you'll need in the next steps:

```bash
tofu output -raw table_bucket_arn   # options A and B
tofu output -raw glue_warehouse     # option C
cd ..
```

## 2. Start DuckDB

From this directory, with the project init file. It keeps extensions in `.duckdb/extensions`
(instead of `~/.duckdb`), installs and loads `aws`, `httpfs` and `iceberg`, and creates the S3
secret from your AWS credential chain:

```bash
duckdb -init duckdb-init.sql
```

Run the statements in the following steps one at a time. If you'd rather type the init file yourself:

```sql
SET extension_directories = ['.duckdb/extensions'];

INSTALL aws;
INSTALL httpfs;
INSTALL iceberg;

LOAD aws;
LOAD httpfs;
LOAD iceberg;

CREATE OR REPLACE SECRET (TYPE s3, PROVIDER credential_chain);
```

## 3. Connect (pick one)

The same table bucket can be reached through three catalog endpoints. Pick **one** and attach it
as `s3_tables`, so the rest of the walkthrough is identical. Inside the DuckDB shell, environment
variables aren't expanded, so paste the real values from step 1 in place of the examples.

| | Endpoint | `ATTACH` string | Extra setup |
|---|---|---|---|
| **A. S3 Tables shortcut** | built for you | table bucket ARN | none |
| **B. S3 Tables Iceberg REST** | `s3tables.<region>.amazonaws.com/iceberg` | table bucket ARN | none |
| **C. Glue Iceberg REST** | `glue.<region>.amazonaws.com/iceberg` | `<account-id>:s3tablescatalog/<bucket>` | Glue integration (created in step 1) |

### Option A: S3 Tables shortcut

```sql
ATTACH 'arn:aws:s3tables:eu-central-1:123456789012:bucket/duckdb-s3tables-demo' AS s3_tables (
    TYPE iceberg,
    ENDPOINT_TYPE s3_tables
);
```

### Option B: S3 Tables Iceberg REST endpoint

The same endpoint as A with the URI spelled out. Use this form in AWS China regions, where the
shortcut builds the wrong URL.

```sql
ATTACH 'arn:aws:s3tables:eu-central-1:123456789012:bucket/duckdb-s3tables-demo' AS s3_tables (
    TYPE iceberg,
    URI 'https://s3tables.eu-central-1.amazonaws.com/iceberg',
    AUTHORIZATION_TYPE 'sigv4'
);
```

AWS doesn't support staged table creation on this endpoint, so `CREATE TABLE ... AS SELECT` may be
rejected. If it is, add `STAGE_CREATE_TABLES false` to the `ATTACH` options (untested).

### Option C: Glue Data Catalog (Glue Iceberg REST endpoint)

DuckDB talks to Glue, which exposes the bucket as the federated catalog `s3tablescatalog`.
Note the warehouse format: `<account-id>:s3tablescatalog/<bucket-name>`, not the ARN.

```sql
ATTACH '123456789012:s3tablescatalog/duckdb-s3tables-demo' AS s3_tables (
    TYPE iceberg,
    ENDPOINT_TYPE glue
);
```

Or with the URI spelled out (needed in AWS China regions):

```sql
ATTACH '123456789012:s3tablescatalog/duckdb-s3tables-demo' AS s3_tables (
    TYPE iceberg,
    URI 'https://glue.eu-central-1.amazonaws.com/iceberg',
    AUTHORIZATION_TYPE 'sigv4'
);
```

Notes for C:
- **Lowercase only.** Tables and columns with capital letters are invisible through Glue. The demo's
  `"Service:Date"` columns would hide the tables from C, so in step 5 alias them to lowercase names,
  as shown there.
- `s3tablescatalog` is one per account and region and covers every table bucket in it. If it
  already exists, `tofu apply` fails: set `-var enable_glue_integration=false`, or import it with
  `tofu import 'aws_glue_catalog.s3tables[0]' s3tablescatalog` (import ID not verified).
- To use a dedicated role, recreate the secret before attaching:

  ```sql
  CREATE OR REPLACE SECRET (
      TYPE s3,
      PROVIDER credential_chain,
      CHAIN sts,
      ASSUME_ROLE_ARN 'arn:aws:iam::123456789012:role/<role>',
      REGION 'eu-central-1'
  );
  ```

- The IAM mode used here needs no Lake Formation grants. If you switch the integration to Lake
  Formation mode, you also need grants on the database and tables, and **Allow external engines to
  access data in Amazon S3 locations with full table access** in *Application integration settings*.

> Only the `ATTACH` syntax was checked against DuckDB; B and C haven't been run against a real account.

## 4. Check the connection

```sql
SHOW ALL TABLES;
```

## 5. Create tables

```sql
CREATE TABLE s3_tables.duckdb.services AS
    FROM 'https://blobs.duckdb.org/nl-railway/services-2025-03.csv.gz';
```

```sql
CREATE TABLE s3_tables.duckdb.services_per_month AS
    SELECT month("Service:Date") AS month,
           "Stop:Station name" AS station,
           count(*) AS num_services
    FROM s3_tables.duckdb.services
    GROUP BY ALL;
```

Option C needs lowercase column names. Use this version of the first table instead:

```sql
CREATE TABLE s3_tables.duckdb.services AS
    SELECT "Service:Date" AS service_date,
           "Stop:Station name" AS station
    FROM 'https://blobs.duckdb.org/nl-railway/services-2025-03.csv.gz';

CREATE TABLE s3_tables.duckdb.services_per_month AS
    SELECT month(service_date) AS month, station, count(*) AS num_services
    FROM s3_tables.duckdb.services
    GROUP BY ALL;
```

## 6. Query

```sql
SELECT * FROM s3_tables.duckdb.services_per_month
ORDER BY num_services DESC
LIMIT 10;
```

Optional web UI:

```sql
CALL start_ui();
```

## 7. Cleanup

DuckDB created the tables, not OpenTofu, so drop them first:

```sql
DROP TABLE s3_tables.duckdb.services_per_month;
DROP TABLE s3_tables.duckdb.services;
```

Then destroy the infrastructure. This also removes `s3tablescatalog`, which is shared by every
table bucket in the account and region. If other buckets use it, drop it from state first so
it is kept:

```bash
cd tofu
tofu state rm 'aws_glue_catalog.s3tables[0]'   # only if you want to keep the catalog
tofu destroy
```

## Run everything at once

`./run_duckdb.sh` runs steps 2 to 6 with option A (reads ARN and region from `tofu output`).
`./run_duckdb.sh --ui` also starts the web UI.
