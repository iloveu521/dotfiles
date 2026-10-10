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
  kitty/.config/kitty/toggle_decorations.py
  zsh/.zshrc
  zsh/.p10k.zsh
  zsh/.config/shell/env.sh
  zsh/.config/zsh/ros.zsh
  vscode/.config/Code/User/settings.json
  vscode/.config/Code/User/keybindings.json
  vscode/extensions.txt
  git/.gitconfig
  codex/.codex/AGENTS.md
  codex/.codex/skills/knowledge-capture/SKILL.md
  codex/.codex/skills/knowledge-capture/agents/openai.yaml
  codex/workspace/blog/hugo/dev/AGENTS.md
  gnome/settings.dconf
  gnome/apply.sh
)
for required in "${required_files[@]}"; do
  [[ -f $repo_root/$required ]] || {
    printf 'missing required file: %s\n' "$required" >&2
    exit 1
  }
done

# Kitty must resolve the requested function keys to their intended actions.
KITTY_CONFIG_UNDER_TEST="$repo_root/kitty/.config/kitty/kitty.conf" kitty +runpy '
import os
import runpy
from kitty.config import load_config
from kitty.fast_data_types import set_options
from kitty.options.utils import parse_shortcut

opts = load_config(os.environ["KITTY_CONFIG_UNDER_TEST"])
if not opts.remember_window_size:
    raise SystemExit("Kitty must remember the window size")
if opts.initial_window_width != (216, "cells") or opts.initial_window_height != (55, "cells"):
    raise SystemExit("Kitty initial window size must be 216x55 cells")
right_click_actions = {
    event.grabbed: action
    for event, action in opts.mousemap.items()
    if event.button == 1 and event.mods == 0 and event.repeat_count == -2
}
if right_click_actions != {False: "paste_from_clipboard", True: "paste_from_clipboard"}:
    raise SystemExit("Kitty right-click must paste from the clipboard")
keymap = opts.keyboard_modes[""].keymap
expected = {
    "f1": "toggle_maximized",
    "f2": "kitten toggle_decorations.py",
    "f3": "new_tab_with_cwd",
}
for shortcut, action in expected.items():
    definitions = keymap.get(parse_shortcut(shortcut), ())
    found = False
    for definition in definitions:
        if definition.definition == action:
            found = True
            break
    if not found:
        raise SystemExit(f"missing Kitty mapping: {shortcut} -> {action}")

# The no-UI kitten must alternate between hiding and showing OS decorations.
toggle = runpy.run_path(
    os.path.join(os.path.dirname(os.environ["KITTY_CONFIG_UNDER_TEST"]), "toggle_decorations.py")
)["handle_result"]

class Boss:
    def __init__(self):
        self.calls = []

    def load_config_file(self, *args, **kwargs):
        self.calls.append((args, kwargs))

boss = Boss()
set_options(opts, True)
toggle(("toggle_decorations.py",), {}, 1, boss)
if boss.calls[-1][1]["overrides"] != ("hide_window_decorations yes",):
    raise SystemExit("decoration toggle did not hide a visible title bar")

opts.hide_window_decorations = 1
set_options(opts, True)
toggle(("toggle_decorations.py",), {}, 1, boss)
if boss.calls[-1][1]["overrides"] != ("hide_window_decorations no",):
    raise SystemExit("decoration toggle did not show a hidden title bar")
'

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

codex_home="$test_root/codex-home"
codex_backup="$test_root/codex-backup"
HOME="$codex_home" "$repo_root/install.sh" --backup-dir "$codex_backup" codex
for relative in \
  .codex/AGENTS.md \
  .codex/skills/knowledge-capture/SKILL.md \
  .codex/skills/knowledge-capture/agents/openai.yaml \
  workspace/blog/hugo/dev/AGENTS.md; do
  assert_link "$codex_home/$relative" "$repo_root/codex/$relative"
done
HOME="$codex_home" "$repo_root/install.sh" --backup-dir "$codex_backup" codex
[[ ! -e $codex_backup/.codex/AGENTS.md && ! -L $codex_backup/.codex/AGENTS.md ]]

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

