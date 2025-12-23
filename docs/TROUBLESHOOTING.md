# VJ Archive Troubleshooting Guide

Common issues and solutions for the VJ Archive system.

## Sync Issues

### Sync is Slow

**Symptoms**: Transfer speeds below 50 MB/s

**Solutions**:
1. Check network connection to AWS region (ap-southeast-2)
2. Increase parallelism:
   ```bash
   rclone sync source dest --transfers 20 --s3-upload-concurrency 8
   ```
3. For very large files, increase chunk size:
   ```bash
   rclone sync source dest --s3-chunk-size 200M
   ```
4. Run from EC2 in same region for fastest transfers

### Sync Hangs or Times Out

**Symptoms**: Transfer stops responding

**Solutions**:
1. Add timeout flags:
   ```bash
   rclone sync source dest --timeout 1h --contimeout 60s
   ```
2. Enable retries:
   ```bash
   rclone sync source dest --retries 3 --retries-sleep 10s
   ```
3. Check AWS service health: https://health.aws.amazon.com/

### "Access Denied" Errors

**Symptoms**: `AccessDenied` or `403 Forbidden`

**Solutions**:
1. Verify AWS profile is set correctly:
   ```bash
   export AWS_PROFILE=aftrs
   aws sts get-caller-identity
   ```
2. Check IAM permissions include:
   - `s3:GetObject`
   - `s3:PutObject`
   - `s3:ListBucket`
   - `s3:DeleteObject`
3. Verify bucket policy allows your IAM user

### Rate Limiting (503 Slow Down)

**Symptoms**: `SlowDown` errors, retries

**Solutions**:
1. Reduce concurrency:
   ```bash
   rclone sync source dest --transfers 4 --s3-upload-concurrency 2
   ```
2. Add delays between operations:
   ```bash
   rclone sync source dest --tpslimit 10
   ```
3. For large migrations, consider using S3 Transfer Acceleration

## Storage Class Issues

### Files Stuck in Glacier

**Symptoms**: Cannot download files, "InvalidObjectState" error

**Solutions**:
1. Check storage class:
   ```bash
   aws s3api head-object --bucket aftrs-vj-archive --key path/to/file --profile aftrs
   ```
2. Restore from Glacier:
   ```bash
   ./scripts/restore-files.sh path/to/files --standard
   ```
3. Wait for restore (3-12 hours depending on tier)
4. Download once "ongoing-request: false"

### Restore Taking Too Long

**Symptoms**: Glacier restore not completing

**Solutions**:
1. Check restore status:
   ```bash
   aws s3api head-object --bucket aftrs-vj-archive --key path/file --profile aftrs | grep -i restore
   ```
2. Use expedited retrieval for urgent files (costs more):
   ```bash
   ./scripts/restore-files.sh path/to/file --expedited
   ```
3. Deep Archive takes up to 48 hours for bulk retrieval

## Cost Issues

### Unexpected High Costs

**Symptoms**: AWS bill higher than expected

**Solutions**:
1. Run cost report:
   ```bash
   ./scripts/cost-report.sh
   ```
2. Check for:
   - Data transfer OUT (egress): $0.09/GB
   - Frequent Glacier restores
   - Objects not transitioning to cheaper tiers
3. Enable AWS Cost Explorer for detailed breakdown
4. Set up billing alerts in AWS Console

### Objects Not Transitioning to Archive

**Symptoms**: Files staying in expensive tiers

**Solutions**:
1. Intelligent-Tiering monitors access automatically
2. Objects must be >128KB to transition
3. Check lifecycle rules in Terraform:
   ```bash
   terraform -chdir=terraform state show aws_s3_bucket_intelligent_tiering_configuration.archive
   ```

## Rclone Configuration Issues

### Remote Not Found

**Symptoms**: `Failed to create file system: didn't find section in config file`

**Solutions**:
1. Check rclone config exists:
   ```bash
   cat ~/.config/rclone/rclone.conf | grep -A5 aftrs-vj-archive
   ```
2. Reconfigure remote:
   ```bash
   rclone config
   # Select: n (new remote)
   # Name: aftrs-vj-archive
   # Type: s3
   # Provider: AWS
   ```

### Invalid Credentials

**Symptoms**: `SignatureDoesNotMatch` or `InvalidAccessKeyId`

**Solutions**:
1. Update rclone credentials from AWS profile:
   ```bash
   AWS_KEY=$(aws configure get aws_access_key_id --profile aftrs)
   AWS_SECRET=$(aws configure get aws_secret_access_key --profile aftrs)
   rclone config update aftrs-vj-archive access_key_id "$AWS_KEY" secret_access_key "$AWS_SECRET"
   ```
2. Verify profile works:
   ```bash
   AWS_PROFILE=aftrs aws s3 ls s3://aftrs-vj-archive/
   ```

## File Integrity Issues

### Corrupt Files After Upload

**Symptoms**: Files don't play or have artifacts

**Solutions**:
1. Enable checksum verification:
   ```bash
   rclone sync source dest --checksum
   ```
2. Verify specific file:
   ```bash
   rclone check /local/file aftrs-vj-archive:aftrs-vj-archive/path/file
   ```
3. Re-upload with checksums enabled

### Missing Files After Sync

**Symptoms**: Files present locally but not in S3

**Solutions**:
1. Check for sync errors in log:
   ```bash
   grep -i error /var/log/vj-archive-sync.log
   ```
2. Look for path issues (special characters):
   ```bash
   rclone sync source dest --log-level DEBUG 2>&1 | grep -i skip
   ```
3. Re-run sync with verbose output:
   ```bash
   rclone sync source dest -v --log-file=/tmp/debug.log
   ```

## Terraform Issues

### State Lock Error

**Symptoms**: `Error acquiring the state lock`

**Solutions**:
1. Wait for other operations to complete
2. Force unlock (use with caution):
   ```bash
   terraform force-unlock LOCK_ID
   ```

### Plan Shows Unexpected Changes

**Symptoms**: Terraform wants to recreate resources

**Solutions**:
1. Check for drift:
   ```bash
   terraform -chdir=terraform refresh
   terraform -chdir=terraform plan
   ```
2. Import existing resources if created outside Terraform

## Getting Help

### Logs to Collect

When reporting issues, include:
1. rclone sync log: `/var/log/vj-archive-sync.log`
2. AWS CLI version: `aws --version`
3. rclone version: `rclone version`
4. Error message (full text)
5. Command that failed

### Useful Commands

```bash
# Check AWS connectivity
aws s3 ls s3://aftrs-vj-archive/ --profile aftrs

# Check rclone connectivity
rclone lsd aftrs-vj-archive:aftrs-vj-archive

# Get bucket info
aws s3api get-bucket-location --bucket aftrs-vj-archive --profile aftrs

# List with details
rclone lsl aftrs-vj-archive:aftrs-vj-archive --fast-list | head

# Check storage class of specific file
aws s3api head-object --bucket aftrs-vj-archive --key path/to/file --profile aftrs
```

### Support Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [rclone Documentation](https://rclone.org/docs/)
- [rclone Forum](https://forum.rclone.org/)
- GitHub Issues: https://github.com/aftrs-studio/vj-archive/issues
