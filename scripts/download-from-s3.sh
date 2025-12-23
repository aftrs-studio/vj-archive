#!/bin/bash
# Download files from S3 to local storage
# Usage: ./download-from-s3.sh <s3-path> <local-destination> [--dry-run]
set -euo pipefail

S3_PATH="${1:-}"
LOCAL_DEST="${2:-}"
DRY_RUN="${3:-}"
BUCKET="aftrs-vj-archive"
REMOTE="aftrs-vj-archive:$BUCKET"

if [[ -z "$S3_PATH" || -z "$LOCAL_DEST" ]]; then
    echo "Usage: ./download-from-s3.sh <s3-path> <local-destination> [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  ./download-from-s3.sh mitch/pack1 /mnt/user/vj-clips/mitch/pack1"
    echo "  ./download-from-s3.sh luke/ ~/Downloads/luke-clips --dry-run"
    exit 1
fi

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

echo "VJ Archive Download"
echo "==================="
echo "Source: s3://$BUCKET/$S3_PATH"
echo "Destination: $LOCAL_DEST"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if source exists in S3
echo "Checking source path..."
FILE_COUNT=$(rclone ls "$REMOTE/$S3_PATH" --fast-list 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "ERROR: No files found at s3://$BUCKET/$S3_PATH"
    echo ""
    echo "Available paths:"
    rclone lsd "$REMOTE" --fast-list 2>/dev/null | awk '{print "  " $5}'
    exit 1
fi

echo "Found $FILE_COUNT files to download"
echo ""

# Calculate total size
echo "Calculating download size..."
rclone size "$REMOTE/$S3_PATH" --fast-list 2>/dev/null
echo ""

# Check for Glacier files
echo "Checking storage classes..."
GLACIER_COUNT=$(AWS_PROFILE=$AWS_PROFILE aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "$S3_PATH" \
    --query 'Contents[?StorageClass==`GLACIER` || StorageClass==`DEEP_ARCHIVE`].Key' \
    --output text 2>/dev/null | wc -w | tr -d ' ')

if [[ "$GLACIER_COUNT" -gt 0 ]]; then
    echo "WARNING: $GLACIER_COUNT files are in Glacier/Deep Archive"
    echo "These must be restored first using: ./restore-files.sh $S3_PATH"
    echo ""
    read -p "Continue with available files? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create destination directory
mkdir -p "$LOCAL_DEST"

# Build rclone command
RCLONE_CMD="rclone sync \"$REMOTE/$S3_PATH\" \"$LOCAL_DEST\" --transfers 10 --s3-chunk-size 100M --fast-list --progress"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    RCLONE_CMD="$RCLONE_CMD --dry-run"
    echo "DRY RUN: No files will be downloaded"
fi

echo ""
echo "Starting download..."
eval "$RCLONE_CMD"

echo ""
echo "Download complete!"
echo "Files saved to: $LOCAL_DEST"

# Show local file count
LOCAL_COUNT=$(find "$LOCAL_DEST" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Local file count: $LOCAL_COUNT"
