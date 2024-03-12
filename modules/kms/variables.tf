/* -------------------------------------------------------------------------- */
/*                                  GENERICS                                  */
/* -------------------------------------------------------------------------- */
variable "prefix" {
  description = "The prefix name of customer to be displayed in AWS console and resource."
  type        = string
}

variable "name" {
  description = "Name used as a resources name."
  type        = string
}

variable "environment" {
  description = "Environment name used as environment resources name."
  type        = string
}

variable "description" {
  description = "The description to give to the key"
  type        = string
}

variable "tags" {
  description = "Tags to add more; default tags contian {terraform=true, environment=var.environment}"
  type        = map(string)
  default     = {}
}

/* -------------------------------------------------------------------------- */
/*                                       KMS                                  */
/* -------------------------------------------------------------------------- */

variable "key_type" {
  description = "Indicate which kind of key to create: 'service' for key used by services; 'direct' for other keys. Must provide service_key or direct_key maps depending on the type"
  type        = string
}

variable "append_random_suffix" {
  description = "Append a random string to the alias name. Default: true (yes)"
  type        = bool
  default     = true
}

variable "deletion_window" {
  description = "Number of days before a key actually gets deleted once it's been scheduled for deletion. Valid value between 7 and 30 days"
  type        = number
  default     = 30
}

variable "service_key_info" {
  description = "Information required for a 'service' key"
  type = object({
    # List of AWS service names for the kms:ViaService policy condition
    aws_service_names = list(string)
    # List of caller account IDs for the kms:CallerAccount policy condition
    caller_account_ids = list(string)
  })
  default = {
    aws_service_names  = []
    caller_account_ids = []
  }
}

variable "direct_key_info" {
  description = "Information required for a 'direct' key"
  type = object({
    # List of principals to allow for cryptographic use of key.
    allow_access_from_principals = list(string)
  })
  default = {
    allow_access_from_principals = []
  }
}

variable "additional_policies" {
  description = "Additional IAM policies block, input as data source. Ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document"
  type        = list(string)
  default     = []
}
