locals {
  prefix         = "${var.prefix}-${var.environment}-${var.bucket_name}"
  bucket_name    = var.centralize_hub ? "${local.prefix}-${data.aws_caller_identity.main.account_id}-${random_string.random_suffix.result}" : "${local.prefix}-${random_string.random_suffix.result}"
  length_key_arn = length(keys(var.kms_key_arn))

  find_kms_key_arn = var.is_use_kms_managed_key && local.length_key_arn == 0 ? module.bucket_kms_key[0].key_arn : null
  find_kms_key_id  = var.is_use_kms_managed_key && local.length_key_arn == 0 ? module.bucket_kms_key[0].key_id : null
  kms_key_arn      = local.length_key_arn != 0 ? values(var.kms_key_arn)[0] : local.find_kms_key_arn
  kms_key_id       = local.length_key_arn != 0 ? values(var.kms_key_arn)[0] : local.find_kms_key_id

  versioning_enabled = var.versioning_enabled ? "Enabled" : "Suspended"

  is_create_bucket_policy = var.is_enable_s3_hardening_policy == true || length(var.additional_bucket_polices) != 0 || (var.bucket_mode == "log" && length(var.source_s3_server_logs) > 0) ? 1 : 0

  tags = merge(
    {
      "Environment" = var.environment,
      "Terraform"   = "true"
    },
    var.tags
  )
}
