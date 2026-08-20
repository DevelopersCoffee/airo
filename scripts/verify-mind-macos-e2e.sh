#!/usr/bin/env bash
# Verifies Mind runtime follow-ups end-to-end (vault, notes, replay, ECAPA build).
#
# macOS (full native stack):
#   scripts/verify-mind-macos-e2e.sh
#   scripts/verify-mind-macos-e2e.sh --journey   # + transcribe pipeline (~570 MB)
#
# Linux / CI (Rust runtime + optional browser smoke):
#   scripts/verify-mind-macos-e2e.sh --linux
#   scripts/verify-mind-macos-e2e.sh --linux --browser
#
# After automated checks pass on macOS, launch the GUI for manual UI proof:
#   app/tool/run_mind_macos.sh
#
# Real meeting recordings (default ~/Documents/data):
#   scripts/mind-meeting-recordings.sh list
#   scripts/mind-meeting-recordings.sh transcribe short
#   scripts/mind-meeting-recordings.sh analyze
#
# Known gaps (not covered here — separate follow-ups):
#   • Qwen 0.5B cannot summarize 74+ min transcripts (2048 ctx; needs chunking).
#   • Whisper tiny loops on long meetings; use small/base + chunking for prod quality.
#   • Speaker enroll (#504) and Devices (#1592) need on-device GUI verification.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_JOURNEY=false
RUN_LINUX=false
RUN_BROWSER=false

for arg in "$@"; do
  case "$arg" in
    --journey) RUN_JOURNEY=true ;;
    --linux) RUN_LINUX=true ;;
    --browser) RUN_BROWSER=true ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

export FRB_TOOLCHAIN="${FRB_TOOLCHAIN:-1.88.0}"
export PATH="${HOME}/.cargo/bin:${PATH}"

run_rust_e2e() {
  echo "==> Rust mind runtime E2E (vault, notes migration, replayFrom)"
  cd "${ROOT}/rust"
  cargo "+${FRB_TOOLCHAIN}" test -p airo_mind_whisper --features whisper mind_runtime_vault_notes_replay_end_to_end
}

if [[ "${RUN_LINUX}" == "true" ]] || [[ "$(uname -s)" != "Darwin" ]]; then
  run_rust_e2e
  if [[ "${RUN_BROWSER}" == "true" ]]; then
    echo "==> Mind web smoke (Playwright)"
    "${ROOT}/scripts/validate_airo_mind_browser.sh"
  fi
  cat <<'EOF'

✓ Linux verification passed (Rust runtime E2E).

For native vault UI, Devices surface, Notes persist, Runtime Console replayFrom,
and speaker enroll (#504), run on macOS:
  scripts/verify-mind-macos-e2e.sh
  app/tool/run_mind_macos.sh

EOF
  exit 0
fi

echo "==> 1/5 Rust mind runtime E2E"
run_rust_e2e

echo "==> 2/5 FRB bindings in sync"
"${ROOT}/scripts/check-mind-whisper-frb.sh"

echo "==> 3/5 ONNX Runtime macOS (ECAPA link check)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/install-onnxruntime.sh"
"${ROOT}/scripts/build-whisper-ecapa-desktop.sh"

echo "==> 4/5 feature_mind unit tests (notes)"
cd "${ROOT}/packages/feature_mind"
flutter pub get
flutter test test/notes/

echo "==> 5/5 Mind shell compile (macOS)"
# Homebrew rustc on PATH shadows rustup and breaks cargokit x86_64 cross-builds.
if command -v rustup >/dev/null 2>&1; then
  export RUSTC="$(rustup which rustc)"
fi
unset CARGO_TARGET_DIR
# install-onnxruntime.sh sets ORT_LIB_LOCATION for the host arch; cargokit must
# resolve per-target ORT paths when building universal macOS slices.
unset ORT_LIB_LOCATION
# ECAPA ONNX static libs are single-arch; skip the x86_64 slice on Apple Silicon.
if [[ "$(uname -m)" == "arm64" ]]; then
  export ARCHS=arm64
fi
"${ROOT}/app/tool/fetch_mind_models.sh"
cd "${ROOT}/packages/feature_mind"
dart run build_runner build --delete-conflicting-outputs
cd "${ROOT}/app"
cp pubspec_mind.yaml pubspec.yaml
cp "${ROOT}/app/tool/mind_macos_pubspec_overrides.yaml" pubspec_overrides.yaml
trap 'git -C "${ROOT}" checkout app/pubspec.yaml app/pubspec.lock 2>/dev/null || true; rm -f "${ROOT}/app/pubspec_overrides.yaml"' EXIT
flutter pub get
flutter build macos -t lib/main_mind.dart \
  --dart-define=APP_VARIANT=mind \
  --dart-define=AIRO_MIND_DESKTOP=true

if [[ "${RUN_JOURNEY}" == "true" ]]; then
  echo "==> Optional journey (models + transcribe; use short audio — tiny loops on 70+ min)"
  cp "${ROOT}/app/analysis_options_mind.yaml" "${ROOT}/app/analysis_options.yaml"
  JFK="${ROOT}/rust/fixtures/jfk.wav"
  if [[ ! -f "${JFK}" ]]; then
    echo "Missing ${JFK} — fetch fixtures or pass AIRO_MIND_DEVICE_RECORD=true" >&2
    exit 1
  fi
  export AIRO_MIND_WAV_PATH="${JFK}"
  flutter test integration_test/mind_journey_device_test.dart \
    --dart-define=APP_VARIANT=mind \
    --dart-define=AIRO_MIND_DESKTOP=true \
    --dart-define=AIRO_RUN_MIND_JOURNEY=true \
    -d macos
fi

cat <<'EOF'

✓ macOS automated verification passed (Rust runtime, FRB, ECAPA build, Mind compile).

Manual UI checklist — launch:
  app/tool/run_mind_macos.sh

  Window > Mind Runtime… (or /runtime):
  [ ] Devices: "This device" + fingerprint groups (#1592 / vault UI)
  [ ] Notes: create → restart app → note still there (Rust notes log)
  [ ] Runtime console: right-click op → replayFrom progress (#1216)

  Scribe tab:
  [ ] Record short meeting → transcript + minutes persist (#1213)
  [ ] Speaker: enroll with ECAPA model → recognized in next meeting (#504)

Long meetings (74 min Voice Memo): decode is fine; prefer small/base ASR +
chunked LLM (--out / GUI meeting intelligence). Legacy CLI auto-chunks when
transcript exceeds Qwen context.

Real device recordings (default ~/Documents/data):
  scripts/mind-meeting-recordings.sh list
  scripts/mind-meeting-recordings.sh transcribe short
  scripts/mind-meeting-recordings.sh analyze

Optional browser E2E + branding (shell routes, flow checklist, PNGs):
  scripts/validate_airo_mind_browser.sh
  scripts/validate_airo_mind_browser.sh --e2e
  scripts/validate_airo_mind_browser.sh --branding

EOF
