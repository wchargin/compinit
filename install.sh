#!/bin/bash
# install.sh: Set up a fresh clone from scratch.
# This script is idempotent.
# Run with '-d' for dry-run if you so desire.

set -e
cd "$(dirname "$0")"

: "${DRY_RUN:=}"
declare -A INSTALL_MODE_COMMANDS=(                  \
    [minimal]=install_minimal                       \
    [full]=install_full                             \
    [config-only]=install_config                    \
    [haskell]=install_haskell                       \
    [tex]=install_tex                               \
    [node]=install_node                             \
    [dropbox-symlinks]=install_dropbox_symlinks     \
)
DEFAULT_INSTALL_COMMAND="${INSTALL_MODE_COMMANDS[minimal]}"

# ANSI color code used for outputting command lines and similar text.
COLOR_COMMAND=3

# usage: Print the usage, then exit with the given status.
# The return status is always 0.
# example: usage
usage() {
    cat >&2 << EOF
Usage: $0 [-d|--dry-run] [-h|--help] [mode]
    -d      dry-run
    -h      print this help message
    mode    installation mode; can be one of
                minimal $(colored "[default]" 0 bold)
                config-only
                    system configuration and dotfiles
                    ($(tag warning)may depend on "minimal")
                haskell
                tex
                node
                full
                    all of the above
                dropbox-symlinks
                    set up Dropbox-hosted symlinks for dotfiles
EOF
    return 0
}

# main: Run the installer with the given command-line options.
# example: main "$@"
main() {
    local install_command=
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            '-d'|'--dry-run')
                if [[ -n "$DRY_RUN" ]]; then
                    printf 'error: %s\n' 'dry-run flag set twice'
                    exit 1
                else
                    DRY_RUN=1
                fi
                ;;
            '-h'|'--help')
                usage
                exit 0
                ;;
            *)
                if [[ -n "$install_command" ]]; then
                    printf 'error: %s\n' 'installation mode set twice'
                    exit 1
                else
                    install_command="${INSTALL_MODE_COMMANDS["$1"]}"
                    if [[ -z "$install_command" ]]; then
                        printf 'Unrecognized argument: %s\n' "$1"
                        usage
                        exit 1
                    fi
                fi
                ;;
        esac
        shift
    done

    if [[ "$(logname)" != "$(whoami)" ]]; then
        printf '%s\n' "Please don't run me as root!"
        printf '%s\n' "I'll ask you for sudo access if I need it."
        exit 1
    fi

    "${install_command:-$DEFAULT_INSTALL_COMMAND}"

    # This isn't your run-of-the-mill dumb banner comment---
    # it's a *colorful* dumb banner comment!
    printf '\n'
    printf '%s\n' "+======================================+"
    printf '%s'   "|              "
    colored                      "All done!"                2 bold
    printf '%s\n'                         "               |"
    printf '%s\n' "+======================================+"
}

# install_config: Run the config-only installation phase.
install_config() {
    section "Configuring your system fonts"
    set_up_fonts

    section "Configuring your terminal environment"
    set_up_terminal

    section "Configuring your shell environment"
    set_up_shell

    section "Configuring your Git environment and GitHub integration"
    set_up_git

    section "Configuring your Vim environment"
    set_up_vim
}

# install_minimal: Run the minimal installation phase.
# This runs install_config as part of its installation process.
install_minimal() {
    section "Installing minimal packages"
    accept_fonts_eula
    install_packages_from "packages/minimal_packages"

    install_config
}

# install_full: Run the full installation phase.
# This runs install_minimal first.
install_full() {
    install_minimal
    install_haskell
    install_tex
    install_node
}

# accept_fonts_eula: Pre-accept the ttf-mscorefonts-installer EULA.
# This reduces user interaction.
accept_fonts_eula() {
    local f_package='ttf-mscorefonts-installer'
    local f_question='msttcorefonts/accepted-mscorefonts-eula'
    local f_type='select'
    local f_answer='true'
    local line="$f_package $f_question $f_type $f_answer"
    sudo debconf-set-selections <<< "$line"
}

