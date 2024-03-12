/* -------------------------------------------------------------------------- */
/*                                 S3 Logging                                 */
/* -------------------------------------------------------------------------- */
data "aws_s3_bucket" "source_bucket" {
  for_each = var.bucket_mode == "log" ? var.source_s3_server_logs : {}

  bucket = lookup(each.value, "bucket_name", null)
}

resource "aws_s3_bucket_logging" "this" {
  for_each = var.bucket_mode == "log" ? var.source_s3_server_logs : {}

  bucket = data.aws_s3_bucket.source_bucket[each.key].id

  target_bucket         = aws_s3_bucket.this.id
  target_prefix         = substr(lookup(each.value, "bucket_prefix", each.value.bucket_name), -1, -1) == "/" ? format("%s", lookup(each.value, "bucket_prefix", each.value.bucket_name)) : format("%s/", lookup(each.value, "bucket_prefix", each.value.bucket_name))
  expected_bucket_owner = lookup(each.value, "bucket_owner", null)
}

data "aws_iam_policy_document" "target_bucket_policy" {
  count = var.bucket_mode == "log" ? 1 : 0

  dynamic "statement" {
    for_each = var.source_s3_server_logs

    content {
      sid       = format("S3ServerAccessLogsPolicy-%s", replace(statement.key, "_", "-"))
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "Service"
        identifiers = ["logging.s3.amazonaws.com"]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = [data.aws_s3_bucket.source_bucket[statement.key].arn]
      }

      dynamic "condition" {
        for_each = lookup(statement.value, "expected_owner", null) == null ? [] : [true]

        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [lookup(condition.value, "expected_owner", null)]
        }
      }
    }
  }
}
