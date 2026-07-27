#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 64
fi

command -v ffmpeg >/dev/null || {
  echo "ffmpeg is required to generate media analyzer fixtures" >&2
  exit 69
}

output_directory=$1
mkdir -p "$output_directory"
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

cat >"$temporary_directory/english.srt" <<'EOF'
1
00:00:00,000 --> 00:00:01,500
Deterministic English subtitle
EOF

cat >"$temporary_directory/spanish.ass" <<'EOF'
[Script Info]
ScriptType: v4.00+
PlayResX: 320
PlayResY: 180

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,16,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,2,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:01.50,Default,,0,0,0,,Subtítulo determinista
EOF

common_video=(-f lavfi -i color=c=blue:s=320x180:r=24:d=2)

ffmpeg -hide_banner -loglevel error -y \
  "${common_video[@]}" \
  -f lavfi -i sine=frequency=440:sample_rate=48000:duration=2 \
  -map 0:v:0 -map 1:a:0 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
  -c:a aac -b:a 96k -movflags +faststart \
  "$output_directory/mp4-h264-aac.mp4"

ffmpeg -hide_banner -loglevel error -y \
  "${common_video[@]}" \
  -f lavfi -i sine=frequency=550:sample_rate=48000:duration=2 \
  -map 0:v:0 -map 1:a:0 \
  -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -pix_fmt yuv420p \
  -c:a libopus -b:a 64k \
  "$output_directory/webm-vp9-opus.webm"

ffmpeg -hide_banner -loglevel error -y \
  "${common_video[@]}" \
  -f lavfi -i sine=frequency=660:sample_rate=48000:duration=2 \
  -map 0:v:0 -map 1:a:0 \
  -vf 'setparams=color_primaries=bt2020:color_trc=smpte2084:colorspace=bt2020nc' \
  -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le \
  -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
  -x265-params 'repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc' \
  -c:a dca -strict -2 -b:a 768k \
  "$output_directory/mkv-hevc-main10-hdr10-dts.mkv"

ffmpeg -hide_banner -loglevel error -y \
  "${common_video[@]}" \
  -f lavfi -i sine=frequency=440:sample_rate=48000:duration=2 \
  -f lavfi -i sine=frequency=880:sample_rate=48000:duration=2 \
  -i "$temporary_directory/english.srt" \
  -i "$temporary_directory/spanish.ass" \
  -map 0:v:0 -map 1:a:0 -map 2:a:0 -map 3:s:0 -map 4:s:0 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
  -c:a aac -b:a 96k -c:s copy \
  -metadata:s:a:0 language=eng -metadata:s:a:1 language=spa \
  -metadata:s:s:0 language=eng -metadata:s:s:1 language=spa \
  -disposition:a:0 default -disposition:a:1 0 \
  -disposition:s:0 default -disposition:s:1 forced \
  "$output_directory/mkv-multi-audio-text-subtitles.mkv"

(
  cd "$output_directory"
  shasum -a 256 \
    mp4-h264-aac.mp4 \
    webm-vp9-opus.webm \
    mkv-hevc-main10-hdr10-dts.mkv \
    mkv-multi-audio-text-subtitles.mkv \
    > SHA256SUMS
)
