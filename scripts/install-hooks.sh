#!/usr/bin/env bash
# Install versioned git hooks from .githooks/ into .git/hooks/.
set -euo pipefail
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit scripts/check-no-large-binaries.sh
echo "hooks installed."
