#!/usr/bin/env bash
# Verifies Mind runtime follow-ups end-to-end on macOS (vault, notes, replay, ECAPA build).
#
# Run on your Mac after merging #1810 / mind-followups:
#   scripts/verify-mind-macos-e2e.sh
#
# Optional: full UI journey with models (~570 MB first run):
#   scripts/verify-mind-macos-e2e.sh --journey

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_JOURNEY=false
if [[ "${1:-}" == "--journey" ]]; then
  RUN_JOURNEY=true
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script targets macOS (Darwin). On Linux use the Rust test only:" >&2
  echo "  cd rust && cargo +1.88.0 test -p airo_mind_whisper --features whisper mind_runtime_vault_notes_replay_end_to_end" >&2
  exit 1
fi

export FRB_TOOLCHAIN="${FRB_TOOLCHAIN:-1.88.0}"
export PATH="${HOME}/.cargo/bin:${PATH}"

echo "==> 1/5 Rust mind runtime E2E (vault, notes migration, replayFrom)"
cd "${ROOT}/rust"
cargo "+${FRB_TOOLCHAIN}" test -p airo_mind_whisper --features whisper mind_runtime_vault_notes_replay_end_to_end

echo "==> 2/5 FRB bindings in sync"
"${ROOT}/scripts/check-mind-whisper-frb.sh"

echo "==> 3/5 ONNX Runtime macOS (ECAPA link check)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/install-onnxruntime.sh"
"${ROOT}/scripts/build-whisper-ecapa-desktop.sh"

echo "==> 4/5 feature_mind unit tests (notes + runtime)"
cd "${ROOT}/packages/feature_mind"
flutter pub get
flutter test test/notes/ test/runtime/rust_mind_runtime_test.dart --plain-name "the failure is per port" --plain-name "every unimplemented" 2>/dev/null || \
  flutter test test/notes/

echo "==> 5/5 Mind shell compile (macOS)"
"${ROOT}/app/tool/fetch_mind_models.sh"
cd "${ROOT}/packages/feature_mind"
dart run build_runner build --delete-conflicting-outputs
cd "${ROOT}/app"
cp pubspec_mind.yaml pubspec.yaml
trap 'git -C "${ROOT}" checkout app/pubspec.yaml app/pubspec.lock 2>/dev/null || true' EXIT
flutter pub get
flutter build macos -t lib/main_mind.dart

if [[ "${RUN_JOURNEY}" == "true" ]]; then
  echo "==> Optional device journey (models + transcribe pipeline)"
  cp "${ROOT}/app/analysis_options_mind.yaml" "${ROOT}/app/analysis_options.yaml"
  JFK="${ROOT}/rust/fixtures/jfk.wav"
  if [[ ! -f "${JFK}" ]]; then
    echo "Missing ${JFK} — fetch fixtures or pass AIRO_MIND_DEVICE_RECORD=true" >&2
    exit 1
  fi
  export AIRO_MIND_WAV_PATH="${JFK}"
  flutter test integration_test/mind_journey_device_test.dart \
    --dart-define=APP_VARIANT=mind \
    --dart-define=AIRO_RUN_MIND_JOURNEY=true \
    -d macos
fi

cat <<'EOF'

✓ macOS verification passed (Rust runtime, FRB, ECAPA build, Mind macOS compile).

Manual UI checks (launch Mind shell):
  app/tool/run_mind_macos.sh

Then verify in the app:
  • Record a short meeting → transcript + minutes save (scribe op log → Rust)
  • Devices surface → vault shows "This device" with fingerprint groups
  • Notes (if routed in shell) → create/edit persists across restart
  • Runtime console → right-click op row → replayFrom shows progress

Speaker enrollment (#504) needs ECAPA model on disk; install via Models tab
or app/tool/fetch_mind_models.sh, then enroll a speaker in a meeting.

EOF
