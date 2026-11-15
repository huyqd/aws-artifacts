#!/usr/bin/env bash
# Runs the DuckDB + Iceberg + S3 Tables demo against the bucket created by tofu/.
# Usage: ./run_duckdb.sh [--ui]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" # duckdb-init.sql uses paths relative to this directory

command -v duckdb >/dev/null || { echo "duckdb CLI not found (brew install duckdb)" >&2; exit 1; }
command -v tofu   >/dev/null || { echo "tofu not found" >&2; exit 1; }

ARN="${TABLE_BUCKET_ARN:-$(tofu -chdir="$DIR/tofu" output -raw table_bucket_arn)}"
NS="${NAMESPACE:-$(tofu -chdir="$DIR/tofu" output -raw namespace)}"
export AWS_REGION="${AWS_REGION:-$(tofu -chdir="$DIR/tofu" output -raw region)}"
export AWS_DEFAULT_REGION="$AWS_REGION"

SETUP="ATTACH '${ARN}' AS s3_tables (TYPE iceberg, ENDPOINT_TYPE s3_tables);"

if [[ "${1:-}" == "--ui" ]]; then
  duckdb -init duckdb-init.sql -cmd "$SETUP" -cmd "CALL start_ui();"
  exit 0
fi

duckdb -init duckdb-init.sql -c "$SETUP
SHOW ALL TABLES;

DROP TABLE IF EXISTS s3_tables.${NS}.services_per_month;
DROP TABLE IF EXISTS s3_tables.${NS}.services;

CREATE TABLE s3_tables.${NS}.services AS
  FROM 'https://blobs.duckdb.org/nl-railway/services-2025-03.csv.gz';

CREATE TABLE s3_tables.${NS}.services_per_month AS
  SELECT month(\"Service:Date\") AS month,
         \"Stop:Station name\" AS station,
         count(*) AS num_services
  FROM s3_tables.${NS}.services
  GROUP BY ALL;

SELECT * FROM s3_tables.${NS}.services_per_month
ORDER BY num_services DESC LIMIT 10;
"
