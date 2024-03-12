data "aws_caller_identity" "current" {}

locals {
  service_key_count = var.key_type == "service" ? 1 : 0

  identifier = format("%s-%s-%s-kms", var.prefix, var.environment, var.name)
  alias_name = "${local.identifier}${var.append_random_suffix ? "-${random_string.random_suffix.result}" : ""}"

  tags = merge(
    {
      Terraform   = true
      Environment = var.environment
    },
    var.tags
  )
}
