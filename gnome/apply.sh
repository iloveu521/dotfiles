#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
settings_file="$module_root/settings.dconf"
dry_run=false

case ${1:-} in
  '') ;;
  --dry-run) dry_run=true ;;
  -h|--help)
    printf 'Usage: %s [--dry-run]\n' "${0##*/}"
    exit 0
    ;;
  *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

command -v dconf >/dev/null || { printf 'error: dconf is required\n' >&2; exit 1; }
command -v gsettings >/dev/null || { printf 'error: gsettings is required\n' >&2; exit 1; }
[[ -f $settings_file ]] || { printf 'error: missing %s\n' "$settings_file" >&2; exit 1; }

for schema in org.gnome.desktop.interface org.gnome.desktop.wm.preferences; do
  gsettings list-schemas | grep -Fxq "$schema" || {
    printf 'error: required GNOME schema is unavailable: %s\n' "$schema" >&2
    exit 1
  }
done

if $dry_run; then
  printf 'would apply these reviewed dconf settings from %s:\n' "$settings_file"
  cat "$settings_file"
  exit 0
fi

dconf load / <"$settings_file"
printf 'applied GNOME interface, window, and Blur My Shell settings\n'
