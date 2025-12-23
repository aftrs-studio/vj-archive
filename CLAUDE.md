# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VJ Archive manages 40TB+ of VJ video clips for Resolume Arena, stored in AWS S3 with Intelligent-Tiering for cost optimization. Videos are organized by person (mitch/, luke/) with underlying video pack directories.

## AWS Profile Constraints

**CRITICAL**: This project MUST use only these AWS profiles:
- `cr8` - Primary profile for cr8/aftrs infrastructure
- `aftrs` - Secondary profile for AFTRS Studio resources

**NEVER** use:
- `default` profile
- `dev` or `development` profiles
- Any work-related AWS profiles

### Enforcing Profile Usage

All scripts must set AWS_PROFILE explicitly:
```bash
export AWS_PROFILE=aftrs
aws s3 ls s3://aftrs-vj-archive/
```

Terraform must use profile:
```hcl
provider "aws" {
  region  = "ap-southeast-2"
  profile = "aftrs"
}
```

Rclone must use aftrs-vj-archive remote (not default S3):
```bash
rclone ls aftrs-vj-archive:aftrs-vj-archive/
```

## Common Commands

### Sync Operations
```bash
./scripts/sync-to-s3.sh /path/to/source        # Sync local to S3
./scripts/list-archive.sh                       # List S3 contents
./scripts/restore-files.sh path/in/bucket       # Restore from Glacier
./scripts/cost-report.sh                        # Get monthly cost estimate
```

### Terraform
```bash
cd terraform && terraform init    # Initialize
cd terraform && terraform plan    # Preview changes
cd terraform && terraform apply   # Apply changes (with approval)
```

## Architecture

- **Storage**: S3 Intelligent-Tiering with automatic tier transitions
  - Frequent Access: Hot data (most recent uploads)
  - Infrequent Access: After 30 days (40% savings)
  - Archive: After 90 days (68% savings)
  - Deep Archive: After 180 days (95% savings)

- **Transfer**: rclone with optimized settings for large video files
  - 10 parallel transfers
  - 100MB chunk size
  - Checksum disabled for speed
  - Server modtime for efficient sync

## Video Workflow

1. Source videos: MP4 format (1080p/4K)
2. Convert to DXV3: Use Resolume Alley (FFmpeg cannot encode DXV)
3. Store both formats: MP4 in archive, DXV3 for active use
4. Sync to S3: Regular backups via rclone

## File Structure

```
vj-archive/
├── docs/                    # Documentation for future LLMs
├── scripts/                 # Shell scripts for operations
├── terraform/               # AWS infrastructure as code
└── README.md
```

## Important Notes

- DXV3 is a proprietary Resolume codec - FFmpeg can decode but not encode
- Use Resolume Alley (free) for batch DXV3 encoding
- Glacier retrieval takes 12h (standard) to 48h (bulk)
- Data transfer OUT costs $0.09/GB - minimize downloads
