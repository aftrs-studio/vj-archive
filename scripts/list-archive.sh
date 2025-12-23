#!/bin/bash
# List contents of the VJ archive S3 bucket
# Usage: ./list-archive.sh [path] [--summary]
set -euo pipefail

PATH_PREFIX="${1:-}"
SUMMARY="${2:-}"
BUCKET="aftrs-vj-archive"

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

if [[ "$SUMMARY" == "--summary" ]]; then
    echo "VJ Archive Summary"
    echo "=================="
    echo ""
    echo "Top-level directories:"
    rclone lsd "aftrs-vj-archive:$BUCKET/$PATH_PREFIX" --fast-list 2>/dev/null | awk '{print "  " $5 " (" $3 " " $4 ")"}'
    echo ""
    echo "Total size:"
    rclone size "aftrs-vj-archive:$BUCKET/$PATH_PREFIX" --fast-list 2>/dev/null
else
    echo "Contents of s3://$BUCKET/$PATH_PREFIX"
    echo ""
    rclone ls "aftrs-vj-archive:$BUCKET/$PATH_PREFIX" --fast-list 2>/dev/null | head -100
    echo ""
    echo "(Showing first 100 files. Use --summary for overview)"
fi
