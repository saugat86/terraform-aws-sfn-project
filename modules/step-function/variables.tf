# Global variable
variable "name" {
  description = "Name of the ECS cluster to create"
  type        = string
}

variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
}

variable "prefix" {
  description = "The prefix name of customer to be displayed in AWS console and resource"
  type        = string
}

variable "tags" {
  description = "Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys"
  type        = map(any)
  default     = {}
}

# Step function 
variable "type" {
  description = "Determines whether a Standard or Express state machine is created. The default is STANDARD. Valid Values: STANDARD | EXPRESS"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], upper(var.type))
    error_message = "Step Function type must be one of the following (STANDARD | EXPRESS)."
  }
}

variable "definition" {
  description = "The Amazon States Language definition of the Step Function"
  type        = string
}

variable "attach_policies_for_integrations" {
  description = "Whether to attach AWS Service policies to IAM role"
  type        = bool
  default     = true
}

variable "service_integrations" {
  description = "Map of AWS service integrations to allow in IAM role policy"
  type        = any
  default     = {}
}

variable "log_include_execution_data" {
  description = "(Optional) Determines whether execution data is included in your log. When set to false, data is excluded."
  type        = bool
  default     = null
}

variable "log_level" {
  description = "(Optional) Defines which category of execution history events are logged. Valid values: ALL, ERROR, FATAL, OFF"
  type        = string
  default     = "OFF"
}

# IAM Role
variable "is_create_role" {
  description = "Whether to create step function roles or not"
  type        = bool
  default     = true
}

variable "exists_role_arn" {
  description = "The exist role arn for step functions"
  type        = string
  default     = ""
}

variable "trusted_entities" {
  description = "Step Function additional trusted entities for assuming roles (trust relationship)"
  type        = list(string)
  default     = []
}

variable "additional_role_policy_arn" {
  description = "Map of policies ARNs to attach to the lambda"
  type        = map(string)
  default     = {}
}

# CloudWatch Log Group 

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

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. Leave this default if account_mode is hub. If account_mode is spoke, please provide centrailize kms key arn (hub)."
  type        = string
  default     = ""
}
