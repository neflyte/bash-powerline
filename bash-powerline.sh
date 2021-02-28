#!/usr/bin/env bash

POWERLINE_GIT=1
POWERLINE_SVN=1
POWERLINE_KUBE=1
POWERLINE_DOCKER=1

__powerline() {
  # Colorscheme
  readonly RESET='\[\033[m\]'
  readonly COLOR_CWD='\[\033[0;94m\]'         # blue
  readonly COLOR_GIT='\[\033[0;36m\]'         # cyan
  readonly COLOR_SVN='\[\033[0;35m\]'         # magenta
  readonly COLOR_SUCCESS='\[\033[0;32m\]'     # green
  readonly COLOR_FAILURE='\[\033[0;31m\]'     # red
  readonly COLOR_BRIGHTBLACK='\[\033[0;90m\]' # bright black
  readonly COLOR_WHITE='\[\033[0;37m\]'       # white

  readonly SYMBOL_GIT_BRANCH=''
  readonly SYMBOL_GIT_MODIFIED='*'
  readonly SYMBOL_GIT_PUSH='↑'
  readonly SYMBOL_GIT_PULL='↓'

  [ -z "${PS_SYMBOL}" ] && {
    case "${OSTYPE}" in
    darwin*)
      PS_SYMBOL=''
      ;;
    Linux | FreeBSD)
      PS_SYMBOL='$'
      [ ${EUID} -eq 0 ] && PS_SYMBOL='#'
      ;;
    *)
      PS_SYMBOL='%'
      ;;
    esac
  }

  __git_info() {
    [ ${POWERLINE_GIT} -eq 0 ] && return # disabled
    hash git 2>/dev/null || return       # git not found
    local git_eng="env LANG=C git"       # force git output in English to make our work easier

    # get current branch name
    local ref=$(${git_eng} symbolic-ref --short HEAD 2>/dev/null)

    if [ -n "${ref}" ]; then
      # prepend branch symbol
      ref=${SYMBOL_GIT_BRANCH}${ref}
    else
      # get tag name or short unique hash
      ref=$(${git_eng} describe --tags --always 2>/dev/null)
    fi

    [ -n "${ref}" ] || return # not a git repo

    local marks

    # scan first two lines of output from `git status`
    while IFS= read -r line; do
      if [[ ${line} =~ ^## ]]; then # header line
        [[ ${line} =~ ahead\ ([0-9]+) ]] && marks+=" ${SYMBOL_GIT_PUSH}${BASH_REMATCH[1]}"
        [[ ${line} =~ behind\ ([0-9]+) ]] && marks+=" ${SYMBOL_GIT_PULL}${BASH_REMATCH[1]}"
      else # branch is modified if output contains more lines after the header line
        marks="${SYMBOL_GIT_MODIFIED}${marks}"
        break
      fi
    done < <(${git_eng} status --porcelain --branch 2>/dev/null) # note the space between the two <

    # print the git branch segment without a trailing newline
    echo -n "${ref}${marks}"
  }

  __svn_info() {
    [ ${POWERLINE_SVN} -eq 0 ] && return # disabled
    hash svn 2>/dev/null || return       # svn not found
    local svn_eng="env LANG=C svn"       # force svn output in English to make our work easier
    local svn_info
    local rev
    local relativeURL

    relativeURL=$(${svn_eng} info --show-item relative-url 2>/dev/null)
    [ -n "${relativeURL}" ] && {
      svn_info="${svn_info}${relativeURL}"
      rev=$(${svn_eng} info --show-item revision 2>/dev/null)
      [ -n "${rev}" ] && svn_info="${svn_info}@${rev}"
      # look for changes
      local changectr=0
      while IFS= read -r line; do
        local changestat=${line:0:1}
        case ${changestat} in
        "A" | "C" | "D" | "M" | "R")
          changectr=$((changectr + 1))
          ;;
        esac
      done < <(${svn_eng} status -q 2>/dev/null)
      [ ${changectr} -gt 0 ] && svn_info+=" ${SYMBOL_GIT_PUSH} ${changectr}"
    }

    echo -n "${svn_info}"
  }

  __docker_info() {
    [ ${POWERLINE_DOCKER} -eq 1 ] || return
  }

  ps1() {
    # Check the exit code of the previous command and display different
    # colors in the prompt accordingly.
    local prevErrno=${?}
    local symbol="${COLOR_SUCCESS}"
    [ ${prevErrno} -ne 0 ] && symbol="${COLOR_FAILURE}"
    symbol+=" ${PS_SYMBOL} ${RESET}"

    # Bash by default expands the content of PS1 unless promptvars is disabled.
    # We must use another layer of reference to prevent expanding any user
    # provided strings, which would cause security issues.
    # POC: https://github.com/njhartwell/pw3nage
    # Related fix in git-bash: https://github.com/git/git/blob/9d77b0405ce6b471cb5ce3a904368fc25e55643d/contrib/completion/git-prompt.sh#L324
    local git
    __powerline_git_info="$(__git_info)"

    if [[ -z ${__powerline_git_info} ]]; then
      git=""
    else
      if shopt -q promptvars; then
        git="${COLOR_GIT}\${__powerline_git_info}${RESET}"
      else
        git="${COLOR_GIT}${__powerline_git_info}${RESET}"
      fi
    fi

    local svn
    __powerline_svn_info="$(__svn_info)"
    if [[ -z ${__powerline_svn_info} ]]; then
      svn=""
    else
      if shopt -q promptvars; then
        svn="${COLOR_SVN}\${__powerline_svn_info}${RESET}"
      else
        svn="${COLOR_SVN}${__powerline_svn_info}${RESET}"
      fi
    fi

    local cwd="${COLOR_CWD}\w${RESET}"
    #local dt=$(date "+%Y-%m-%d %I:%M")

    #local userhost='\u@\h'
    #userhost="${COLOR_BRIGHTBLACK}${userhost}"
    local userhost="${COLOR_BRIGHTBLACK}\u@\h${RESET}"

    local kubectx
    [ ${POWERLINE_KUBE} -eq 1 ] && {
      kubectx=$(kubectl config current-context 2>/dev/null) || kubectx=""
    }

    local lineone
    [ -n "${kubectx}" ] && lineone+="${COLOR_WHITE}k:${kubectx} "
    [ -n "${git}" ] && lineone+="${COLOR_GIT}g:${git} "
    [ -n "${svn}" ] && lineone+="${COLOR_SVN}s:${svn} "
    [ -n "${lineone}" ] && lineone+="\n"

    PS1="${RESET}${lineone}${userhost} ${cwd} ${symbol}"
  }

  PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
}

__powerline
unset __powerline
