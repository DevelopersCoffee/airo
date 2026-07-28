#!/usr/bin/env bash
set -euo pipefail

readonly VERSION="0.10.29"
readonly UPSTREAM_URL="https://dl.google.com/dl/android/maven2/com/google/mediapipe/tasks-core/${VERSION}/tasks-core-${VERSION}.aar"
readonly UPSTREAM_SHA256="7c9f935c6e60f2d612ba3240991863fc12a48a25d67dc4373a52ce8c3b0c2232"
readonly SOURCE_COMMIT="8317ba78778738ba90a521e7e4580a2ba0129c81"
readonly LICENSE_URL="https://raw.githubusercontent.com/google-ai-edge/mediapipe/${SOURCE_COMMIT}/LICENSE"
readonly LICENSE_SHA256="8707eef0533987efc5b155d64761eeb6e20793f50b9bd1a68dad1cf4719d0ed8"
readonly FIXED_TIMESTAMP="201001010000"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FACTORY_SOURCE="${SCRIPT_DIR}/TasksStatsLoggerFactory.java"
readonly NOTICE_SOURCE="${SCRIPT_DIR}/NOTICE"

usage() {
  echo "usage: $0 --android-jar PATH --output PATH [--javac PATH]" >&2
}

android_jar=""
output_path=""
javac_bin="javac"
while (($# > 0)); do
  case "$1" in
    --android-jar)
      android_jar="${2:-}"
      shift 2
      ;;
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    --javac)
      javac_bin="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ ! -f "$android_jar" || "$output_path" != *.aar ]]; then
  usage
  exit 64
fi
if [[ -e "$output_path" ]]; then
  echo "refusing to overwrite existing output: $output_path" >&2
  exit 73
fi
for required_file in "$FACTORY_SOURCE" "$NOTICE_SOURCE"; do
  if [[ ! -f "$required_file" ]]; then
    echo "missing derivation input: $required_file" >&2
    exit 66
  fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/airo-mediapipe-core.XXXXXX")"
case "$work_dir" in
  */airo-mediapipe-core.*) ;;
  *)
    echo "unsafe temporary directory: $work_dir" >&2
    exit 70
    ;;
esac
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

readonly upstream_aar="${work_dir}/tasks-core-${VERSION}.aar"
readonly upstream_license="${work_dir}/LICENSE"
readonly aar_tree="${work_dir}/aar"
readonly classes_tree="${work_dir}/classes"
readonly compiled_tree="${work_dir}/compiled"
readonly derived_aar="${work_dir}/tasks-core-${VERSION}-airo-no-telemetry.aar"

curl --fail --location --silent --show-error \
  --retry 3 --connect-timeout 15 --max-time 120 \
  --output "$upstream_aar" "$UPSTREAM_URL"
curl --fail --location --silent --show-error \
  --retry 3 --connect-timeout 15 --max-time 120 \
  --output "$upstream_license" "$LICENSE_URL"

actual_upstream_sha="$(shasum -a 256 "$upstream_aar" | awk '{print $1}')"
actual_license_sha="$(shasum -a 256 "$upstream_license" | awk '{print $1}')"
if [[ "$actual_upstream_sha" != "$UPSTREAM_SHA256" ]]; then
  echo "upstream AAR hash mismatch: $actual_upstream_sha" >&2
  exit 65
fi
if [[ "$actual_license_sha" != "$LICENSE_SHA256" ]]; then
  echo "upstream license hash mismatch: $actual_license_sha" >&2
  exit 65
fi

mkdir -p "$aar_tree" "$classes_tree" "$compiled_tree"
unzip -q "$upstream_aar" -d "$aar_tree"
unzip -q "$aar_tree/classes.jar" -d "$classes_tree"

rm -f \
  "$classes_tree/com/google/mediapipe/tasks/core/logging/LoggingClient.class" \
  "$classes_tree/com/google/mediapipe/tasks/core/logging/RemoteLoggingClient.class" \
  "$classes_tree/com/google/mediapipe/tasks/core/logging/TasksStatsProtoLogger.class"
find "$classes_tree/com/google/mediapipe/proto" -type f \
  \( -name 'MediaPipeLoggingProto*.class' \
  -o -name 'MediaPipeLoggingEnumsProto*.class' \) -delete

"$javac_bin" \
  -encoding UTF-8 \
  -g:none \
  --release 8 \
  -classpath "$android_jar:$aar_tree/classes.jar" \
  -d "$compiled_tree" \
  "$FACTORY_SOURCE"
cp \
  "$compiled_tree/com/google/mediapipe/tasks/core/logging/TasksStatsLoggerFactory.class" \
  "$classes_tree/com/google/mediapipe/tasks/core/logging/TasksStatsLoggerFactory.class"

mkdir -p "$aar_tree/META-INF"
cp "$upstream_license" "$aar_tree/META-INF/LICENSE"
cp "$NOTICE_SOURCE" "$aar_tree/META-INF/NOTICE"

export TZ=UTC
find "$classes_tree" -type f -exec touch -t "$FIXED_TIMESTAMP" {} +
rm -f "$aar_tree/classes.jar"
(
  cd "$classes_tree"
  find . -type f -print | LC_ALL=C sort | zip -X -q "$aar_tree/classes.jar" -@
)
find "$aar_tree" -type f -exec touch -t "$FIXED_TIMESTAMP" {} +
(
  cd "$aar_tree"
  find . -type f -print | LC_ALL=C sort | zip -X -q "$derived_aar" -@
)

mkdir -p "$(dirname "$output_path")"
mv "$derived_aar" "$output_path"
shasum -a 256 "$output_path"
