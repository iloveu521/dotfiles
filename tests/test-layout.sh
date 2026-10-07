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
  gnome/settings.dconf
  gnome/apply.sh
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

# A late backup conflict must not leave earlier targets partially installed.
atomic_home="$test_root/atomic-home"
atomic_backup="$test_root/atomic-backup"
mkdir -p "$atomic_home/.config/nvim" "$atomic_backup"
printf 'original nvim\n' >"$atomic_home/.config/nvim/init.lua"
printf 'original git\n' >"$atomic_home/.gitconfig"
printf 'occupied\n' >"$atomic_backup/.gitconfig"
if HOME="$atomic_home" "$repo_root/install.sh" --backup-dir "$atomic_backup" nvim git >/dev/null 2>&1; then
  printf 'backup conflict unexpectedly succeeded\n' >&2
  exit 1
fi
[[ ! -L $atomic_home/.config/nvim ]]
grep -Fqx 'original nvim' "$atomic_home/.config/nvim/init.lua"
grep -Fqx 'original git' "$atomic_home/.gitconfig"

if find "$repo_root" -type f \( \
  -name 'state.vscdb*' -o -name '*.db' -o -name '*History*' -o \
  -name 'agent-sessions.code-workspace' -o -name 'credentials' \
\) -print -quit | grep -q .; then
  printf 'private machine state found in repository\n' >&2
  exit 1
fi

if rg -l --hidden -g '!.git/**' \
  '(github_pat_|ghp_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|npm_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY)' \
  "$repo_root/nvim" "$repo_root/kitty" "$repo_root/zsh" \
  "$repo_root/vscode" "$repo_root/git" | grep -q .; then
  printf 'likely credential found in repository\n' >&2
  exit 1
fi

if rg -n '/home/[A-Za-z0-9._-]+/' \
  "$repo_root/nvim" "$repo_root/kitty" "$repo_root/zsh" \
  "$repo_root/vscode" "$repo_root/git" >/dev/null; then
  printf 'machine-specific home path found in portable modules\n' >&2
  exit 1
fi

if grep -Eq '^export ROS_DOMAIN_ID=' "$repo_root/zsh/.config/shell/env.sh"; then
  printf 'ROS domain must not be enabled globally\n' >&2
  exit 1
fi
grep -Fq 'ROS_DOMAIN_ID_OVERRIDE' "$repo_root/zsh/.config/zsh/ros.zsh"
if grep -Fq 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' "$repo_root/zsh/.config/shell/env.sh"; then
  printf 'optional Neovim path must be conditional\n' >&2
  exit 1
fi

allowed_gnome_sections='^\[(org/gnome/desktop/interface|org/gnome/desktop/wm/preferences|org/gnome/shell/extensions/blur-my-shell/applications)\]$'
if grep '^\[' "$repo_root/gnome/settings.dconf" | grep -Ev "$allowed_gnome_sections" | grep -q .; then
  printf 'unexpected GNOME dconf section found\n' >&2
  exit 1
fi

gnome_dry_run=$("$repo_root/gnome/apply.sh" --dry-run)
grep -Fq 'org/gnome/desktop/interface' <<<"$gnome_dry_run"
grep -Fq 'blur-my-shell/applications' <<<"$gnome_dry_run"
grep -Fq "whitelist=['kitty']" "$repo_root/gnome/settings.dconf"
grep -Fq 'opacity=235' "$repo_root/gnome/settings.dconf"

if BLUR_MY_SHELL_SCHEMA_DIR="$test_root/missing-schema" \
  "$repo_root/gnome/apply.sh" --dry-run >/dev/null 2>&1; then
  printf 'missing Blur My Shell schema unexpectedly succeeded\n' >&2
  exit 1
fi

bad_gnome_settings="$test_root/bad-settings.dconf"
cp -- "$repo_root/gnome/settings.dconf" "$bad_gnome_settings"
printf '\n[org/gnome/shell]\nenabled-extensions=[]\n' >>"$bad_gnome_settings"
if GNOME_SETTINGS_FILE="$bad_gnome_settings" \
  "$repo_root/gnome/apply.sh" --dry-run >/dev/null 2>&1; then
  printf 'unexpected GNOME section was not rejected at runtime\n' >&2
  exit 1
fi

bad_gnome_key="$test_root/bad-key.dconf"
cp -- "$repo_root/gnome/settings.dconf" "$bad_gnome_key"
printf 'unexpected-key=true\n' >>"$bad_gnome_key"
if GNOME_SETTINGS_FILE="$bad_gnome_key" \
  "$repo_root/gnome/apply.sh" --dry-run >/dev/null 2>&1; then
  printf 'unexpected GNOME key was not rejected at runtime\n' >&2
  exit 1
fi

printf 'layout tests passed\n'
