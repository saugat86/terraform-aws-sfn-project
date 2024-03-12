/* -------------------------------------------------------------------------- */
/*                                  S3 Bucket                                 */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  force_destroy = var.force_s3_destroy

  tags = merge({ Name = local.bucket_name }, local.tags)
}

/* -------------------------------------------------------------------------- */
/*                           S3 Block Public Access                           */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

/* -------------------------------------------------------------------------- */
/*                            S3 OwnerShip Controll                           */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.is_control_object_ownership ? 1 : 0

  bucket = local.is_create_bucket_policy == 1 ? aws_s3_bucket_policy.this[0].id : aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket.this
  ]
}

/* -------------------------------------------------------------------------- */
/*                                S3 Bucket ACL                               */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_acl" "this" {
  count = var.object_ownership == "BucketOwnerEnforced" ? 0 : 1

  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

/* -------------------------------------------------------------------------- */
/*                            S3 Bucket Versioning                            */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = local.versioning_enabled
  }
}

/* -------------------------------------------------------------------------- */
/*                      S3 Bucket Lifecycle Configuration                     */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) != 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      filter {
        prefix = ""
      }

      dynamic "transition" {
        for_each = lookup(rule.value, "transition", [])
        content {
          days          = lookup(transition.value, "days", null)
          storage_class = lookup(transition.value, "storage_class", null)
        }
      }

      expiration {
        days = rule.value.expiration_days
      }
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                     S3 Bucket Oject lock Configuration                     */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.object_lock_rule != null ? 1 : 0
  bucket = aws_s3_bucket.this.bucket

  object_lock_enabled = "Enabled"

  rule {
    default_retention {
      mode  = var.object_lock_rule.mode
      days  = var.object_lock_rule.days
      years = var.object_lock_rule.years
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                         S3 Bucket SSE Configuration                        */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.is_use_kms_managed_key ? local.kms_key_arn : null
      sse_algorithm     = var.is_use_kms_managed_key ? "aws:kms" : "AES256"
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                        S3 Bucket CORS Configuration                        */
/* -------------------------------------------------------------------------- */
resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rule) != 0 ? 1 : 0
  bucket = aws_s3_bucket.this.bucket

  dynamic "cors_rule" {
    for_each = var.cors_rule
    content {
      id              = lookup(cors_rule.value, "id", null)
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = lookup(cors_rule.value, "allowed_methods", null)
      allowed_origins = lookup(cors_rule.value, "allowed_origins", null)
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                                   RANDOM                                   */
/* -------------------------------------------------------------------------- */
resource "random_string" "random_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}
