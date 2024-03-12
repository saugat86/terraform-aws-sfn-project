# Create Consumer policies with provided action items
data "aws_iam_policy_document" "consumers" {
  for_each  = var.consumer_policy_actions
  policy_id = replace(each.key, "/[^a-zA-Z0-9]/", "")
  statement {
    effect  = "Allow"
    sid     = replace(each.key, "/[^a-zA-Z0-9]/", "")
    actions = each.value
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "consumers" {
  for_each = var.consumer_policy_actions
  name     = "${local.prefix}-${each.key}-${data.aws_region.active.name}-policy"
  policy   = data.aws_iam_policy_document.consumers[each.key].json

  tags = merge({ Name = "${local.prefix}-${each.key}-${data.aws_region.active.name}-policy" }, local.tags)
}

# Create Consumer Readonly policies with read-only permission to single bucket.
data "aws_iam_policy_document" "consumers_readonly" {
  count     = var.is_create_consumer_readonly_policy ? 1 : 0
  policy_id = "BucketReadonly"
  statement {
    sid    = "BucketReadonly"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "consumers_readonly" {
  count  = var.is_create_consumer_readonly_policy ? 1 : 0
  name   = "${local.prefix}-BucketReadonly-${data.aws_region.active.name}-policy"
  policy = data.aws_iam_policy_document.consumers_readonly[0].json

  tags = merge({ Name = "${local.prefix}-BucketReadonly-${data.aws_region.active.name}-policy" }, local.tags)
}
