# AWS S3 Cost Analysis for VJ Archive

Detailed cost breakdown for storing 40TB of VJ video clips in AWS S3.

## Storage Cost Scenarios

### Scenario 1: All S3 Standard (Worst Case)

Everything stays in hot storage:

| Item | Calculation | Monthly Cost |
|------|-------------|--------------|
| Storage | 40,000 GB × $0.023/GB | $920.00 |
| Monitoring | N/A | $0.00 |
| **Total** | | **$920.00/month** |

### Scenario 2: S3 Intelligent-Tiering (Recommended)

Automatic tiering based on access patterns:

| Tier | % of Data | GB | Rate | Monthly Cost |
|------|-----------|-----|------|--------------|
| Frequent Access | 10% | 4,000 | $0.023 | $92.00 |
| Infrequent (30d) | 30% | 12,000 | $0.0125 | $150.00 |
| Archive Instant (90d) | 40% | 16,000 | $0.004 | $64.00 |
| Archive Access | 15% | 6,000 | $0.0036 | $21.60 |
| Deep Archive | 5% | 2,000 | $0.00099 | $1.98 |
| **Storage Total** | | | | **$329.58** |
| Monitoring Fee | 100,000 objects | | $0.0025/1000 | $0.25 |
| **Total** | | | | **$329.83/month** |

### Scenario 3: Mostly Archival

90% of content rarely accessed:

| Tier | % of Data | GB | Rate | Monthly Cost |
|------|-----------|-----|------|--------------|
| Frequent Access | 5% | 2,000 | $0.023 | $46.00 |
| Infrequent | 5% | 2,000 | $0.0125 | $25.00 |
| Deep Archive | 90% | 36,000 | $0.00099 | $35.64 |
| **Total** | | | | **$106.64/month** |

## Request Costs

### Initial Upload (One-time)

Assuming 100,000 objects (average 400MB each):

| Operation | Count | Rate | Cost |
|-----------|-------|------|------|
| PUT requests | 100,000 | $0.005/1000 | $0.50 |
| LIST requests | 1,000 | $0.005/1000 | $0.005 |
| **Total** | | | **$0.51** |

### Monthly Operations

Normal sync and browsing:

| Operation | Monthly Count | Rate | Cost |
|-----------|---------------|------|------|
| LIST | 10,000 | $0.005/1000 | $0.05 |
| GET | 5,000 | $0.0004/1000 | $0.002 |
| PUT (new uploads) | 500 | $0.005/1000 | $0.003 |
| **Total** | | | **~$0.06** |

## Data Transfer Costs

### Upload (IN)

**Free** - No cost for data transfer into S3.

### Download (OUT)

| Destination | Rate | 100GB Cost | 1TB Cost |
|-------------|------|------------|----------|
| Internet | $0.09/GB | $9.00 | $90.00 |
| Same region EC2 | Free | $0.00 | $0.00 |
| Different region | $0.02/GB | $2.00 | $20.00 |

**Strategy**: Minimize downloads. Keep working copies local/NAS.

## Glacier Retrieval Costs

When restoring from Archive/Deep Archive tiers:

### Archive Access Tier

| Retrieval Type | Time | Cost/GB | 100GB Cost |
|----------------|------|---------|------------|
| Expedited | 1-5 min | $0.03 | $3.00 |
| Standard | 3-5 hours | $0.01 | $1.00 |
| Bulk | 5-12 hours | $0.0025 | $0.25 |

### Deep Archive Tier

| Retrieval Type | Time | Cost/GB | 100GB Cost |
|----------------|------|---------|------------|
| Standard | 12 hours | $0.02 | $2.00 |
| Bulk | 48 hours | $0.0025 | $0.25 |

**Recommendation**: Use Bulk retrieval for non-urgent restores.

## Annual Cost Summary

| Scenario | Monthly | Annual |
|----------|---------|--------|
| All Standard | $920 | $11,040 |
| Intelligent-Tiering (mixed) | $330 | $3,960 |
| Mostly Archival | $107 | $1,284 |

**Savings with Intelligent-Tiering**: $7,080/year vs Standard

## Cost Optimization Tips

### 1. Enable Intelligent-Tiering

Automatic optimization without manual management:
```hcl
resource "aws_s3_bucket_intelligent_tiering_configuration" "archive" {
  bucket = aws_s3_bucket.vj_archive.id
  name   = "EntireArchive"
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}
```

### 2. Use S3 Storage Lens

Monitor storage patterns and identify optimization opportunities:
- Free metrics dashboard
- Identifies cold data candidates
- Tracks cost trends

### 3. Set Lifecycle Rules

For known archival content:
```hcl
rule {
  id     = "archive-old-content"
  status = "Enabled"
  transition {
    days          = 30
    storage_class = "GLACIER_IR"
  }
}
```

### 4. Minimize Egress

- Keep working copies on local NAS
- Process in same-region EC2 (free transfer)
- Use CloudFront for frequent access patterns

## Comparison with Alternatives

### Backblaze B2

| Metric | AWS S3 | Backblaze B2 |
|--------|--------|--------------|
| Storage | $0.023/GB | $0.006/GB |
| Download | $0.09/GB | $0.01/GB |
| 40TB Storage | $920/mo | $240/mo |
| Ecosystem | Excellent | Limited |

**Note**: B2 is cheaper but lacks Intelligent-Tiering and AWS integration.

### Wasabi

| Metric | AWS S3 | Wasabi |
|--------|--------|--------|
| Storage | $0.023/GB | $0.0069/GB |
| Download | $0.09/GB | Free* |
| 40TB Storage | $920/mo | $276/mo |

*Wasabi free egress has usage limits.

### Google Cloud Storage

| Metric | AWS S3 | GCS |
|--------|--------|-----|
| Standard | $0.023/GB | $0.020/GB |
| Nearline | $0.010/GB | $0.010/GB |
| Archive | $0.004/GB | $0.0012/GB |

Similar pricing, choose based on existing infrastructure.

## Break-Even Analysis

When does Intelligent-Tiering save money?

| Access Pattern | Standard Cost | IT Cost | Monthly Savings |
|----------------|---------------|---------|-----------------|
| 100% hot | $920 | $920 | $0 |
| 50% cold (30d) | $920 | $620 | $300 |
| 80% cold (90d) | $920 | $380 | $540 |
| 95% cold (180d) | $920 | $170 | $750 |

**Conclusion**: Intelligent-Tiering is always equal or better cost.
