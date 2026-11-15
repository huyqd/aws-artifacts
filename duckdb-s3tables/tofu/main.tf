data "aws_caller_identity" "current" {}

resource "aws_s3tables_table_bucket" "this" {
  name = var.table_bucket_name
}

resource "aws_s3tables_namespace" "this" {
  namespace        = var.namespace
  table_bucket_arn = aws_s3tables_table_bucket.this.arn
}

# Least-privilege policy for the identity that runs DuckDB.
# Attach it to your user/role (e.g. `aws iam attach-user-policy`).
data "aws_iam_policy_document" "duckdb" {
  statement {
    sid    = "S3TablesCatalogAndData"
    effect = "Allow"
    actions = [
      "s3tables:GetTableBucket",
      "s3tables:ListNamespaces",
      "s3tables:GetNamespace",
      "s3tables:ListTables",
      "s3tables:CreateTable",
      "s3tables:DeleteTable",
      "s3tables:GetTable",
      "s3tables:GetTableMetadataLocation",
      "s3tables:UpdateTableMetadataLocation",
      "s3tables:GetTableData",
      "s3tables:PutTableData",
    ]
    resources = [
      aws_s3tables_table_bucket.this.arn,
      "${aws_s3tables_table_bucket.this.arn}/table/*",
    ]
  }
}

# Extra permissions for the Glue Iceberg REST endpoint (attach style C in the README).
data "aws_iam_policy_document" "duckdb_glue" {
  statement {
    sid    = "GlueS3TablesCatalog"
    effect = "Allow"
    actions = [
      "glue:GetCatalog",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:CreateTable",
      "glue:UpdateTable",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/${var.table_bucket_name}",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/s3tablescatalog/${var.table_bucket_name}/${var.namespace}",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/s3tablescatalog/${var.table_bucket_name}/${var.namespace}/*",
    ]
  }

  statement {
    sid       = "LakeFormationDataAccess"
    effect    = "Allow"
    actions   = ["lakeformation:GetDataAccess"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "duckdb_combined" {
  source_policy_documents = concat(
    [data.aws_iam_policy_document.duckdb.json],
    var.enable_glue_integration ? [data.aws_iam_policy_document.duckdb_glue.json] : [],
  )
}

resource "aws_iam_policy" "duckdb" {
  count       = var.create_iam_policy ? 1 : 0
  name        = "${var.table_bucket_name}-duckdb-access"
  description = "Allows DuckDB to use the ${var.table_bucket_name} S3 Tables bucket"
  policy      = data.aws_iam_policy_document.duckdb_combined.json
}
