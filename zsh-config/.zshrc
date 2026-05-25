# Apply matugen-generated terminal palette (直接读 colors.json,发 OSC 4/10/11/12)
# Material You → ANSI 16 映射跟 ~/.dotfiles/scripts/setwall.sh 一致。
# ★必须在 p10k instant prompt **之前**:instant prompt 会吞掉 .zshrc 期间的 stdout,
#  放后面 kitty 收不到 OSC,颜色就要等下次 setwall 才对。
() {
    local cf=~/.local/state/quickshell/user/generated/colors.json
    [[ -f $cf ]] && (( $+commands[jq] )) || return
    local -a c
    c=( "${(@f)$(jq -r '
        .background, .on_background, .primary,
        (.surface_container_lowest // .background),
        .error, .tertiary, .secondary, .primary,
        .tertiary_container, .primary_container, .on_surface,
        (.surface_container_low // .surface),
        .error_container,
        (.on_tertiary_container // .tertiary),
        (.on_secondary_container // .secondary),
        (.on_primary_container // .primary),
        (.tertiary_fixed // .tertiary),
        (.primary_fixed // .primary),
        (.inverse_surface // .on_background)
    ' $cf)}" )
    # c[1]=bg c[2]=fg c[3]=cursor c[4..19]=ANSI 0..15
    # ★ OSC 终止用 BEL(\a),不用 ST(ESC \) —— zsh 字符串拼接会吞末尾的 \,
    #   导致前一段 OSC 没有合法终止,kitty 这种无 fallback 主题的终端就拿不到色
    local e=$'\033' s=$'\a' out= i
    for i in {0..15}; do out+="${e}]4;${i};${c[i+4]}${s}"; done
    out+="${e}]10;${c[2]}${s}${e}]11;${c[1]}${s}${e}]12;${c[3]}${s}"
    print -n -- "$out"
}

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Start configuration added by Zim Framework install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}

# --------------------
# Module configuration
# --------------------

#
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Disable automatic widget re-binding on each precmd. This can be set when
# zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# ------------------------------
# Post-init module configuration
# ------------------------------

#
# zsh-history-substring-search
#

zmodload -F zsh/terminfo +p:terminfo
# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key
# }}} End configuration added by Zim Framework install


# >>> conda initialize >>>
# Cross-machine compatible. DO NOT run `conda init zsh` - it will overwrite this.
for _conda_root in \
    "$HOME/miniconda3" \
    "$HOME/anaconda3"
do
    if [[ -f "$_conda_root/bin/conda" ]]; then
        __conda_setup="$("$_conda_root/bin/conda" shell.zsh hook 2> /dev/null)"
        if [[ $? -eq 0 ]]; then
            eval "$__conda_setup"
        elif [[ -f "$_conda_root/etc/profile.d/conda.sh" ]]; then
            . "$_conda_root/etc/profile.d/conda.sh"
        else
            export PATH="$_conda_root/bin:$PATH"
        fi
        unset __conda_setup
        break
    fi
done
unset _conda_root
# <<< conda initialize <<<

start_proxy() {
    export http_proxy="127.0.0.1:7897"
    export https_proxy="127.0.0.1:7897"
}

stop_proxy() {
    unset http_proxy
    unset https_proxy
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH=$HOME/.local/bin:$PATH

# `--icons` 必须带值,否则 _eza 补全会把后续路径当成 --icons 的取值,导致 TAB 路径补全失效
alias ls='eza --icons=auto'
