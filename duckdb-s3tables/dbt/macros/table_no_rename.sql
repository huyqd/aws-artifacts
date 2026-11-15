{#
  Replaces dbt-duckdb's `table` materialization for this project.

  The stock one builds <model>__dbt_tmp, renames the old table to a backup and renames the
  new one into place, all in one transaction. On an Iceberg REST catalog (S3 Tables) that
  fails with:
    "Iceberg REST Catalog cannot commit this transaction atomically because it mixes
     table updates with rename/drop requests"

  So this drops the old table and runs CREATE TABLE AS directly, with no rename. Trade-off:
  the table is briefly missing while a model rebuilds, and a failed build leaves no previous
  version.
#}
{% materialization table, adapter="duckdb" %}
  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set existing_relation = load_cached_relation(this) -%}

  {{ run_hooks(pre_hooks) }}

  {% if existing_relation is not none %}
    {{ drop_relation_if_exists(existing_relation) }}
  {% endif %}

  {% call statement('main') -%}
    {{ create_table_as(False, target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}
  {% do persist_docs(target_relation, model) %}
  {{ adapter.commit() }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
