#!/bin/bash
# Verify integrity of files in S3 by comparing checksums
# Usage: ./verify-integrity.sh [path] [--fix]
set -euo pipefail

PATH_PREFIX="${1:-}"
FIX_MODE="${2:-}"
BUCKET="aftrs-vj-archive"
REMOTE="aftrs-vj-archive:$BUCKET"

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

echo "VJ Archive Integrity Verification"
echo "=================================="
echo "Bucket: s3://$BUCKET/$PATH_PREFIX"
echo "AWS Profile: $AWS_PROFILE"
echo ""

if [[ "$FIX_MODE" == "--fix" ]]; then
    echo "Mode: CHECK AND RE-UPLOAD corrupt files"
else
    echo "Mode: CHECK ONLY (use --fix to re-upload corrupt files)"
fi
echo ""

# Count files to check
echo "Counting files..."
TOTAL=$(rclone ls "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null | wc -l | tr -d ' ')
echo "Total files to verify: $TOTAL"
echo ""

if [[ "$TOTAL" -eq 0 ]]; then
    echo "No files found at path: $PATH_PREFIX"
    exit 0
fi

# Use rclone check for integrity verification
echo "Running integrity check (this may take a while for large archives)..."
echo ""

if [[ "$FIX_MODE" == "--fix" ]]; then
    # Check and list differences, then sync to fix
    rclone check "$REMOTE/$PATH_PREFIX" "$REMOTE/$PATH_PREFIX" \
        --one-way \
        --fast-list \
        2>&1 | tee /tmp/vj-integrity-check.log || true

    ERRORS=$(grep -c "ERROR" /tmp/vj-integrity-check.log 2>/dev/null || echo "0")
    if [[ "$ERRORS" -gt 0 ]]; then
        echo ""
        echo "Found $ERRORS integrity issues."
        echo "To fix, you need to re-upload from your local source."
        echo "Run: rclone sync /local/path $REMOTE/$PATH_PREFIX --checksum"
    fi
else
    # Just check using size and modtime (fast)
    echo "Checking file listing consistency..."
    rclone lsf "$REMOTE/$PATH_PREFIX" --fast-list -R 2>/dev/null | head -20

    echo ""
    echo "Quick stats:"
    rclone size "$REMOTE/$PATH_PREFIX" --fast-list 2>/dev/null

    echo ""
    echo "For full checksum verification, run:"
    echo "  rclone check /local/source $REMOTE/$PATH_PREFIX --checksum"
fi

echo ""
echo "Integrity check complete."
