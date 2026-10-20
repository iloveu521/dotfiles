#####################################
#          Aliases
###################################
alias bat="batcat"
alias utc='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias cst='TZ=Asia/Shanghai date +"%Y-%m-%dT%H:%M:%S%:z"'

#################################
#         Functions
#################################

# 模糊搜索+预览代码+noevim
nvf() {
  local file
  file=$(fd --type f --hidden \
      --exclude .git \
      --exclude build \
     --exclude install \
      --exclude log \
      | fzf \
        --preview 'batcat --color=always --style=numbers --line-range=:500 {}' \
        --preview-window='right:60%:wrap'
    ) || return

  [[ -n "$file" ]] && nvim "$file"
}

# Git diff: bat 语法高亮
gdiff() {
  git diff --no-color "$@" |
    batcat --language=diff \
           --plain \
           --paging=always
}

# ROS 2: colcon build
rb() {
  colcon build --symlink-install "$@" \
    --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
}

# ROS 2: run
rr() {
  ros2 run "$@"
}

# ROS 2: launch
rl() {
  ros2 launch "$@"
}

# ROS 2: topic
rt() {
  ros2 topic "$@"
}


# claude code dangerous mode 
claude-d() {
  claude code --dangerously-skip-permissions "$@"
}
