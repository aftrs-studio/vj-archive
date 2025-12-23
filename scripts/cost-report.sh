#!/bin/bash
# Generate cost estimate for VJ archive storage
# Usage: ./cost-report.sh
set -euo pipefail

BUCKET="aftrs-vj-archive"

# CRITICAL: Ensure correct AWS profile
export AWS_PROFILE="${AWS_PROFILE:-aftrs}"
if [[ "$AWS_PROFILE" != "aftrs" && "$AWS_PROFILE" != "cr8" ]]; then
    echo "ERROR: AWS_PROFILE must be 'aftrs' or 'cr8', not '$AWS_PROFILE'" >&2
    exit 1
fi

echo "VJ Archive Cost Report"
echo "======================"
echo "Bucket: s3://$BUCKET"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Get bucket size using rclone
echo "Calculating storage size..."
SIZE_OUTPUT=$(rclone size "aftrs-vj-archive:$BUCKET" --fast-list 2>/dev/null)
TOTAL_SIZE=$(echo "$SIZE_OUTPUT" | grep "Total size:" | awk '{print $3}')
TOTAL_OBJECTS=$(echo "$SIZE_OUTPUT" | grep "Total objects:" | awk '{print $3}')

echo "Total Size: $TOTAL_SIZE"
echo "Total Objects: $TOTAL_OBJECTS"
echo ""

# Parse size to GB for calculations
SIZE_GB=$(echo "$SIZE_OUTPUT" | grep "Total size:" | awk '{
    size = $3;
    unit = $4;
    if (unit ~ /TiB/) size = size * 1024;
    else if (unit ~ /MiB/) size = size / 1024;
    else if (unit ~ /KiB/) size = size / 1024 / 1024;
    printf "%.0f", size
}')

if [[ -z "$SIZE_GB" || "$SIZE_GB" == "0" ]]; then
    echo "Unable to calculate costs (bucket may be empty)"
    exit 0
fi

echo "Estimated Monthly Costs"
echo "-----------------------"
echo ""

# S3 pricing (ap-southeast-2)
S3_STANDARD=0.025
S3_IA=0.0125
S3_GLACIER_IR=0.004
S3_ARCHIVE=0.0036
S3_DEEP=0.00099

# Calculate costs for different scenarios
COST_STANDARD=$(echo "$SIZE_GB * $S3_STANDARD" | bc)
COST_IA=$(echo "$SIZE_GB * $S3_IA" | bc)
COST_GLACIER_IR=$(echo "$SIZE_GB * $S3_GLACIER_IR" | bc)
COST_ARCHIVE=$(echo "$SIZE_GB * $S3_ARCHIVE" | bc)
COST_DEEP=$(echo "$SIZE_GB * $S3_DEEP" | bc)

printf "If all S3 Standard:        \$%.2f/month\n" "$COST_STANDARD"
printf "If all Infrequent Access:  \$%.2f/month\n" "$COST_IA"
printf "If all Glacier IR:         \$%.2f/month\n" "$COST_GLACIER_IR"
printf "If all Archive Access:     \$%.2f/month\n" "$COST_ARCHIVE"
printf "If all Deep Archive:       \$%.2f/month\n" "$COST_DEEP"
echo ""

# Estimate for Intelligent-Tiering (mixed)
COST_IT=$(echo "($SIZE_GB * 0.1 * $S3_STANDARD) + ($SIZE_GB * 0.3 * $S3_IA) + ($SIZE_GB * 0.4 * $S3_GLACIER_IR) + ($SIZE_GB * 0.2 * $S3_DEEP)" | bc)
printf "Intelligent-Tiering (est): \$%.2f/month\n" "$COST_IT"
echo "(Assumes 10%% hot, 30%% IA, 40%% Glacier IR, 20%% Deep Archive)"
echo ""

# Monitoring costs
MONITORING=$(echo "$TOTAL_OBJECTS * 0.0000025" | bc)
printf "Monitoring fee (~):        \$%.2f/month\n" "$MONITORING"
echo ""
echo "Note: Actual costs depend on access patterns. Check AWS Cost Explorer for accurate billing."
