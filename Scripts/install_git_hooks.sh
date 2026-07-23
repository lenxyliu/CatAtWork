#!/bin/sh
set -eu

root=$(git rev-parse --show-toplevel)
git config core.hooksPath .githooks
chmod +x "$root/.githooks/pre-commit" "$root/.githooks/pre-push"
echo "Installed repository hooks from .githooks"
