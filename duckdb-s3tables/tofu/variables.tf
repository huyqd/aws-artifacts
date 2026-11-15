variable "region" {
  description = "AWS region for the S3 Tables bucket"
  type        = string
  default     = "eu-central-1"
}

variable "table_bucket_name" {
  description = "Name of the S3 table bucket (3-63 chars, lowercase, unique per account/region)"
  type        = string
  default     = "duckdb-s3tables-demo"
}

variable "namespace" {
  description = "Namespace (database) created in the table bucket"
  type        = string
  default     = "duckdb"
}

variable "create_iam_policy" {
  description = "Create a managed IAM policy granting DuckDB the S3 Tables access it needs"
  type        = bool
  default     = true
}

variable "enable_glue_integration" {
  description = <<-EOT
    Integrate S3 Tables with the Glue Data Catalog by creating the federated catalog
    `s3tablescatalog` (IAM access control mode). It is one per account and region and covers
    ALL table buckets there, so set this to false if it already exists.
  EOT
  type        = bool
  default     = true
}