# Repeated modules must fail before touching targets or creating backups.
duplicate_git_home="$test_root/duplicate-git-home"
duplicate_git_backup="$test_root/duplicate-git-backup"
mkdir -p "$duplicate_git_home"
printf 'original duplicate git\n' >"$duplicate_git_home/.gitconfig"
if HOME="$duplicate_git_home" "$repo_root/install.sh" \
  --backup-dir "$duplicate_git_backup" git git >/dev/null 2>&1; then
  printf 'duplicate git module unexpectedly succeeded\n' >&2
  exit 1
fi
grep -Fqx 'original duplicate git' "$duplicate_git_home/.gitconfig"
[[ ! -e $duplicate_git_backup/.gitconfig && ! -L $duplicate_git_backup/.gitconfig ]]

duplicate_vscode_home="$test_root/duplicate-vscode-home"
duplicate_vscode_backup="$test_root/duplicate-vscode-backup"
mkdir -p "$duplicate_vscode_home/.config/Code/User"
printf 'original vscode\n' >"$duplicate_vscode_home/.config/Code/User/settings.json"
if HOME="$duplicate_vscode_home" "$repo_root/install.sh" \
  --backup-dir "$duplicate_vscode_backup" vscode vscode >/dev/null 2>&1; then
  printf 'duplicate vscode module unexpectedly succeeded\n' >&2
  exit 1
fi
grep -Fqx 'original vscode' "$duplicate_vscode_home/.config/Code/User/settings.json"
[[ ! -e $duplicate_vscode_backup/.config/Code/User/settings.json ]]

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
  "$repo_root/vscode" "$repo_root/git" "$repo_root/codex" | grep -q .; then
  printf 'likely credential found in repository\n' >&2
  exit 1
fi

if rg -n '/home/[A-Za-z0-9._-]+/' \
  "$repo_root/nvim" "$repo_root/kitty" "$repo_root/zsh" \
  "$repo_root/vscode" "$repo_root/git" "$repo_root/codex" >/dev/null; then
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
zsh -fc '
  unset ROS_DOMAIN_ID
  source "$1"
  [[ -z ${ROS_DOMAIN_ID+x} ]]
  ROS_DISTRO_SETUP=/dev/null ROS_DOMAIN_ID_OVERRIDE=77 rosenv /tmp/no-overlay
  [[ $ROS_DOMAIN_ID == 77 ]]
' _ "$repo_root/zsh/.config/zsh/ros.zsh"

ROS_ROOT="$repo_root/tests/fixtures/ros/ros" ROS_DISTRO=jazzy zsh -fc '
  source "$1"
  rosenv /tmp/no-overlay
  [[ $ROS_DISTRO == humble ]]
  [[ $ROS_VERSION == 2 ]]
' _ "$repo_root/zsh/.config/zsh/ros.zsh"

allowed_gnome_sections='^\[(org/gnome/desktop/interface|org/gnome/desktop/wm/preferences|org/gnome/mutter|org/gnome/desktop/wm/keybindings|org/gnome/shell/extensions/blur-my-shell/applications)\]$'
if grep '^\[' "$repo_root/gnome/settings.dconf" | grep -Ev "$allowed_gnome_sections" | grep -q .; then
  printf 'unexpected GNOME dconf section found\n' >&2
  exit 1
fi

gnome_dry_run=$("$repo_root/gnome/apply.sh" --dry-run)
grep -Fq 'org/gnome/desktop/interface' <<<"$gnome_dry_run"
grep -Fq 'blur-my-shell/applications' <<<"$gnome_dry_run"
grep -Fq 'org/gnome/mutter' <<<"$gnome_dry_run"
grep -Fq 'auto-maximize=false' <<<"$gnome_dry_run"
grep -Fq 'org/gnome/desktop/wm/keybindings' <<<"$gnome_dry_run"
grep -Fq "minimize=['F4', '<Super>h']" <<<"$gnome_dry_run"
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
