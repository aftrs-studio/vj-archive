#!/bin/bash
# Sync VJ clips from local/UNRAID to S3
# Usage: ./sync-to-s3.sh /path/to/source [--dry-run]
set -euo pipefail

SOURCE_PATH="${1:-/mnt/user/vj-clips}"
DRY_RUN="${2:-}"
BUCKET="aftrs-vj-archive"
REMOTE="aftrs-vj-archive:${BUCKET}"
LOG_FILE="/var/log/vj-archive-sync.log"

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

# Verify source exists
if [[ ! -d "$SOURCE_PATH" ]]; then
    echo "ERROR: Source path does not exist: $SOURCE_PATH" >&2
    exit 1
fi

# Build rclone command
RCLONE_CMD="rclone sync \"$SOURCE_PATH\" \"$REMOTE\" --transfers 10 --s3-upload-concurrency 4 --s3-chunk-size 100M --s3-disable-checksum --fast-list --update --use-server-modtime --progress --log-file=\"$LOG_FILE\""

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    RCLONE_CMD="$RCLONE_CMD --dry-run"
    echo "DRY RUN: No files will be transferred"
fi

echo "Starting sync: $SOURCE_PATH -> s3://$BUCKET"
echo "AWS Profile: $AWS_PROFILE"
echo "Log file: $LOG_FILE"
echo ""

eval "$RCLONE_CMD"

echo ""
echo "Sync complete. Check $LOG_FILE for details."
