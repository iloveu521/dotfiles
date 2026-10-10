# ROS 2 environment helper. Nothing is sourced until rosenv runs.
function rosenv() {
  local workspace="${1:-$PWD}"
  local ros_root="${ROS_ROOT:-/opt/ros}"
  local distro="${ROS_DISTRO:-}"
  local distro_setup="${ROS_DISTRO_SETUP:-}"
  local expected_distro=
  local os_version=
  local -a candidates

  # An explicit setup path always wins, which keeps this helper usable for
  # tests and non-standard ROS installations.
  if [[ -z "$distro_setup" ]]; then
    if [[ -n "$distro" && -r "$ros_root/$distro/setup.zsh" ]]; then
      distro_setup="$ros_root/$distro/setup.zsh"
    else
      # Prefer the ROS release paired with the Ubuntu release. If the distro
      # is not installed, fall back to the only installed setup script.
      os_version="$(sed -n 's/^VERSION_ID="\{0,1\}\([^" ]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null | head -n 1)"
      case "$os_version" in
        24.04) expected_distro=jazzy ;;
        22.04) expected_distro=humble ;;
        20.04) expected_distro=foxy ;;
      esac
      if [[ -n "$expected_distro" && -r "$ros_root/$expected_distro/setup.zsh" ]]; then
        distro_setup="$ros_root/$expected_distro/setup.zsh"
      else
        candidates=("$ros_root"/*/setup.zsh(N))
        if (( ${#candidates} == 1 )); then
          distro_setup="${candidates[1]}"
        elif (( ${#candidates} > 1 )); then
          print -u2 -- "rosenv: multiple ROS distros found under $ros_root; set ROS_DISTRO"
          return 1
        fi
      fi
    fi
  fi

  if [[ ! -r "$distro_setup" ]]; then
    print -u2 -- "rosenv: cannot read $distro_setup"
    return 1
  fi

  if [[ -z "${ROS_DISTRO_SETUP:-}" ]]; then
    export ROS_DISTRO="${distro_setup:h:t}"
  fi
  source "$distro_setup" || return
  if [[ -r "$workspace/install/setup.zsh" ]]; then
    source "$workspace/install/setup.zsh" || return
  fi

  export ROS_DOMAIN_ID="${ROS_DOMAIN_ID_OVERRIDE:-${ROS_DOMAIN_ID:-42}}"
}
