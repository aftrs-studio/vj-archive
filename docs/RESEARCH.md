# Research Documentation for Future LLMs

This document captures research findings for AWS S3 storage, rclone optimization, and VJ video workflows. Future AI assistants can use this as context when working on this project.

## AWS S3 Storage Classes

### S3 Intelligent-Tiering (Recommended)

Automatically moves objects between tiers based on access patterns:

| Tier | When | Cost/GB/month | Retrieval |
|------|------|---------------|-----------|
| Frequent Access | Default | $0.023 | Instant |
| Infrequent Access | 30 days no access | $0.0125 | Instant |
| Archive Instant | 90 days no access | $0.004 | Instant |
| Archive Access | 90+ days (opt-in) | $0.0036 | 3-5 hours |
| Deep Archive | 180+ days (opt-in) | $0.00099 | 12-48 hours |

**Key Benefits**:
- No retrieval fees for Frequent/Infrequent/Archive Instant tiers
- Automatic optimization without manual intervention
- Small monitoring fee ($0.0025/1000 objects) negligible for large files

### Cost Comparison for 40TB

| Scenario | Monthly Cost |
|----------|--------------|
| All S3 Standard | $920 |
| 50% Infrequent (mixed access) | $690 |
| 80% Archive Instant (cold) | $368 |
| 95% Deep Archive (archival) | $92 |

### Retrieval Costs

Only applies when restoring from Archive/Deep Archive tiers:
- Archive Access: $0.03/GB + $10/1000 requests
- Deep Archive: $0.02/GB + $2.50/1000 requests
- Bulk retrieval (48h): 50% cheaper

## Rclone Configuration

### Optimized Flags for Large Video Files

```bash
rclone sync source dest \
  --transfers 10 \              # Parallel file transfers
  --s3-upload-concurrency 4 \   # Parts uploaded per file
  --s3-chunk-size 100M \        # Multipart chunk size
  --s3-disable-checksum \       # Skip MD5 for speed
  --fast-list \                 # Single API call for listing
  --update \                    # Skip files newer on dest
  --use-server-modtime \        # Use S3 modtime (avoids HEAD)
  --progress                    # Show transfer progress
```

### Why These Flags Matter

| Flag | Purpose | Impact |
|------|---------|--------|
| `--transfers 10` | Parallel uploads | 10x throughput |
| `--s3-upload-concurrency 4` | Parallel parts per file | Better large file handling |
| `--s3-chunk-size 100M` | Larger chunks | Fewer API calls |
| `--s3-disable-checksum` | Skip MD5 calculation | Faster uploads |
| `--fast-list` | Recursive list in one call | Fewer API requests |
| `--use-server-modtime` | Trust S3 timestamps | Avoids HEAD requests |

### Performance Benchmarks

With optimized settings on 1Gbps connection:
- Upload speed: 100-440 MB/s achievable
- 1TB transfer: ~40-90 minutes
- 40TB transfer: ~27-60 hours

### Rclone Mount Option

For direct S3 access without sync:
```bash
rclone mount aftrs-vj-archive:aftrs-vj-archive /mnt/vj-archive \
  --vfs-cache-mode full \
  --vfs-cache-max-size 50G
```

Pros: Instant access, no local storage needed
Cons: Network latency, data transfer costs on read

## DXV Codec Research

### DXV3 Overview

- **Developer**: Resolume (proprietary)
- **Purpose**: GPU-accelerated video playback for VJing
- **Compression**: DXT-based (DirectX Texture Compression)
- **File sizes**: ~3-5x larger than H.264

### FFmpeg Support

FFmpeg has a **decoder only** for DXV:
```bash
# Decode DXV to other format (works)
ffmpeg -i input.dxv -c:v libx264 output.mp4

# Encode to DXV (NOT SUPPORTED)
ffmpeg -i input.mp4 -c:v dxv output.dxv  # FAILS
```

### Encoding Options

1. **Resolume Alley** (Free)
   - Drag-drop interface
   - Batch conversion supported
   - Best for large collections

2. **Adobe Plugins**
   - After Effects, Premiere, Media Encoder
   - Installed automatically with Resolume
   - Better for post-production workflows

3. **Resolume Wire**
   - Real-time encoding
   - For live capture scenarios

### Quality Settings

| Setting | File Size | Quality | Use Case |
|---------|-----------|---------|----------|
| Normal | 1x | Good | Most content |
| High | 2x | Excellent | Gradients, fine detail |

**Recommendation**: Use Normal quality unless visible banding appears.

### HAP Codec Alternative

Open-source DXT-based codec with GPU playback:
- Cross-platform (Windows, Mac, Linux)
- FFmpeg can encode: `ffmpeg -i in.mp4 -c:v hap out.mov`
- Slightly lower performance than DXV3 in Resolume

## AWS Transfer Options

### Option 1: Direct rclone (Recommended)

Best for ongoing sync, no additional cost:
```bash
rclone sync /local/path s3:bucket --progress
```

### Option 2: S3 Transfer Acceleration

Enables faster uploads via CloudFront edge:
- Additional cost: $0.04-0.08/GB
- 50-500% faster for distant regions
- Enable: `aws s3api put-bucket-accelerate-configuration`

### Option 3: AWS Snowball

Physical device for initial bulk transfer:
- 80TB capacity per device
- ~$300 per job + shipping
- Best for: Initial 40TB migration
- Transfer time: 1 week including shipping

### Option 4: AWS DataSync

Managed transfer service:
- $0.0125/GB transferred
- Handles scheduling, verification
- Best for: Ongoing large transfers

## Research Leads (Unexplored)

1. **S3 Object Lock** - Immutable backups for compliance
2. **Cross-Region Replication** - Disaster recovery
3. **CloudFront Distribution** - Serve clips to remote VJ rigs
4. **S3 Batch Operations** - Bulk storage class changes
5. **AWS Backup** - Centralized backup management
6. **S3 Inventory** - Audit large buckets efficiently
7. **S3 Storage Lens** - Analytics and cost optimization
8. **EC2 in-region transfer** - Avoid egress costs for processing

## Sources

- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [S3 Intelligent-Tiering](https://aws.amazon.com/s3/storage-classes/intelligent-tiering/)
- [Rclone S3 Backend](https://rclone.org/s3/)
- [Rclone Performance Tips](https://forum.rclone.org/t/how-to-reach-max-speed-dwn-up-on-s3-compatible-storage/33144)
- [Resolume DXV Codec](https://www.resolume.com/software/codec)
- [FFmpeg DXV Decoder](https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/dxv.c)
- [S3 Cost Calculator](https://calculator.aws/)
