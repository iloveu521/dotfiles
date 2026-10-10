#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
for columns in 80 120; do
  NVIM_CONFIG_UNDER_TEST="$repo_root/nvim/.config/nvim" \
    nvim --headless -u NONE -i NONE --cmd "set columns=$columns" \
      -l "$repo_root/tests/test-nvim-config.lua"
done
