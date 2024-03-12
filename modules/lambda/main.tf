# Global Local Variable
locals {
  name = format("%s-%s-%s", var.prefix, var.environment, var.name)

  lambda_role_arn = var.is_create_lambda_role ? aws_iam_role.this[0].arn : var.lambda_role_arn

  file_name         = var.is_edge ? null : data.archive_file.this.output_path
  bucket_name       = var.is_edge ? var.is_create_lambda_bucket ? module.s3[0].bucket_name : var.bucket_name : null
  object_key        = var.is_edge ? aws_s3_object.this[0].id : null
  object_version_id = var.is_edge ? aws_s3_object.this[0].version_id : null

  cloudwatch_log_group_kms_key_arn = var.cloudwatch_log_group_kms_key_arn != null ? var.cloudwatch_log_group_kms_key_arn : var.is_create_default_kms ? module.cloudwatch_log_group_kms[0].key_arn : null

  tags = merge(
    {
      "Environment" = var.environment,
      "Terraform"   = "true",
      "Module"      = "terraform-aws-lambda"
    },
    var.tags
  )
}



/* -------------------------------------------------------------------------- */
/*                                  Zip File                                  */
/* -------------------------------------------------------------------------- */
resource "null_resource" "lambda" {
  triggers = var.archive_file_trigger == {} ? {
    main = base64sha256(file("./${var.source_code_dir}/main.py"))
  } : var.archive_file_trigger
}

data "archive_file" "this" {
  depends_on = [null_resource.lambda]

  type        = "zip"
  source_dir  = var.source_code_dir
  output_path = format("%s/%s.zip", var.compressed_local_file_dir, local.name)
}

module "s3" {
  count = var.is_edge && var.is_create_lambda_bucket ? 1 : 0

  source = "../s3"

  prefix      = var.prefix
  environment = var.environment
  bucket_name = var.is_edge ? format("%s-lambda-edge-bucket", var.name) : format("%s-lambda-bucket", var.name)

  force_s3_destroy = true

  is_enable_s3_hardening_policy      = false
  is_create_consumer_readonly_policy = false

  tags = var.tags
}

resource "aws_s3_object" "this" {
  count = var.is_edge && var.is_create_lambda_bucket ? 1 : 0

  bucket = element(module.s3[*].bucket_name, 0)
  key    = format("%s.zip", local.name)
  source = data.archive_file.this.output_path
  etag   = data.archive_file.this.output_md5

  tags = merge(local.tags, { "Name" = format("%s.zip", local.name) })
}

/* -------------------------------------------------------------------------- */
/*                            Resource Based Policy                           */
/* -------------------------------------------------------------------------- */
resource "aws_lambda_permission" "allow_serivce" {
  for_each = var.lambda_permission_configurations

  statement_id   = format("AllowExecutionFrom-%s", each.key)
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = lookup(each.value, "principal", null)
  source_arn     = lookup(each.value, "source_arn", null)
  source_account = lookup(each.value, "source_account", null)
  # TODO Terraform aws says not support but doc support
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission#principal_org_id
  # principal_org_id = lookup(each.value, "principal_org_id", "")
}

