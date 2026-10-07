#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
fake_home="$test_root/home"
backup_root="$test_root/backups"
mkdir -p "$fake_home/.config/nvim"
printf 'old\n' >"$fake_home/.config/nvim/old.lua"

required_files=(
  nvim/.config/nvim/init.lua
  nvim/.config/nvim/lazy-lock.json
  kitty/.config/kitty/kitty.conf
  zsh/.zshrc
  zsh/.p10k.zsh
  zsh/.config/shell/env.sh
  zsh/.config/zsh/ros.zsh
  vscode/.config/Code/User/settings.json
  vscode/.config/Code/User/keybindings.json
  vscode/extensions.txt
  git/.gitconfig
)
for required in "${required_files[@]}"; do
  [[ -f $repo_root/$required ]] || {
    printf 'missing required file: %s\n' "$required" >&2
    exit 1
  }
done

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
[[ ! -e $fake_home/.config/kitty/kitty.conf ]]

if HOME="$fake_home" "$repo_root/install.sh" does-not-exist >/dev/null 2>&1; then
  printf 'unknown module unexpectedly succeeded\n' >&2
  exit 1
fi

if find "$repo_root" -type f \( \
  -name 'state.vscdb*' -o -name '*.db' -o -name '*History*' -o \
  -name 'agent-sessions.code-workspace' -o -name 'credentials' \
\) -print -quit | grep -q .; then
  printf 'private machine state found in repository\n' >&2
  exit 1
fi

if rg -l --hidden -g '!.git/**' \
  '(github_pat_|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY)' \
  "$repo_root/nvim" "$repo_root/kitty" "$repo_root/zsh" \
  "$repo_root/vscode" "$repo_root/git" | grep -q .; then
  printf 'likely credential found in repository\n' >&2
  exit 1
fi

printf 'layout tests passed\n'
