#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
fake_home="$test_root/home"
backup_root="$test_root/backups"
mkdir -p "$fake_home/.config/nvim" "$repo_root/nvim/.config/nvim" "$repo_root/git"
printf 'old\n' >"$fake_home/.config/nvim/old.lua"
printf 'new\n' >"$repo_root/nvim/.config/nvim/init.lua"
printf '[init]\n\tdefaultBranch = main\n' >"$repo_root/git/.gitconfig"

assert_link() {
  local path=$1 expected=$2
  [[ -L $path ]] || { printf 'not a symlink: %s\n' "$path" >&2; exit 1; }
  [[ $(readlink -f -- "$path") == "$expected" ]] || {
    printf 'wrong link: %s -> %s\n' "$path" "$(readlink -f -- "$path")" >&2
    exit 1
  }
}

HOME="$fake_home" "$repo_root/install.sh" --backup-dir "$backup_root" nvim git
assert_link "$fake_home/.config/nvim" "$repo_root/nvim/.config/nvim"
assert_link "$fake_home/.gitconfig" "$repo_root/git/.gitconfig"
[[ -f $backup_root/.config/nvim/old.lua ]]

# Re-running is idempotent and does not create another backup.
HOME="$fake_home" "$repo_root/install.sh" --backup-dir "$backup_root" nvim git
[[ $(find "$backup_root" -type f | wc -l) -eq 1 ]]

# Installing selected modules leaves other modules untouched.
mkdir -p "$repo_root/kitty/.config/kitty"
printf 'font_size 14\n' >"$repo_root/kitty/.config/kitty/kitty.conf"
[[ ! -e $fake_home/.config/kitty/kitty.conf ]]

if HOME="$fake_home" "$repo_root/install.sh" does-not-exist >/dev/null 2>&1; then
  printf 'unknown module unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'layout tests passed\n'