/* -------------------------------------------------------------------------- */
/*                                  IAM Role                                  */
/* -------------------------------------------------------------------------- */
data "aws_iam_policy_document" "assume_role_policy_doc" {
  count = var.is_create_lambda_role ? 1 : 0

  statement {
    sid    = "AllowAwsToAssumeRole"
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = var.is_edge ? [
        "edgelambda.amazonaws.com",
        "lambda.amazonaws.com",
        ] : [
        "lambda.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda_logs_policy_doc" {
  count = var.is_create_lambda_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_access_vpc" {
  count = var.is_create_lambda_role ? 1 : 0

  # Allow to connect to VPC
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  count = var.is_create_lambda_role ? 1 : 0

  source_policy_documents = [
    data.aws_iam_policy_document.lambda_logs_policy_doc[0].json,
    data.aws_iam_policy_document.lambda_access_vpc[0].json
  ]
}

resource "aws_iam_role" "this" {
  count = var.is_create_lambda_role ? 1 : 0

  name               = format("%s-function-role", local.name)
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_doc[0].json

  tags = merge(local.tags, { "Name" : format("%s-function-role", local.name) })
}

resource "aws_iam_role_policy" "logs_role_policy" {
  count = var.is_create_lambda_role ? 1 : 0

  name   = var.is_edge ? format("%s-lambda-at-edge-log-access-policy", local.name) : format("%s-lambda-log-access-policy", local.name)
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.lambda_policy[0].json
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.is_create_lambda_role ? length(var.additional_lambda_role_policy_arns) : 0

  role       = aws_iam_role.this[0].name
  policy_arn = var.additional_lambda_role_policy_arns[count.index]
}

/* -------------------------------------------------------------------------- */
/*                                     SSM                                    */
/* -------------------------------------------------------------------------- */
# TODO; migrate to SSM
resource "aws_ssm_parameter" "params" {
  for_each = var.ssm_params

  description = format("param %s for the lambda function %s", each.key, local.name)

  name  = each.key
  value = each.value

  type = "SecureString"
  tier = length(each.value) > 4096 ? "Advanced" : "Standard"

  tags = local.tags
}

data "aws_iam_policy_document" "secret_access_policy_doc" {
  count = var.is_create_lambda_role && length(var.ssm_params) > 0 ? 1 : 0

  statement {
    sid    = "AccessParams"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      for name, outputs in aws_ssm_parameter.params :
      outputs.arn
    ]
  }
}

resource "aws_iam_policy" "ssm_policy" {
  count = var.is_create_lambda_role && length(var.ssm_params) > 0 ? 1 : 0

  name        = format("%s-ssm-policy", local.name)
  description = format("Gives the lambda %s access to params from SSM", local.name)
  policy      = data.aws_iam_policy_document.secret_access_policy_doc[0].json
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  count = var.is_create_lambda_role && length(var.ssm_params) > 0 ? 1 : 0

  role       = aws_iam_role.this[0].id
  policy_arn = aws_iam_policy.ssm_policy[0].arn
}

/* -------------------------------------------------------------------------- */
/*                               Lambda Function                              */
/* -------------------------------------------------------------------------- */
resource "aws_lambda_function" "this" {
  function_name = format("%s-function", local.name)
  description   = format("Lambda function: %s", local.name)

  # Read source code from s3
  s3_bucket         = local.bucket_name
  s3_key            = local.object_key
  s3_object_version = local.object_version_id

  # Read source code from local
  filename         = local.file_name
  source_code_hash = data.archive_file.this.output_base64sha256

  # Specification
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions
  layers                         = var.layer_arns

  # Code Env
  publish = true # Force public new version
  runtime = var.runtime
  handler = var.handler

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) == 0 ? [] : [true]
    content {
      variables = var.environment_variables
    }
  }

  role = local.lambda_role_arn

  vpc_config {
    security_group_ids = var.vpc_config.security_group_ids
    subnet_ids         = var.vpc_config.subnet_ids_to_associate
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn == null ? [] : [true]

    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [true]
    content {
      mode = var.tracing_mode
    }
  }

  tags = merge(local.tags, { "Name" = format("%s-function", local.name) })
}

/* -------------------------------------------------------------------------- */
/*                            CloudWatch Log Group                            */
/* -------------------------------------------------------------------------- */
data "aws_iam_policy_document" "cloudwatch_log_group_kms_policy" {
  statement {
    sid = "AllowCloudWatchToDoCryptography"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = tolist([format("logs.%s.amazonaws.com", data.aws_region.this.name)])
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [format("arn:aws:logs:%s:%s:log-group:%s", data.aws_region.this.name, data.aws_caller_identity.this.account_id, format("/aws/lambda/%s-function", local.name))]
    }
  }
}

module "cloudwatch_log_group_kms" {
  count  = var.is_create_cloudwatch_log_group && var.is_create_default_kms && var.cloudwatch_log_group_kms_key_arn == null ? 1 : 0
  source = "../kms"

  prefix               = var.prefix
  environment          = var.environment
  name                 = format("%s-function-log-group", var.name)
  key_type             = "service"
  append_random_suffix = true
  description          = format("Secure Secrets Manager's service secrets for service %s", local.name)
  additional_policies  = [data.aws_iam_policy_document.cloudwatch_log_group_kms_policy.json]

  tags = merge(local.tags, { "Name" : format("%s-function-log-group", var.name) })
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.is_create_cloudwatch_log_group ? 1 : 0

  name              = format("/aws/lambda/%s-function", local.name)
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = local.cloudwatch_log_group_kms_key_arn

  tags = merge(local.tags, { "Name" = format("/aws/lambda/%s-function", local.name) })
}
