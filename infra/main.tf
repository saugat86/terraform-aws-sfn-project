module "lambda" {
  source = "../modules/lambda"

  prefix      = var.prefix
  environment = var.environment
  name        = var.name

  is_edge = false

  # Source code
  source_code_dir           = "./src"
  compressed_local_file_dir = "./outputs"

  # Lambda Env
  runtime = "python3.9"
  handler = "main.lambda_handler"

  # Resource policy
  lambda_permission_configurations = {}

  # Env
  ssm_params = {}

  tags = var.custom_tags
}

module "state_machine" {
  source = "../modules/step-function"

  prefix      = var.prefix
  environment = var.environment
  name        = var.name

  is_create_role             = true
  additional_role_policy_arn = {}

  type       = "STANDARD"
  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "LambdaInvoke",
  "States": {
    "LambdaInvoke": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda.function_arn}"
      },
      "Next": "CheckStatusCode"
    },
    "CheckStatusCode": {
      "Type": "Choice",
      "InputPath": "$",
      "Choices": [
        {
          "Variable": "$.statusCode",
          "NumericEquals": 500,
          "Next": "Wait"
        }
      ],
      "Default": "SuccessState"
    },
    "Wait": {
      "Type": "Wait",
      "OutputPath": "$.event",
      "Seconds": 10,
      "Next": "LambdaInvoke"
    },
    "SuccessState": {
      "Type": "Succeed"
    }
  }
}
EOF

  service_integrations = {
    lambda = {
      lambda = ["${module.lambda.function_arn}*"]
    }
  }

  is_create_cloudwatch_log_group = true
  log_include_execution_data     = null
  log_level                      = "ALL"

  tags = var.custom_tags
}
