#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_DERIVED_SHA256="36366b6b3ee7cb8279e3b3dd608774f4f30298296e56d6ff23f7f083d4bc0416"
readonly EXPECTED_LICENSE_SHA256="8707eef0533987efc5b155d64761eeb6e20793f50b9bd1a68dad1cf4719d0ed8"

if (($# != 1)) || [[ "$1" != *.aar || ! -f "$1" ]]; then
  echo "usage: $0 PATH_TO_DERIVED_AAR" >&2
  exit 64
fi
readonly artifact_path="$1"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/airo-mediapipe-audit.XXXXXX")"
case "$work_dir" in
  */airo-mediapipe-audit.*) ;;
  *)
    echo "unsafe temporary directory: $work_dir" >&2
    exit 70
    ;;
esac
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

readonly aar_tree="${work_dir}/aar"
readonly classes_tree="${work_dir}/classes"
mkdir -p "$aar_tree" "$classes_tree"
unzip -q "$artifact_path" -d "$aar_tree"
unzip -q "$aar_tree/classes.jar" -d "$classes_tree"

actual_sha="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"
if [[ "$actual_sha" != "$EXPECTED_DERIVED_SHA256" ]]; then
  echo "derived AAR hash mismatch: $actual_sha" >&2
  exit 65
fi

for forbidden_path in \
  "com/google/mediapipe/tasks/core/logging/LoggingClient.class" \
  "com/google/mediapipe/tasks/core/logging/RemoteLoggingClient.class" \
  "com/google/mediapipe/tasks/core/logging/TasksStatsProtoLogger.class"; do
  if [[ -e "$classes_tree/$forbidden_path" ]]; then
    echo "forbidden logging class present: $forbidden_path" >&2
    exit 1
  fi
done
if find "$classes_tree/com/google/mediapipe/proto" -type f \
  \( -name 'MediaPipeLoggingProto*.class' \
  -o -name 'MediaPipeLoggingEnumsProto*.class' \) | grep -q .; then
  echo "forbidden usage-logging proto class present" >&2
  exit 1
fi
if rg -a -q \
  'COREML_ON_DEVICE_SOLUTIONS|com/google/android/datatransport|TasksStatsProtoLogger|RemoteLoggingClient' \
  "$classes_tree"; then
  echo "forbidden telemetry symbol or string present" >&2
  exit 1
fi

factory_bytecode="$(javap \
  -classpath "$aar_tree/classes.jar" \
  -p -c \
  com.google.mediapipe.tasks.core.logging.TasksStatsLoggerFactory)"
if ! grep -q 'TasksStatsDummyLogger.create' <<<"$factory_bytecode"; then
  echo "factory does not invoke TasksStatsDummyLogger" >&2
  exit 1
fi
if grep -q 'TasksStatsProtoLogger' <<<"$factory_bytecode"; then
  echo "factory still invokes TasksStatsProtoLogger" >&2
  exit 1
fi

for legal_file in LICENSE NOTICE; do
  if [[ ! -s "$aar_tree/META-INF/$legal_file" ]]; then
    echo "missing legal file: META-INF/$legal_file" >&2
    exit 1
  fi
done
actual_license_sha="$(shasum -a 256 "$aar_tree/META-INF/LICENSE" | awk '{print $1}')"
if [[ "$actual_license_sha" != "$EXPECTED_LICENSE_SHA256" ]]; then
  echo "embedded license hash mismatch: $actual_license_sha" >&2
  exit 65
fi

echo "ok: telemetry-free MediaPipe tasks-core $actual_sha"
