output "table_bucket_arn" {
  description = "ARN to pass to DuckDB ATTACH"
  value       = aws_s3tables_table_bucket.this.arn
}

output "namespace" {
  value = aws_s3tables_namespace.this.namespace
}

output "region" {
  value = var.region
}

output "iam_policy_arn" {
  value = var.create_iam_policy ? aws_iam_policy.duckdb[0].arn : null
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "glue_warehouse" {
  description = "Warehouse string for ATTACH via the Glue Iceberg REST endpoint"
  value       = var.enable_glue_integration ? "${data.aws_caller_identity.current.account_id}:s3tablescatalog/${aws_s3tables_table_bucket.this.name}" : null
}
