#!/usr/bin/env bash
set -euo pipefail

INPUT="$1"
OUTPUT_DIR="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <input.mp4> <output_dir>"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# HLS segment duration in seconds
SEGMENT_TIME=6

# Remove old output
# rm -f "$OUTPUT"/*.m3u8 "$OUTPUT"/*.ts

echo "Input File: $INPUT"
echo "Output Dir: $OUTPUT_DIR"

ffmpeg -hide_banner -y \
  -i "$INPUT" \
  -filter_complex "\
    [0:v]split=4[v1080][v720][v480][v360]; \
    [v1080]scale=w=1920:h=-2[v1080out]; \
    [v720]scale=w=1280:h=-2[v720out]; \
    [v480]scale=w=854:h=-2[v480out]; \
    [v360]scale=w=640:h=-2[v360out] \
  " \
  \
  -map "[v1080out]" -map 0:a? \
  -c:v:0 libx264 -b:v:0 5000k -maxrate:v:0 5350k -bufsize:v:0 7500k \
  -c:a:0 aac -b:a:0 192k \
  \
  -map "[v720out]" -map 0:a? \
  -c:v:1 libx264 -b:v:1 2800k -maxrate:v:1 2996k -bufsize:v:1 4200k \
  -c:a:1 aac -b:a:1 128k \
  \
  -map "[v480out]" -map 0:a? \
  -c:v:2 libx264 -b:v:2 1400k -maxrate:v:2 1498k -bufsize:v:2 2100k \
  -c:a:2 aac -b:a:2 128k \
  \
  -map "[v360out]" -map 0:a? \
  -c:v:3 libx264 -b:v:3 800k -maxrate:v:3 856k -bufsize:v:3 1200k \
  -c:a:3 aac -b:a:3 96k \
  \
  -preset medium \
  -profile:v main \
  -pix_fmt yuv420p \
  -g 48 \
  -keyint_min 48 \
  -sc_threshold 0 \
  \
  -f hls \
  -hls_time "$SEGMENT_TIME" \
  -hls_playlist_type vod \
  -hls_flags independent_segments \
  -hls_segment_type mpegts \
  -hls_segment_filename "$OUTPUT_DIR/%v/segment_%05d.ts" \
  -master_pl_name master.m3u8 \
  -var_stream_map "\
    v:0,a:0,name:1080p \
    v:1,a:1,name:720p \
    v:2,a:2,name:480p \
    v:3,a:3,name:360p" \
  "$OUTPUT_DIR/%v/index.m3u8"

echo
echo "Done!"
echo "Master playlist: $OUTPUT_DIR/master.m3u8"
