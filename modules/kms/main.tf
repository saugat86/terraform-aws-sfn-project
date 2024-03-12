resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    {
      Name  = local.alias_name
      Alias = local.alias_name
    },
    local.tags
  )
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_iam_policy_document" "admin_policy" {
  statement {
    sid = "Allow Admin" # Root user will have permissions to manage the CMK, but do not have permissions to use the CMK in cryptographic operations. - https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#cryptographic-operations
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "service_cryptography" {
  statement {
    sid = "Allow Cryptography"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = var.service_key_info.aws_service_names
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = var.service_key_info.caller_account_ids
    }
  }
  count = local.service_key_count
}

data "aws_iam_policy_document" "direct_cryptography" {
  statement {
    sid = "Allow Cryptography"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.direct_key_info.allow_access_from_principals
    }
  }
  count = 1 - local.service_key_count
}

data "aws_iam_policy_document" "kms_key_policy" {
  source_policy_documents   = local.service_key_count == 1 ? [data.aws_iam_policy_document.admin_policy.json, data.aws_iam_policy_document.service_cryptography[0].json] : [data.aws_iam_policy_document.admin_policy.json, data.aws_iam_policy_document.direct_cryptography[0].json]
  override_policy_documents = var.additional_policies
}
