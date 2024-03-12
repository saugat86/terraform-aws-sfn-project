output "key_arn" {
  description = "KMS key arn"
  value       = join("", aws_kms_key.this[*].arn)
}

output "key_id" {
  description = "KMS key id"
  value       = join("", aws_kms_key.this[*].key_id)
}
