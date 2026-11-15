{#
  Drops the table of every model in this project:
    uv run dbt run-operation drop_models --profiles-dir .
  Add `--args '{dry_run: true}'` to only print what would be dropped.

  Plain DROP TABLE with a commit after each one, because DuckDB-Iceberg rejects CASCADE and
  mixing drops into one transaction (see table_no_rename.sql).
#}
{% macro drop_models(dry_run=false) %}
  {% for node in graph.nodes.values() if node.resource_type == 'model' %}
    {% set relation = api.Relation.create(
        database=node.database, schema=node.schema, identifier=node.alias) %}
    {{ log((('[dry run] ' if dry_run else '') ~ 'drop table if exists ' ~ relation), info=true) }}
    {% if not dry_run %}
      {% do run_query('drop table if exists ' ~ relation) %}
      {% do adapter.commit() %}
    {% endif %}
  {% endfor %}
{% endmacro %}
