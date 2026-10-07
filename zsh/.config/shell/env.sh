# Environment shared by interactive Bash and Zsh.

_shell_path_prepend() {
    [ -d "$1" ] || return 0
    case ":${PATH-}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

_shell_path_append() {
    [ -d "$1" ] || return 0
    case ":${PATH-}:" in
        *":$1:"*) ;;
        *) PATH="${PATH:+$PATH:}$1" ;;
    esac
}

_shell_path_prepend "$HOME/.npm-global/bin"
_shell_path_prepend /usr/local/cuda/bin
_shell_path_append /opt/linux-wallpaperengine
export PATH

if [ -d /usr/local/cuda ]; then
    export CUDA_HOME=/usr/local/cuda
fi

if [ -d /usr/local/cuda/lib64 ]; then
    case ":${LD_LIBRARY_PATH-}:" in
        *:/usr/local/cuda/lib64:*) ;;
        *) LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
    export LD_LIBRARY_PATH
fi

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export NVM_DIR="$HOME/.nvm"
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80
export ROS_DOMAIN_ID=42
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

unset -f _shell_path_prepend _shell_path_append
