#!/bin/bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: tool/flutter_with_open_retry.sh <flutter args...>" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
shim_dir="$(mktemp -d "${TMPDIR:-/tmp}/flutter-open-retry.XXXXXX")"

cleanup() {
  rm -rf "${shim_dir}"
}
trap cleanup EXIT

cat >"${shim_dir}/open" <<'EOF'
#!/bin/bash

set -euo pipefail

real_open="/usr/bin/open"
status=0

"${real_open}" "$@" || status=$?

if [[ ${status} -eq 0 ]]; then
  exit 0
fi

should_retry=0
for arg in "$@"; do
  if [[ "${arg}" == *.app || "${arg}" == */*.app ]]; then
    should_retry=1
    break
  fi
done

if [[ ${should_retry} -eq 0 ]]; then
  exit "${status}"
fi

sleep 1
exec "${real_open}" "$@"
EOF

chmod +x "${shim_dir}/open"

cd "${repo_root}/app"
PATH="${shim_dir}:${PATH}" flutter "$@"
