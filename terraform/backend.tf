# Terraform Backend Configuration
#
# Uncomment and configure if using remote state storage.
# For initial setup, local state is fine.

# terraform {
#   backend "s3" {
#     bucket  = "aftrs-terraform-state"
#     key     = "vj-archive/terraform.tfstate"
#     region  = "ap-southeast-2"
#     profile = "aftrs"
#     encrypt = true
#   }
# }
