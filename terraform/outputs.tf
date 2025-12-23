output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.vj_archive.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.vj_archive.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.vj_archive.region
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.vj_archive.bucket_domain_name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for bucket access"
  value       = aws_iam_policy.vj_archive_access.arn
}

output "rclone_config" {
  description = "Rclone configuration snippet"
  value       = <<-EOT
    [aftrs-vj-archive]
    type = s3
    provider = AWS
    env_auth = false
    region = ${var.aws_region}
    storage_class = INTELLIGENT_TIERING
    # Add access_key_id and secret_access_key from your aftrs profile
  EOT
}
