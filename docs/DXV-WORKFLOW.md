# DXV Codec Workflow Guide

This guide covers converting video files to Resolume DXV3 codec for optimal VJing performance.

## Understanding DXV

DXV is Resolume's proprietary codec optimized for real-time GPU playback. It uses DXT compression (same as game textures) for instant GPU decoding.

### Why DXV?

| Codec | CPU Usage | GPU Decode | Scrubbing | File Size |
|-------|-----------|------------|-----------|-----------|
| H.264/MP4 | High | Partial | Slow | Small |
| ProRes | Medium | No | Medium | Large |
| **DXV3** | **Minimal** | **Full** | **Instant** | Large |
| HAP | Minimal | Full | Instant | Large |

**Bottom line**: DXV3 gives butter-smooth playback in Resolume even with multiple layers.

## FFmpeg Limitations

FFmpeg can **decode** DXV but cannot **encode** it:

```bash
# This works (decode)
ffmpeg -i video.dxv -c:v libx264 output.mp4

# This does NOT work (encode)
ffmpeg -i video.mp4 -c:v dxv output.dxv  # ERROR: Unknown encoder
```

Resolume has not released the encoding algorithm publicly.

## Encoding with Resolume Alley

[Resolume Alley](https://resolume.com/software/codec) is the free, official tool for DXV encoding.

### Basic Workflow

1. **Launch Alley** (free download from Resolume)
2. **Drag files** into the window (or folder for batch)
3. **Select codec**: DXV3 (recommended)
4. **Choose quality**: Normal (default) or High
5. **Set output folder**: Alongside source or custom
6. **Click Convert**

### Quality Settings

| Setting | When to Use |
|---------|-------------|
| **Normal** | 95% of content - good balance |
| **High** | Gradients, subtle color transitions, text |

High quality doubles file size with marginal visual improvement for most content.

### Batch Conversion Tips

```
1. Organize source files in folders by pack
2. Drag entire folder into Alley
3. Output to parallel folder structure
4. Delete source after verification
```

Example structure:
```
source/
├── mitch/pack1/  → alley → dxv/mitch/pack1/
├── mitch/pack2/  → alley → dxv/mitch/pack2/
└── luke/pack1/   → alley → dxv/luke/pack1/
```

## Adobe Integration

If you have After Effects, Premiere, or Media Encoder installed when you install Resolume, export plugins are added automatically.

### After Effects

1. Composition > Add to Render Queue
2. Output Module > Format: QuickTime
3. Video Codec: Resolume DXV3
4. Quality: Normal

### Media Encoder

1. Drag sequence to queue
2. Format: QuickTime
3. Preset: Create custom with DXV3 codec

## Preprocessing with FFmpeg

Use FFmpeg for format conversion BEFORE Alley:

### Resize to 1080p
```bash
ffmpeg -i input.mp4 -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -crf 18 output_1080p.mp4
```

### Convert to proper frame rate
```bash
ffmpeg -i input.mp4 -r 30 -c:v libx264 -crf 18 output_30fps.mp4
```

### Extract segment
```bash
ffmpeg -i input.mp4 -ss 00:01:00 -t 00:00:30 -c copy segment.mp4
```

### Batch preprocessing script
```bash
#!/bin/bash
for f in *.mp4; do
  ffmpeg -i "$f" -vf "scale=1920:1080:force_original_aspect_ratio=decrease" -c:v libx264 -crf 18 "processed/${f}"
done
```

## Alternative: HAP Codec

HAP is an open-source GPU codec that works similarly to DXV.

### Pros
- FFmpeg can encode: `ffmpeg -i in.mp4 -c:v hap out.mov`
- Cross-platform support
- Resolume supports it natively

### Cons
- Slightly higher CPU usage than DXV3
- Less optimized for Resolume specifically
- Requires MOV container (not MP4)

### HAP Encoding
```bash
# Standard HAP
ffmpeg -i input.mp4 -c:v hap output.mov

# HAP Alpha (with transparency)
ffmpeg -i input.mov -c:v hap_alpha output.mov

# HAP Q (higher quality)
ffmpeg -i input.mp4 -c:v hap -compressor snappy output.mov
```

## Recommended Workflow

```
Source MP4 (archival)
    │
    ├─► S3 Archive (intelligent-tiering)
    │
    └─► FFmpeg Preprocess (if needed)
            │
            └─► Resolume Alley (DXV3 Normal)
                    │
                    └─► Resolume Arena (VJing)
```

1. Keep original MP4s in S3 archive (smaller, universal)
2. Convert to DXV3 only for active use in Resolume
3. Store DXV3 locally or on fast NAS for performance

## File Size Comparison

For a 1-minute 1080p 30fps clip:

| Codec | Approximate Size |
|-------|------------------|
| H.264 (CRF 18) | ~50 MB |
| ProRes 422 | ~500 MB |
| DXV3 Normal | ~400 MB |
| DXV3 High | ~800 MB |
| HAP | ~600 MB |

## Troubleshooting

### Alley crashes on large files
- Split video into segments first
- Ensure sufficient RAM (16GB+ recommended)
- Process in smaller batches

### Playback stutters in Resolume
- Check disk speed (SSD recommended for DXV)
- Lower preview quality in Resolume
- Reduce number of simultaneous layers

### Colors look wrong
- Ensure source is Rec.709 color space
- Check gamma settings in Alley
- Use "Broadcast Safe" option if oversaturated
