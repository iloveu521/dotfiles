# Explicit ROS 2 Jazzy environment helper. Nothing is sourced until rosenv runs.
function rosenv() {
  local workspace="${1:-$PWD}"
  local distro_setup="${ROS_DISTRO_SETUP:-/opt/ros/jazzy/setup.zsh}"

  if [[ ! -r "$distro_setup" ]]; then
    print -u2 -- "rosenv: cannot read $distro_setup"
    return 1
  fi

  source "$distro_setup" || return
  if [[ -r "$workspace/install/setup.zsh" ]]; then
    source "$workspace/install/setup.zsh" || return
  fi

  export ROS_DOMAIN_ID="${ROS_DOMAIN_ID_OVERRIDE:-${ROS_DOMAIN_ID:-42}}"
}
