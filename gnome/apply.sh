#!/usr/bin/env bash
set -euo pipefail

module_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
settings_file=${GNOME_SETTINGS_FILE:-"$module_root/settings.dconf"}
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

command -v gsettings >/dev/null || { printf 'error: gsettings is required\n' >&2; exit 1; }
[[ -f $settings_file ]] || { printf 'error: missing %s\n' "$settings_file" >&2; exit 1; }

find_blur_schema_dir() {
  if [[ -n ${BLUR_MY_SHELL_SCHEMA_DIR:-} ]]; then
    printf '%s\n' "$BLUR_MY_SHELL_SCHEMA_DIR"
    return
  fi
  local candidate
  for candidate in \
    "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas" \
    /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas; do
    if [[ -f $candidate/gschemas.compiled ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

blur_schema_dir=$(find_blur_schema_dir) || {
  printf 'error: Blur My Shell compiled schema was not found\n' >&2
  exit 1
}
[[ -f $blur_schema_dir/gschemas.compiled ]] || {
  printf 'error: Blur My Shell compiled schema is unavailable: %s\n' "$blur_schema_dir" >&2
  exit 1
}

for schema in org.gnome.desktop.interface org.gnome.desktop.wm.preferences; do
  gsettings list-schemas | grep -Fxq "$schema" || {
    printf 'error: required GNOME schema is unavailable: %s\n' "$schema" >&2
    exit 1
  }
done
blur_schema=org.gnome.shell.extensions.blur-my-shell.applications
gsettings --schemadir "$blur_schema_dir" list-schemas | grep -Fxq "$blur_schema" || {
  printf 'error: required Blur My Shell schema is unavailable: %s\n' "$blur_schema" >&2
  exit 1
}

section_schema() {
  case $1 in
    org/gnome/desktop/interface) printf '%s\n' org.gnome.desktop.interface ;;
    org/gnome/desktop/wm/preferences) printf '%s\n' org.gnome.desktop.wm.preferences ;;
    org/gnome/shell/extensions/blur-my-shell/applications) printf '%s\n' "$blur_schema" ;;
    *) return 1 ;;
  esac
}

allowed_keys() {
  case $1 in
    org/gnome/desktop/interface)
      printf '%s\n' color-scheme cursor-theme font-name gtk-theme icon-theme monospace-font-name text-scaling-factor
      ;;
    org/gnome/desktop/wm/preferences)
      printf '%s\n' button-layout focus-mode theme
      ;;
    org/gnome/shell/extensions/blur-my-shell/applications)
      printf '%s\n' blur brightness color dynamic-opacity opacity pipeline sigma whitelist
      ;;
    *) return 1 ;;
  esac
}

declare -a entry_schemas entry_keys entry_values entry_schema_dirs
declare -A seen_sections
current_section=
while IFS= read -r raw_line || [[ -n $raw_line ]]; do
  line=${raw_line#"${raw_line%%[![:space:]]*}"}
  line=${line%"${line##*[![:space:]]}"}
  [[ -z $line || $line == \#* ]] && continue

  if [[ $line =~ ^\[(.+)\]$ ]]; then
    current_section=${BASH_REMATCH[1]}
    section_schema "$current_section" >/dev/null || {
      printf 'error: unapproved GNOME settings section: %s\n' "$current_section" >&2
      exit 1
    }
    seen_sections["$current_section"]=1
    continue
  fi

  [[ -n $current_section && $line =~ ^([a-z0-9-]+)=(.+)$ ]] || {
    printf 'error: invalid GNOME settings line: %s\n' "$raw_line" >&2
    exit 1
  }
  key=${BASH_REMATCH[1]}
  value=${BASH_REMATCH[2]}
  allowed_keys "$current_section" | grep -Fxq "$key" || {
    printf 'error: unapproved key in %s: %s\n' "$current_section" "$key" >&2
    exit 1
  }

  schema=$(section_schema "$current_section")
  schema_dir=
  if [[ $schema == "$blur_schema" ]]; then
    schema_dir=$blur_schema_dir
    gsettings --schemadir "$schema_dir" list-keys "$schema" | grep -Fxq "$key" || {
      printf 'error: key is unavailable in %s: %s\n' "$schema" "$key" >&2
      exit 1
    }
  else
    gsettings list-keys "$schema" | grep -Fxq "$key" || {
      printf 'error: key is unavailable in %s: %s\n' "$schema" "$key" >&2
      exit 1
    }
  fi
  entry_schemas+=("$schema")
  entry_keys+=("$key")
  entry_values+=("$value")
  entry_schema_dirs+=("$schema_dir")
done <"$settings_file"

for required_section in \
  org/gnome/desktop/interface \
  org/gnome/desktop/wm/preferences \
  org/gnome/shell/extensions/blur-my-shell/applications; do
  [[ -n ${seen_sections[$required_section]:-} ]] || {
    printf 'error: required GNOME settings section is missing: %s\n' "$required_section" >&2
    exit 1
  }
done

if $dry_run; then
  printf 'would apply these reviewed GNOME settings from %s:\n' "$settings_file"
  cat "$settings_file"
  exit 0
fi

for index in "${!entry_schemas[@]}"; do
  if [[ -n ${entry_schema_dirs[$index]} ]]; then
    gsettings --schemadir "${entry_schema_dirs[$index]}" set \
      "${entry_schemas[$index]}" "${entry_keys[$index]}" "${entry_values[$index]}"
  else
    gsettings set "${entry_schemas[$index]}" "${entry_keys[$index]}" "${entry_values[$index]}"
  fi
done
printf 'applied reviewed GNOME interface, window, and Blur My Shell settings\n'
