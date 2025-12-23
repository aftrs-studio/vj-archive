# UNRAID to S3 Migration Guide

Step-by-step guide for migrating the VJ video collection from UNRAID to AWS S3.

## Prerequisites

### 1. AWS Configuration

Ensure the `aftrs` profile is configured:

```bash
# Check existing profiles
aws configure list-profiles

# Configure if missing
aws configure --profile aftrs
# Enter: Access Key ID, Secret Access Key, Region (ap-southeast-2)
```

### 2. Install rclone

```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash

# Verify
rclone version
```

### 3. Configure rclone Remote

Create `~/.config/rclone/rclone.conf`:

```ini
[aftrs-vj-archive]
type = s3
provider = AWS
env_auth = false
access_key_id = YOUR_ACCESS_KEY
secret_access_key = YOUR_SECRET_KEY
region = ap-southeast-2
storage_class = INTELLIGENT_TIERING
```

Or use interactive setup:
```bash
rclone config
# n) New remote
# name> aftrs-vj-archive
# Storage> s3
# provider> AWS
# env_auth> false
# access_key_id> (enter key)
# secret_access_key> (enter secret)
# region> ap-southeast-2
# storage_class> INTELLIGENT_TIERING
```

## Migration Steps

### Phase 1: Inventory

Count files and calculate total size:

```bash
# On UNRAID, check total size
du -sh /mnt/user/vj-clips/
du -sh /mnt/user/vj-clips/*/

# Count files
find /mnt/user/vj-clips -type f | wc -l

# List by user directory
for d in /mnt/user/vj-clips/*/; do
  echo "$d: $(du -sh "$d" | cut -f1), $(find "$d" -type f | wc -l) files"
done
```

### Phase 2: Test Sync

Test with a small subset first:

```bash
# Dry run (shows what would be transferred)
rclone sync /mnt/user/vj-clips/mitch/test-pack aftrs-vj-archive:aftrs-vj-archive/mitch/test-pack \
  --dry-run \
  --progress

# If dry run looks good, do actual sync
rclone sync /mnt/user/vj-clips/mitch/test-pack aftrs-vj-archive:aftrs-vj-archive/mitch/test-pack \
  --progress
```

### Phase 3: Full Migration

Run the optimized sync script:

```bash
# Set environment
export AWS_PROFILE=aftrs

# Run migration (can take 24-72 hours for 40TB)
./scripts/sync-to-s3.sh /mnt/user/vj-clips

# Or manual command with all optimizations
rclone sync /mnt/user/vj-clips aftrs-vj-archive:aftrs-vj-archive \
  --transfers 10 \
  --s3-upload-concurrency 4 \
  --s3-chunk-size 100M \
  --s3-disable-checksum \
  --fast-list \
  --update \
  --use-server-modtime \
  --progress \
  --log-file=/var/log/vj-archive-migration.log
```

### Phase 4: Verification

Verify upload integrity:

```bash
# Compare file counts
LOCAL_COUNT=$(find /mnt/user/vj-clips -type f | wc -l)
S3_COUNT=$(rclone ls aftrs-vj-archive:aftrs-vj-archive --fast-list | wc -l)
echo "Local: $LOCAL_COUNT, S3: $S3_COUNT"

# Check specific directory
rclone check /mnt/user/vj-clips/mitch aftrs-vj-archive:aftrs-vj-archive/mitch

# List S3 contents
./scripts/list-archive.sh
```

## Handling Large Migrations

### Screen/tmux Session

Keep sync running if SSH disconnects:

```bash
# Start screen session
screen -S vj-migration

# Run sync
./scripts/sync-to-s3.sh /mnt/user/vj-clips

# Detach: Ctrl+A, D
# Reattach: screen -r vj-migration
```

### Resumable Sync

rclone sync is naturally resumable:

```bash
# If interrupted, just run again
rclone sync /mnt/user/vj-clips aftrs-vj-archive:aftrs-vj-archive \
  --update \
  --progress

# --update skips files already on destination
```

### Bandwidth Limiting

If network impact is concern:

```bash
rclone sync source dest \
  --bwlimit 50M    # Limit to 50 MB/s
  --bwlimit "08:00,10M 18:00,50M"  # Time-based limits
```

## Time Estimates

| Data Size | 100 Mbps | 500 Mbps | 1 Gbps |
|-----------|----------|----------|--------|
| 1 TB | ~24 hours | ~5 hours | ~2.5 hours |
| 10 TB | ~10 days | ~2 days | ~1 day |
| 40 TB | ~40 days | ~8 days | ~4 days |

**Note**: Actual speeds depend on UNRAID disk speed, network quality, and AWS region.

## Alternative: AWS Snowball

For faster initial migration, consider AWS Snowball:

1. **Request Snowball** from AWS Console
2. **Receive device** (3-5 business days)
3. **Copy data** locally to device
4. **Ship back** to AWS
5. **Data imported** to S3

| Aspect | rclone | Snowball |
|--------|--------|----------|
| Cost | Free (transfer only) | ~$300/device |
| Time to complete | 4-40 days | ~7-10 days |
| Network usage | High | None |
| Best for | Good internet | Poor internet, large data |

For 40TB, Snowball may be faster if upload speed is under 500 Mbps.

## Post-Migration

### 1. Set Up Regular Sync

Add to UNRAID cron for ongoing backup:

```bash
# Edit crontab
crontab -e

# Add daily sync at 2 AM
0 2 * * * /path/to/vj-archive/scripts/sync-to-s3.sh /mnt/user/vj-clips >> /var/log/vj-sync.log 2>&1
```

### 2. Verify Intelligent-Tiering

Check that lifecycle rules are working:

```bash
# After 30+ days, check storage classes
aws s3api list-objects-v2 \
  --bucket aftrs-vj-archive \
  --prefix mitch/ \
  --query 'Contents[].StorageClass' \
  --profile aftrs
```

### 3. Monitor Costs

Use AWS Cost Explorer or the cost report script:

```bash
./scripts/cost-report.sh
```

## Troubleshooting

### Sync Hangs on Large Files

Increase timeouts:
```bash
rclone sync source dest \
  --timeout 1h \
  --contimeout 60s
```

### Permission Denied Errors

Check IAM permissions include:
- `s3:PutObject`
- `s3:GetObject`
- `s3:ListBucket`
- `s3:DeleteObject`

### Rate Limiting (503 Slow Down)

Reduce concurrency:
```bash
rclone sync source dest \
  --transfers 4 \
  --s3-upload-concurrency 2
```

### Verify File Integrity

For critical content, enable checksums (slower):
```bash
rclone sync source dest \
  --checksum  # Compare MD5 hashes
```

## Rollback Plan

If migration fails, data remains on UNRAID:

1. **Stop sync**: Ctrl+C or kill process
2. **Check S3 state**: `./scripts/list-archive.sh`
3. **Delete partial uploads**: `aws s3 rm s3://aftrs-vj-archive --recursive --profile aftrs`
4. **Investigate cause** before retrying

**Important**: Never delete UNRAID source until S3 backup is verified!
