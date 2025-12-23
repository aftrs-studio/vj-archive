# VJ Archive

AWS S3-based archive infrastructure for managing 40TB+ of VJ video clips (1080p/4K) for Resolume Arena.

## Overview

This repository manages the cloud storage infrastructure for the AFTRS Studio VJ video collection. Videos are organized by person, with source MP4 files converted to Resolume DXV3 codec for optimal VJing performance.

## Architecture

```
UNRAID Server (Source)          AWS S3 (Cloud Archive)
/mnt/user/vj-clips/             s3://aftrs-vj-archive/
├── mitch/                      ├── mitch/
│   ├── pack1/                  │   ├── pack1/
│   └── pack2/                  │   └── pack2/
└── luke/                       └── luke/
    └── pack1/                      └── pack1/
```

## Quick Start

### Prerequisites

- AWS CLI configured with `aftrs` or `cr8` profile
- rclone installed (`brew install rclone`)
- Terraform 1.0+ (`brew install terraform`)

### Sync to S3

```bash
# Set AWS profile (REQUIRED - never use default/dev profiles)
export AWS_PROFILE=aftrs

# Run sync script
./scripts/sync-to-s3.sh /mnt/user/vj-clips
```

### List Archive Contents

```bash
./scripts/list-archive.sh
```

### Restore from Glacier

```bash
./scripts/restore-files.sh mitch/pack1/
```

## Cost Estimates (40TB)

| Storage Tier | Monthly Cost |
|--------------|--------------|
| S3 Standard | ~$920 |
| Intelligent-Tiering (30d) | ~$500 |
| Deep Archive (180d) | ~$40 |

See [docs/COST-ANALYSIS.md](docs/COST-ANALYSIS.md) for detailed breakdown.

## Documentation

- [RESEARCH.md](docs/RESEARCH.md) - AWS/S3/rclone research for LLMs
- [DXV-WORKFLOW.md](docs/DXV-WORKFLOW.md) - DXV3 encoding guide
- [COST-ANALYSIS.md](docs/COST-ANALYSIS.md) - Detailed cost breakdown
- [MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) - UNRAID to S3 migration

## Infrastructure

Terraform manages:
- S3 bucket with Intelligent-Tiering
- IAM policies for restricted access
- Lifecycle rules for automatic archiving

```bash
cd terraform && terraform init && terraform plan
```

## License

MIT License - See [LICENSE](LICENSE)
