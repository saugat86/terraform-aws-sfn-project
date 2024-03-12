output "bucket_id" {
  description = "S3 Bucket Id"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "S3 Bucket Domain Name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.this.bucket
}

output "consumer_policies" {
  description = "S3 Bucket Consumer Policies name and ARN map"
  value = {
    for name, policy in aws_iam_policy.consumers : name => policy.arn
  }
}

output "consumer_readonly_policy" {
  description = "S3 Bucket Consumer Readonly Policy name and ARN map"
  value       = var.is_create_consumer_readonly_policy ? aws_iam_policy.consumers_readonly[0].arn : null
}

output "bucket_kms_key_id" {
  description = "S3 Bucket KMS Key ID"
  value       = var.is_use_kms_managed_key ? local.kms_key_id : null
}

output "bucket_kms_key_arn" {
  description = "S3 Bucket KMS Key ARN"
  value       = var.is_use_kms_managed_key ? local.kms_key_arn : null
}
