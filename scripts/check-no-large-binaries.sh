#!/usr/bin/env bash
# Guard: fail on new/changed tracked files matching banned binary classes
# or larger than 10MB unless explicitly allowlisted.
# Usage: scripts/check-no-large-binaries.sh [--staged|--head]
#   --staged (default): check files staged in the index (pre-commit / CI on PR).
#   --head: check all files at HEAD (audit mode).
# CI wiring (GitHub Actions): run `bash scripts/check-no-large-binaries.sh --staged`
#   on pull_request and `bash scripts/check-no-large-binaries.sh --head` on push.
# See .github/workflows/guard-binaries.yml.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MODE="${1:---staged}"
MAX_BYTES=$((10 * 1024 * 1024))

# HEAD-required binaries that are exempt from the size gate.
# Do NOT extend without owner approval. No LFS (billing constrained).
ALLOWLIST=(
  "libs/ai_sd-release.aar"
  "libs/ai_sherpa-release.aar"
  "libs/gguf_lib-release.aar"
  "libs/tn_security-release.aar"
  "plugins/expense/model.onnx"
  "networking/src/main/cpp/prebuilts/arm64-v8a/libcurl-impersonate-chrome.so"
  "networking/src/main/cpp/prebuilts/x86_64/libcurl-impersonate-chrome.so"
  "app/src/main/res/raw/credits.mp3"
)

is_allowlisted() {
  local f="$1" a
  for a in "${ALLOWLIST[@]}"; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

# Banned classes: generated / release / downloadable-weight artifacts.
is_banned_class() {
  local f="$1"
  [[ "$f" == repo/* ]] && return 0
  [[ "$f" == app/release/* ]] && return 0
  [[ "$f" == bootstrap* ]] && return 0
  [[ "$f" == *build/* ]] && return 0
  [[ "$f" == *.cxx/* ]] && return 0
  [[ "$f" == *.externalNativeBuild/* ]] && return 0
  [[ "$f" == *.apk ]] && return 0
  [[ "$f" == *.aab ]] && return 0
  [[ "$f" == *.zip ]] && return 0
  [[ "$f" == *.gguf ]] && return 0
  [[ "$f" == *.safetensors ]] && return 0
  [[ "$f" == *.pt ]] && return 0
  return 1
}

if [[ "$MODE" == "--head" ]]; then
  mapfile -t FILES < <(git ls-files)
else
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM)
fi

fail=0
for f in "${FILES[@]:-}"; do
  [[ -z "$f" ]] && continue
  if is_allowlisted "$f"; then
    continue
  fi
  if is_banned_class "$f"; then
    echo "BLOCKED (banned class): $f" >&2
    fail=1
    continue
  fi
  if [[ -f "$f" ]]; then
    size=$(wc -c <"$f")
    if (( size > MAX_BYTES )); then
      echo "BLOCKED (>10MB, not allowlisted): $f (${size} bytes)" >&2
      fail=1
    fi
  fi
done

if (( fail )); then
  echo "check-no-large-binaries: FAILED. Use GitHub Releases for artifacts; fetch models at build time." >&2
  exit 1
fi
echo "check-no-large-binaries: OK (${#FILES[@]} files checked, mode=$MODE)."
