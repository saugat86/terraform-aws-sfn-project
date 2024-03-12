/* -------------------------------------------------------------------------- */
/*                                   Generic                                  */
/* -------------------------------------------------------------------------- */
variable "prefix" {
  description = "The prefix name of customer to be displayed in AWS console and resource"
  type        = string
}

variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
}

variable "name" {
  description = "Name of the ECS cluster to create"
  type        = string
}

variable "tags" {
  description = "Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys"
  type        = map(any)
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                                    Data                                    */
/* -------------------------------------------------------------------------- */
variable "archive_file_trigger" {
  description = "The map of string that will be used to determine trigger to do archive"
  type        = map(string)
  default     = {}
}

variable "compressed_local_file_dir" {
  description = "A path to the directory to store plan time generated local files"
  type        = string
  default     = ""
}

variable "source_code_dir" {
  description = "An absolute path to the directory containing the code to upload to lambda"
  type        = string
  default     = ""
}

/* -------------------------------------------------------------------------- */
/*                            Resource Based Policy                           */
/* -------------------------------------------------------------------------- */
variable "lambda_permission_configurations" {
  description = <<EOF
  principal  - (Required) The principal who is getting this permission e.g., s3.amazonaws.com, an AWS account ID, or any valid AWS service principal such as events.amazonaws.com or sns.amazonaws.com.
  source_arn - (Optional) When the principal is an AWS service, the ARN of the specific resource within that service to grant permission to. Without this, any resource from
  source_account - (Optional) This parameter is used for S3 and SES. The AWS account ID (without a hyphen) of the source owner.
  EOF
  type        = any
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                                     IAM                                    */
/* -------------------------------------------------------------------------- */
variable "is_create_lambda_role" {
  description = "Whether to create lamda role or not"
  type        = bool
  default     = true
}

variable "lambda_role_arn" {
  description = "The arn of role that already created by something to asso with lambda"
  type        = string
  default     = ""
}

variable "additional_lambda_role_policy_arns" {
  description = "List of policies ARNs to attach to the lambda's created role"
  type        = list(string)
  default     = []
}

/* -------------------------------------------------------------------------- */
/*                            S3 Lambda Source Code                           */
/* -------------------------------------------------------------------------- */
variable "is_create_lambda_bucket" {
  description = "Whether to create lambda bucket or not"
  type        = bool
  default     = false
}

variable "bucket_name" {
  description = "Name of the bucket to put the file in. Alternatively, an S3 access point ARN can be specified."
  type        = string
  default     = ""
}
/* -------------------------------------------------------------------------- */
/*                               Lambda Function                              */
/* -------------------------------------------------------------------------- */
variable "is_edge" {
  description = "Whether lambda is lambda@Edge or not"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "(Optional) Amount of time your Lambda Function has to run in seconds. Defaults to 3."
  type        = number
  default     = 3
}

variable "memory_size" {
  description = "(Optional) Amount of memory in MB your Lambda Function can use at runtime. Defaults to 128."
  type        = number
  default     = 128
}

variable "reserved_concurrent_executions" {
  description = "(Optional) Amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved Concurrency Limits -1. See Managing Concurrency"
  type        = number
  default     = -1
}

variable "layer_arns" {
  description = "(Optional) List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function."
  type        = list(string)
  default     = []
}

variable "vpc_config" {
  description = <<EOF
  For network connectivity to AWS resources in a VPC, specify a list of security groups and subnets in the VPC.
  When you connect a function to a VPC, it can only access resources and the internet through that VPC. See VPC Settings.

  security_group_ids - (Required) List of security group IDs associated with the Lambda function.
  subnet_ids_to_associate - (Required) List of subnet IDs associated with the Lambda function.
  EOF
  type = object({
    security_group_ids      = list(string)
    subnet_ids_to_associate = list(string)
  })
  default = {
    security_group_ids      = []
    subnet_ids_to_associate = []
  }
}

variable "dead_letter_target_arn" {
  description = "Dead letter queue configuration that specifies the queue or topic where Lambda sends asynchronous events when they fail processing."
  type        = string
  default     = null
}

variable "tracing_mode" {
  description = "Tracing mode of the Lambda Function. Valid value can be either PassThrough or Active."
  type        = string
  default     = "PassThrough"
  validation {
    condition     = contains(["PassThrough", "Active"], var.tracing_mode)
    error_message = "Valid values for account_mode are PassThrough and Active."
  }
}

variable "runtime" {
  description = "The runtime of the lambda function"
  type        = string
}

variable "handler" {
  description = "Function entrypoint in your code."
  type        = string
}

variable "environment_variables" {
  description = "A map that defines environment variables for the Lambda Function."
  type        = map(string)
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                            CloudWatch Log Group                            */
/* -------------------------------------------------------------------------- */
variable "is_create_cloudwatch_log_group" {
  description = "Whether to create cloudwatch log group or not"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_in_days" {
  description = "Retention day for cloudwatch log group"
  type        = number
  default     = 90
}

variable "is_create_default_kms" {
  description = "Whether to create cloudwatch log group kms or not"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_kms_key_arn" {
  description = "The ARN for the KMS encryption key."
  type        = string
  default     = null
}

variable "ssm_params" {
  description = <<EOF
  Lambda@Edge does not support env vars, so it is a common pattern to exchange Env vars for SSM params.
  ! SECRET

  you would have lookups in SSM, like:
  `const someEnvValue = await ssmClient.getParameter({ Name: 'SOME_SSM_PARAM_NAME', WithDecryption: true })`

  EOF
  type        = map(string)
  default     = {}
}