# set_up_fonts: Configure system fonts.
set_up_fonts() {
    local fonts_dir="$HOME/.local/share/fonts"
    cmd mkdir -p "$fonts_dir"

    # Use '--display-as' so we don't expand the glob,
    # which takes up a bunch of space.
    cmd --display-as                                \
        "cp --no-clobber fontdata/fonts/* $fonts_dir"   \
         cp --no-clobber fontdata/fonts/* "$fonts_dir"

    local fontconfig_dir="$HOME/.config/fontconfig/conf.d"
    local fontconfig_name="10-powerline-symbols.conf"
    cmd mkdir -p "$fontconfig_dir"
    safe_cp "fontdata/$fontconfig_name" "$fontconfig_dir/$fontconfig_name"

    cmd gsettings set org.gnome.desktop.interface monospace-font-name   \
        'Inconsolata LGC Medium 12'
}

# set_up_terminal: Configure terminal emulator color scheme and profile.
set_up_terminal() {
    cmd gnome-terminal-colors-solarized/install.sh  \
        --scheme light                              \
        --profile Default

    local path="/apps/gnome-terminal/profiles/Default"
    cmd gconftool-2 -s -t bool "$path/scrollback_unlimited" true
    cmd gconftool-2 -s -t bool "$path/default_show_menubar" false
}

# set_up_shell: Configure Bash and readline.
set_up_shell() {
    safe_cp "dotfiles/bashrc" "$HOME/.bashrc"
    safe_cp "dotfiles/inputrc" "$HOME/.inputrc"
}

# set_up_git: Configure git(1) globals and GitHub integration.
set_up_git() {
    safe_cp "dotfiles/gitconfig" "$HOME/.gitconfig"
    safe_cp "dotfiles/gitignore_global" "$HOME/.gitignore_global"

    local ssh_key_file="$HOME/.ssh/id_rsa"
    if [[ -f "$ssh_key_file" ]]; then
        printf 'SSH key already exists at "%s"; not regenerating.\n' \
            "$ssh_key_file"
    else
        cmd ssh-keygen -t rsa -f "$ssh_key_file"
    fi

    local public_key="${ssh_key_file}.pub"
    copy_file_to_clipboard "$public_key"


    printf '%s\n' "Your public key has been copied to the clipboard."
    printf '%s\n' "Please register it with GitHub, and then enter 'done' here."
    printf '%s\n' "If you want to skip this step, enter 'skip' instead."
    printf '%s\n' "You can also enter 'copy' to copy the key again."
    printf '> '
    if [[ -n "$DRY_RUN" ]]; then
        colored "(skipping for dry-run)" "$COLOR_COMMAND"
        printf '\n'
    else
        local confirmed=0
        while read -r input; do
            case "$input" in
                '')
                    ;;
                'done'|'skip')
                    confirmed=1
                    break
                    ;;
                'copy')
                    copy_file_to_clipboard "$public_key"
                    ;;
                *)
                    printf >&2 '%s %s\n' "Unrecognized input:" "$input"
                    ;;
            esac
            printf '> '
        done
        if [[ "$confirmed" -eq 0 ]]; then
            # user pressed <C-D> immediately
            printf '<C-D>\n'
            printf '%s\n' '(Proceeding.)'
        fi
    fi
}

# copy_file_to_clipboard: Copy a file on disk to the system clipboard.
#
# Respects DRY_RUN.
# example: copy_file_to_clipboard dir/foo.txt
copy_file_to_clipboard() {
    local mode=

    # We need to use a bit of redirection here,
    # which our 'cmd' wrapper doesn't really nicely support.
    # So we'll format the command line on our own.
    for mode in "primary  " "clipboard"; do
        cmd                                         \
            --display-as "xsel --${mode} -i < $1"   \
            sh -c "xsel --${mode} -i < \"$1\""
    done
}

# set_up_vim: Set up .vimrc and plugin manager (junegunn/vim-plug).
set_up_vim() {
    safe_cp "dotfiles/vimrc" "$HOME/.vimrc"
    cmd mkdir -p "$HOME/.vim/autoload/"
    safe_cp "vim-plug/plug.vim" "$HOME/.vim/autoload/plug.vim"
    printf '%s\n' 'Run :PlugUpgrade and :PlugInstall in vim to get started.'
}

# install_haskell: Install the Haskell Platform from APT.
install_haskell() {
    section "Installing Haskell"
    sudo apt-get install -y haskell-platform
    safe_cp "dotfiles/ghci" "$HOME/.ghci"
    cmd cabal install hoogle
}

# install_tex: Install and configure TeXlive.
install_tex() {
    section "Installing TeX"
    sudo apt-get install -y texlive-full
}

# install_node: Install and configure node(1) and npm(1).
install_node() {
    section "Installing Node"

    if type node npm >/dev/null 2>&1; then
        printf '%s\n' "Both 'node' and 'npm' are already installed:"
        type node npm
        printf '%s\n' 'Skipping this phase of setup.'
        return 0
    fi

    local dir
    dir="$(mktemp -d)"
    cmd --display-as "mkdir $dir" :

    local node_archive="node-v4.2.4-linux-x64"
    cmd cp "node/${node_archive}.tar.gz" "$dir"
    cmd pushd "$dir" 2>/dev/null
    cmd tar xzf "${node_archive}.tar.gz"
    cmd cd "$node_archive/"
    cmd mkdir -p "$HOME/bin"
    cmd ./bin/npm set prefix "$HOME"
    cmd ./bin/npm install --global npm
    safe_cp --generated ./bin/node "$HOME/bin/node"
    cmd popd

    cmd --display-as "rm -r $dir" :
    rm -r "$dir"
}

# install_dropbox_symlinks: Set up symbolic links for dotfiles in Dropbox;
# e.g., make ~/.bashrc a symlink to ~/Dropbox/dotfiles/bashrc a symlink.
install_dropbox_symlinks() {
    local dropbox_base_dir="$HOME/Dropbox/dotfiles"
    if [[ ! -d "$dropbox_base_dir" ]]; then
        printf "The directory \"%s\" doesn't seem to exist.\n" \
            "$dropbox_base_dir"
        printf "Are you sure that Dropbox is set up correctly\n"
        printf "and that an initial sync has (at least partially) completed?\n"
        return 1
    fi >&2

    for dotfile in bashrc vimrc; do
        local src="$dropbox_base_dir/$dotfile"  # no actual dot
        local tgt="$HOME/.$dotfile"
        if [[ ! -f "$src" ]]; then
            tag warning
            printf 'no such file "%s"; skipping\n' "$src"
            continue
        fi
        cmd rm -f "$tgt"
        cmd ln -s "$src" "$tgt"
    done
}

# install_packages_from: Install a list of APT packages from a manifest file.
# The manifest should have one package name per line, and nothing else.
# Respects DRY_RUN.
#
# example: install_packages_from ./dir/my_package_list
install_packages_from() {
    while <&3 read -r package; do
        cmd sudo apt-get -y install "$package"
    done 3<"$1"
}

# safe_cp: Verify that the destination does not exist, then acts as 'cp'.
# If the target does exist, prints a note to that effect
# and completes successfully (returning 0).
# May not work properly when the target argument is just a directory
# (i.e., it will fail if the *directory* exists).
# Respects DRY_RUN.
#
# If the file is not going to exist in dry-run mode,
# pass '--generated' as the first argument.
#
# example: safe_cp foo /home/bar
# example: cmd make foo; safe_cp --generated foo /home/bar
safe_cp() {
    local generated=
    if [[ "$1" == "--generated" ]]; then
        generated=1
        shift
    fi
    if [[ -e "$2" ]]; then
        if [[ -z "$generated" && ! -e "$1" ]]; then
            printf >&2 'error: source "%s" does not exist' "$1"
            return 1
        fi
        tag note
        printf 'Not copying "%s" to "%s"; target exists\n' "$1" "$2"
    else
        cmd cp "$1" "$2"
    fi
}

# section: Print a section header with name the first argument.
# example: section 'Reticulate splines'
section() {
    safe_tput bold
    printf '\n%s\n' "$1"
    safe_tput sgr0
}

# cmd: Run a command in production, or echo it in dry-run mode.
# You can use --display-as to override the display text
# (e.g., if you need to spawn a subshell just to use redirection).
# example: cmd mv srcfile targetfile
# example: cmd --display-as 'cat < file' sh -c 'cat < file'
cmd() {
    local FAKE_PROMPT='%'

    local cmdline=
    if [[ "$1" == "--display-as" ]]; then
        cmdline="$2"
        shift 2
    else
        local args=()
        local arg
        for arg in "$@"; do
            if [[ "$arg" =~ " " ]]; then
                args+=( "'$arg'" )
            else
                args+=( "$arg" )
            fi
        done
        cmdline="${args[*]}"
    fi

    colored "$FAKE_PROMPT $cmdline" "$COLOR_COMMAND"
    printf '\n'

    if [[ ! -n "$DRY_RUN" ]]; then
        "$@"
    fi
}

# safe_tput: Act as 'tput', but don't complain if we're not in a terminal.
# Does not respect DRY_RUN, because you probably don't want it to.
# example: safe_tput sgr0
safe_tput() {
    tput 2>/dev/null "$@" || true
}

# colored: Print some text that's colored and optionally.
# example: colored "flux capacitor activated" 5
# example: colored "NEON" 1 bold
colored() {
    local text="$1"
    local color="$2"
    local bold="$3"

    safe_tput setaf "$color"
    if [[ "$bold" == "bold" ]]; then
        safe_tput bold
    fi
    printf '%s' "$text"
    safe_tput sgr0
}

# tag: Print a 'warning' or 'note' tag, including a trailing space.
# example: tag warning
# example: tag note
tag() {
    local color=
    case "$1" in
        warning)
            colored "warning:" 5 bold
            ;;
        note)
            colored "note:" 4
            ;;
        *)
            printf >&2 'internal error: unknown tag "%s"\n' "$1"
            return 2
            ;;
    esac
    printf ' '
}

main "$@"
