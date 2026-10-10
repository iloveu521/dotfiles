#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
target_home=${HOME:-}
backup_root=
dry_run=false

usage() {
  printf 'Usage: %s [--dry-run] [--backup-dir PATH] [MODULE ...]\n' "${0##*/}"
  printf 'Modules: nvim kitty zsh vscode git codex\n'
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
[[ $backup_root == /* && $backup_root != / ]] || {
  printf 'error: backup directory must be an absolute, non-root path\n' >&2
  exit 2
}

all_modules=(nvim kitty zsh vscode git codex)
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
    codex)
      printf '%s\n' \
        '.codex/AGENTS.md' \
        '.codex/skills/knowledge-capture/SKILL.md' \
        '.codex/skills/knowledge-capture/agents/openai.yaml' \
        'workspace/blog/hugo/dev/AGENTS.md'
      ;;
    *) return 1 ;;
  esac
}

declare -A seen_modules
for module in "${modules[@]}"; do
  module_items "$module" >/dev/null || {
    printf 'error: unknown module: %s\n' "$module" >&2
    exit 2
  }
  [[ -z ${seen_modules[$module]:-} ]] || {
    printf 'error: duplicate module: %s\n' "$module" >&2
    exit 2
  }
  seen_modules["$module"]=1
done

# Build and validate the complete operation list before changing any target.
declare -a sources destinations backup_paths actions
declare -A seen_destinations
for module in "${modules[@]}"; do
  while IFS= read -r relative; do
    source_path="$repo_root/$module/$relative"
    destination="$target_home/$relative"
    backup_path="$backup_root/$relative"
    [[ -z ${seen_destinations[$destination]:-} ]] || {
      printf 'error: multiple modules target the same path: %s\n' "$destination" >&2
      exit 1
    }
    seen_destinations["$destination"]=1
    [[ -e $source_path || -L $source_path ]] || {
      printf 'error: module payload is missing: %s\n' "$source_path" >&2
      exit 1
    }

    action=link
    if [[ -L $destination && $(readlink -f -- "$destination") == $(readlink -f -- "$source_path") ]]; then
      action=skip
    elif [[ -e $destination || -L $destination ]]; then
      [[ ! -e $backup_path && ! -L $backup_path ]] || {
        printf 'error: backup target already exists: %s\n' "$backup_path" >&2
        exit 1
      }
      action=backup-link
    fi

    sources+=("$source_path")
    destinations+=("$destination")
    backup_paths+=("$backup_path")
    actions+=("$action")
  done < <(module_items "$module")
done

assert_writable_parent() {
  local candidate=$1
  while [[ ! -e $candidate && ! -L $candidate ]]; do
    candidate=$(dirname "$candidate")
  done
  [[ -d $candidate && -w $candidate ]] || {
    printf 'error: parent path is not a writable directory: %s\n' "$candidate" >&2
    exit 1
  }
}

for index in "${!destinations[@]}"; do
  [[ ${actions[$index]} == skip ]] && continue
  assert_writable_parent "$(dirname "${destinations[$index]}")"
  if [[ ${actions[$index]} == backup-link ]]; then
    assert_writable_parent "$(dirname "${backup_paths[$index]}")"
  fi
done

for index in "${!sources[@]}"; do
  source_path=${sources[$index]}
  destination=${destinations[$index]}
  backup_path=${backup_paths[$index]}
  action=${actions[$index]}

  if [[ $action == skip ]]; then
    printf 'ok: %s\n' "$destination"
    continue
  fi
  if [[ $action == backup-link ]]; then
    printf 'backup: %s -> %s\n' "$destination" "$backup_path"
    if ! $dry_run; then
      mkdir -p -- "$(dirname "$backup_path")"
      [[ ! -e $backup_path && ! -L $backup_path ]] || {
        printf 'error: backup target appeared during installation: %s\n' "$backup_path" >&2
        exit 1
      }
      mv -- "$destination" "$backup_path"
    fi
  fi

  printf 'link: %s -> %s\n' "$destination" "$source_path"
  if ! $dry_run; then
    mkdir -p -- "$(dirname "$destination")"
    [[ ! -e $destination && ! -L $destination ]] || {
      printf 'error: destination appeared during installation: %s\n' "$destination" >&2
      exit 1
    }
    ln -s -- "$source_path" "$destination"
  fi
done
