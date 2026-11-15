-- Project-level DuckDB setup. Use with: duckdb -init duckdb-init.sql
-- Paths are relative, so launch duckdb from this directory.
SET extension_directories = ['.duckdb/extensions'];

INSTALL aws;
INSTALL httpfs;
INSTALL iceberg;

LOAD aws;
LOAD httpfs;
LOAD iceberg;

CREATE OR REPLACE SECRET (TYPE s3, PROVIDER credential_chain);
