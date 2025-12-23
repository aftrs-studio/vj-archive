variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS profile to use (MUST be 'aftrs' or 'cr8')"
  type        = string
  default     = "aftrs"

  validation {
    condition     = contains(["aftrs", "cr8"], var.aws_profile)
    error_message = "AWS profile must be 'aftrs' or 'cr8'. Never use default/dev profiles."
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket for VJ archive"
  type        = string
  default     = "aftrs-vj-archive"
}

variable "create_iam_user" {
  description = "Whether to create a dedicated IAM user for rclone sync"
  type        = bool
  default     = false
}
