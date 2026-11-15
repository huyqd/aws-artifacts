# Integrates S3 table buckets with the Glue Data Catalog / AWS analytics services.
# Equivalent to `aws glue create-catalog` with the s3tablescatalog catalog.json.
# One s3tablescatalog exists per account+region and covers every table bucket in it.
resource "aws_glue_catalog" "s3tables" {
  count = var.enable_glue_integration ? 1 : 0

  name                                  = "s3tablescatalog"
  allow_full_table_external_data_access = "True"

  federated_catalog {
    identifier      = "arn:aws:s3tables:${var.region}:${data.aws_caller_identity.current.account_id}:bucket/*"
    connection_name = "aws:s3tables"
  }

  # IAM access control mode: IAM policies decide access, no Lake Formation grants needed.
  create_database_default_permissions {
    permissions = ["ALL"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }

  create_table_default_permissions {
    permissions = ["ALL"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }
}
