#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
target_home=${HOME:-}
backup_root=
dry_run=false

usage() {
  printf 'Usage: %s [--dry-run] [--backup-dir PATH] [MODULE ...]\n' "${0##*/}"
  printf 'Modules: nvim kitty zsh vscode git\n'
}

while (($#)); do
  case $1 in
    --dry-run) dry_run=true; shift ;;
    --backup-dir)
      (($# >= 2)) || { printf 'error: --backup-dir requires a path\n' >&2; exit 2; }
      backup_root=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) break ;;
  esac
done

[[ -n $target_home && $target_home == /* && $target_home != / ]] || {
  printf 'error: HOME must be an absolute, non-root path\n' >&2
  exit 2
}
if [[ -z $backup_root ]]; then
  backup_root="$target_home/.local/state/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
fi

all_modules=(nvim kitty zsh vscode git)
if (($#)); then
  modules=("$@")
else
  modules=("${all_modules[@]}")
fi

module_items() {
  case $1 in
    nvim) printf '%s\n' '.config/nvim' ;;
    kitty) printf '%s\n' '.config/kitty' ;;
    zsh) printf '%s\n' '.zshrc' '.p10k.zsh' '.config/shell' '.config/zsh' ;;
    vscode) printf '%s\n' '.config/Code/User/settings.json' '.config/Code/User/keybindings.json' ;;
    git) printf '%s\n' '.gitconfig' ;;
    *) return 1 ;;
  esac
}

for module in "${modules[@]}"; do
  module_items "$module" >/dev/null || {
    printf 'error: unknown module: %s\n' "$module" >&2
    exit 2
  }
done

link_item() {
  local module=$1 relative=$2
  local source_path="$repo_root/$module/$relative"
  local destination="$target_home/$relative"
  local backup_path="$backup_root/$relative"

  [[ -e $source_path || -L $source_path ]] || {
    printf 'error: module payload is missing: %s\n' "$source_path" >&2
    exit 1
  }
  if [[ -L $destination && $(readlink -f -- "$destination") == $(readlink -f -- "$source_path") ]]; then
    printf 'ok: %s\n' "$destination"
    return
  fi

  if [[ -e $destination || -L $destination ]]; then
    printf 'backup: %s -> %s\n' "$destination" "$backup_path"
    if ! $dry_run; then
      mkdir -p -- "$(dirname "$backup_path")"
      [[ ! -e $backup_path && ! -L $backup_path ]] || {
        printf 'error: backup target already exists: %s\n' "$backup_path" >&2
        exit 1
      }
      mv -- "$destination" "$backup_path"
    fi
  fi

  printf 'link: %s -> %s\n' "$destination" "$source_path"
  if ! $dry_run; then
    mkdir -p -- "$(dirname "$destination")"
    ln -s -- "$source_path" "$destination"
  fi
}

for module in "${modules[@]}"; do
  while IFS= read -r relative; do
    link_item "$module" "$relative"
  done < <(module_items "$module")
done
