#!/bin/bash
# Restore files from Glacier/Deep Archive tiers
# Usage: ./restore-files.sh <path> [--expedited|--standard|--bulk]
set -euo pipefail

RESTORE_PATH="${1:-}"
TIER="${2:---standard}"
BUCKET="aftrs-vj-archive"

if [[ -z "$RESTORE_PATH" ]]; then
    echo "Usage: ./restore-files.sh <path-in-bucket> [--expedited|--standard|--bulk]"
    echo ""
    echo "Examples:"
    echo "  ./restore-files.sh mitch/pack1/           # Restore directory (standard)"
    echo "  ./restore-files.sh mitch/pack1/video.mp4  # Restore single file"
    echo "  ./restore-files.sh luke/ --bulk           # Bulk restore (cheapest, 48h)"
    exit 1
fi

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

# Map tier flag to AWS tier name
case "$TIER" in
    --expedited) AWS_TIER="Expedited" ;;
    --standard)  AWS_TIER="Standard" ;;
    --bulk)      AWS_TIER="Bulk" ;;
    *)           AWS_TIER="Standard" ;;
esac

echo "Restoring from Glacier: s3://$BUCKET/$RESTORE_PATH"
echo "Retrieval tier: $AWS_TIER"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# List objects to restore
OBJECTS=$(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "$RESTORE_PATH" --query 'Contents[?StorageClass==`GLACIER` || StorageClass==`DEEP_ARCHIVE`].Key' --output text --profile "$AWS_PROFILE" 2>/dev/null || echo "")

if [[ -z "$OBJECTS" || "$OBJECTS" == "None" ]]; then
    echo "No Glacier/Deep Archive objects found at this path."
    echo "Objects may already be in accessible tiers."
    exit 0
fi

COUNT=$(echo "$OBJECTS" | wc -w | tr -d ' ')
echo "Found $COUNT objects in Glacier/Deep Archive"
echo ""

# Restore each object
for KEY in $OBJECTS; do
    echo "Restoring: $KEY"
    aws s3api restore-object --bucket "$BUCKET" --key "$KEY" --restore-request "{\"Days\":7,\"GlacierJobParameters\":{\"Tier\":\"$AWS_TIER\"}}" --profile "$AWS_PROFILE" 2>/dev/null || echo "  (already restoring or restored)"
done

echo ""
echo "Restore initiated. Time estimates:"
echo "  Expedited: 1-5 minutes"
echo "  Standard:  3-5 hours (Archive) / 12 hours (Deep Archive)"
echo "  Bulk:      5-12 hours (Archive) / 48 hours (Deep Archive)"
echo ""
echo "Check status with: aws s3api head-object --bucket $BUCKET --key <file> --profile $AWS_PROFILE"
