{#
  Replaces dbt-duckdb's `table` materialization for this project.

  The stock one builds <model>__dbt_tmp, renames the old table to a backup and renames the
  new one into place, all in one transaction. On an Iceberg REST catalog (S3 Tables) that
  fails with:
    "Iceberg REST Catalog cannot commit this transaction atomically because it mixes
     table updates with rename/drop requests"

  So this drops the old table (plain DROP TABLE: dbt's own drop adds CASCADE, and Iceberg
  rejects that), commits, then runs CREATE TABLE AS in a new transaction, with no rename.
  Tried and rejected by DuckDB-Iceberg on S3 Tables:
    - CREATE OR REPLACE TABLE   "not supported in DuckDB-Iceberg"
    - DROP ... CASCADE          "not supported for Iceberg tables currently"
    - drop + create in one transaction  "Cannot create table deleted within a transaction" Trade-off:
  the table is briefly missing while a model rebuilds, and a failed build leaves no previous
  version.
#}
{% materialization table, adapter="duckdb" %}
  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set existing_relation = load_cached_relation(this) -%}

  {{ run_hooks(pre_hooks) }}

  {#- Plain DROP: dbt's drop_relation_if_exists appends CASCADE, which Iceberg rejects -#}
  {% if existing_relation is not none %}
    {% call statement('drop_existing') -%}
      drop table if exists {{ existing_relation }}
    {%- endcall %}
    {#- Commit the drop first: Iceberg can't create a table dropped in the same transaction -#}
    {{ adapter.commit() }}
  {% endif %}

  {% call statement('main') -%}
    {{ create_table_as(False, target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}
  {% do persist_docs(target_relation, model) %}
  {{ adapter.commit() }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
