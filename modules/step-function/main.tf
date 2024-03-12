data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

# Step Function   
resource "aws_sfn_state_machine" "this" {

  name     = format("%s-sfn", local.name)
  type     = upper(var.type)
  role_arn = local.role_arn

  definition = var.definition

  dynamic "logging_configuration" {
    for_each = var.is_create_cloudwatch_log_group ? [true] : []

    content {
      log_destination        = try("${aws_cloudwatch_log_group.this[0].arn}:*", null)
      include_execution_data = var.log_include_execution_data
      level                  = var.log_level
    }
  }

  dynamic "tracing_configuration" {
    for_each = local.enable_xray_tracing ? [true] : []
    content {
      enabled = true
    }
  }

  tags = merge(local.tags, { Name = format("%s-sfn", local.name) })
}

# IAM Role Log policy
data "aws_iam_policy_document" "log_access_policy" {
  count = var.is_create_role && var.is_create_cloudwatch_log_group ? 1 : 0

  statement {
    sid = "AllowStepFunctionToUseLog"

    effect = "Allow"

    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "log_access_policy" {
  count = var.is_create_role && var.is_create_cloudwatch_log_group ? 1 : 0

  name   = format("%s-log-access-policy", local.name)
  policy = data.aws_iam_policy_document.log_access_policy[0].json

  tags = merge(local.tags, { "Name" = format("%s-log-access-policy", local.name) })
}

# Service Policies
data "aws_iam_policy_document" "service" {
  for_each = { for k, v in var.service_integrations : k => v if var.is_create_role && var.attach_policies_for_integrations }

  dynamic "statement" {
    for_each = each.value

    content {
      effect    = lookup(local.aws_service_policies[each.key][statement.key], "effect", "Allow")
      sid       = replace("${each.key}${title(statement.key)}", "/[^0-9A-Za-z]*/", "")
      actions   = local.aws_service_policies[each.key][statement.key]["actions"]
      resources = statement.value == true ? local.aws_service_policies[each.key][statement.key]["default_resources"] : tolist(statement.value)

      dynamic "condition" {
        for_each = lookup(local.aws_service_policies[each.key][statement.key], "condition", [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_policy" "service" {
  for_each = { for k, v in var.service_integrations : k => v if var.is_create_role && var.attach_policies_for_integrations }

  name   = format("%s-%s-policy", local.name, each.key)
  policy = data.aws_iam_policy_document.service[each.key].json

  tags = merge(local.tags, { "Name" = format("%s-%s-policy", local.name, each.key) })
}

/* --------------------------- Asumme Role Policy --------------------------- */
data "aws_iam_policy_document" "assume_role" {
  count = var.is_create_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = distinct(concat(["states.${data.aws_region.this.name}.amazonaws.com"], var.trusted_entities))
    }
  }
}

# IAM Role 

resource "aws_iam_role" "this" {
  count = var.is_create_role ? 1 : 0

  name               = format("%s-step-functions-role", local.name)
  description        = "Role for step functions"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json

  tags = merge(local.tags, { "Name" = format("%s-step-functions-role", local.name) })
}

# IAM Policy Attachment
resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.is_create_role ? var.additional_role_policy_arn : {}

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "log_acces" {
  count = var.is_create_role && var.is_create_cloudwatch_log_group ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.log_access_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "service" {
  for_each = { for k, v in var.service_integrations : k => v if var.is_create_role && var.attach_policies_for_integrations }

  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.service[each.key].arn
}

# CloudWatch Log Group   

resource "aws_cloudwatch_log_group" "this" {
  count = var.is_create_cloudwatch_log_group ? 1 : 0

  name              = format("/aws/vendedlogs/states/%s-log-group", local.name)
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = var.kms_key_id

  tags = merge(local.tags, { "Name" = format("/aws/vendedlogs/states/%s-log-group", local.name) })
}
