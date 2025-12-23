#!/bin/bash
# Generate detailed storage report by directory
# Usage: ./storage-report.sh [path]
set -euo pipefail

PATH_PREFIX="${1:-}"
BUCKET="aftrs-vj-archive"
REMOTE="aftrs-vj-archive:$BUCKET"

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

echo "VJ Archive Storage Report"
echo "========================="
echo "Bucket: s3://$BUCKET"
echo "AWS Profile: $AWS_PROFILE"
echo "Generated: $(date)"
echo ""

# Overall stats
echo "## Overall Statistics"
echo ""
rclone size "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null
echo ""

# Directory breakdown
echo "## Directory Breakdown"
echo ""
printf "%-40s %15s %10s\n" "Directory" "Size" "Files"
printf "%-40s %15s %10s\n" "----------------------------------------" "---------------" "----------"

# Get top-level directories
DIRS=$(rclone lsd "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null | awk '{print $5}')

for DIR in $DIRS; do
    FULL_PATH="$PATH_PREFIX$DIR"
    SIZE_OUTPUT=$(rclone size "$REMOTE/$FULL_PATH" --fast-list 2>/dev/null)
    SIZE=$(echo "$SIZE_OUTPUT" | grep "Total size:" | awk '{print $3 " " $4}')
    COUNT=$(echo "$SIZE_OUTPUT" | grep "Total objects:" | awk '{print $3}')
    printf "%-40s %15s %10s\n" "$DIR/" "${SIZE:-0}" "${COUNT:-0}"
done

echo ""

# Storage class breakdown
echo "## Storage Class Distribution"
echo ""

# Use AWS CLI for accurate storage class info
AWS_PROFILE=$AWS_PROFILE aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "$PATH_PREFIX" \
    --query 'Contents[].StorageClass' \
    --output text 2>/dev/null | tr '\t' '\n' | sort | uniq -c | while read COUNT CLASS; do
    printf "  %-25s %10s files\n" "$CLASS" "$COUNT"
done

echo ""

# File type breakdown
echo "## File Types"
echo ""
rclone ls "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null | awk -F'.' '{print $NF}' | sort | uniq -c | sort -rn | head -10 | while read COUNT EXT; do
    printf "  .%-10s %10s files\n" "$EXT" "$COUNT"
done

echo ""

# Largest files
echo "## Largest Files (Top 10)"
echo ""
rclone ls "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null | sort -rn | head -10 | while read SIZE FILE; do
    SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)
    printf "  %10.2f MB  %s\n" "$SIZE_MB" "$FILE"
done

echo ""

# Recent activity (newest files)
echo "## Recently Modified (Top 10)"
echo ""
rclone lsl "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null | sort -k2,3 -r | head -10 | while read SIZE DATE TIME FILE; do
    printf "  %s %s  %s\n" "$DATE" "$TIME" "$FILE"
done

echo ""
echo "Report complete."
