#!/bin/sh
set -eux

# usage: ./install.sh
# Configure a fresh system, or update an existing system's
# configuration.
#
# This script is idemptotent, and will not overwrite newer files.

main() {
    cd "$(dirname "$0")"
    ensure_not_root

    set_up_dotfiles
    set_up_packages
    set_up_fonts
    set_up_terminal

    sed 's/^    //' <<EOF

    ========================================================================
        All done.
    
        Possible next steps:
          - Switch to an xmonad session and customize gnome-panels.
          - Set up an SSH key.
          - Install Chrome.
          - Run the 'gnome-terminal-colors-solarized' installer,
            included in this repository.
          - Run 'dropbox start -i' (once) to install the Dropbox daemon.
            Once it starts syncing, run 'symlink_dropbox_dotfiles.sh'.
    ========================================================================
EOF
}

ensure_not_root() {
    if [ "$(whoami)" = "root" ]; then
        printf >&2 'Do not invoke this script as root.\n'
        return 1
    fi
}

set_up_dotfiles() {
    cp -v -u "./dotfiles/bashrc" "${HOME}/.bashrc"
    cp -v -u "./dotfiles/inputrc" "${HOME}/.inputrc"
    cp -v -u "./dotfiles/xsessionrc" "${HOME}/.xsessionrc"

    cp -v -u "./dotfiles/gitconfig" "${HOME}/.gitconfig"
    cp -v -u "./dotfiles/gitignore_global" "${HOME}/.gitignore_global"

    mkdir -p "${HOME}/.xmonad"
    cp -v -u "./dotfiles/xmonad.hs" "${HOME}/.xmonad/xmonad.hs"
    cp -v -u "./dotfiles/haskeline" "${HOME}/.haskeline"

    cp -v -u "./dotfiles/vimrc" "${HOME}/.vimrc"
    mkdir -p "${HOME}/.vim"
    mkdir -p "${HOME}/.vim/autoload"
    cp -v -u "./vim-plug/plug.vim" "${HOME}/.vim/autoload/plug.vim"

    mkdir -p "${HOME}/.config"
    if [ -d "${HOME}/.config/nvim" ] && ! [ -h "${HOME}/.config/nvim" ]; then
        rmdir "${HOME}/.config/nvim"
    fi
    ln -s -f "${HOME}/.vim" "${HOME}/.config/nvim"
    ln -s -f "${HOME}/.vimrc" "${HOME}/.config/nvim/init.vim"
}

set_up_packages() {
    <"./lists/standard_packages" xargs sudo apt-get install -y

    sudo add-apt-repository -y ppa:neovim-ppa/stable
    sudo add-apt-repository -y ppa:gekkio/xmonad
    sudo apt-get update

    <"./lists/ppa_packages" xargs sudo apt-get install -y

    pip install --user --upgrade pip
    while read -r package; do
        pip install --user "${package}"
    done <"./lists/pip_packages"
}

set_up_fonts() {
    mkdir -p "${HOME}/.local/share/fonts"
    cp -v -r "./fontdata/fonts" -t "${HOME}/.local/share/"

    mkdir -p "${HOME}/.config/fontconfig/conf.d"
    cp -v -r "./fontdata/10-powerline-symbols.conf" -t "${HOME}/.config/fontconfig/conf.d/"
}

set_up_terminal() {
    # Set up gnome-terminal-colors-solarized manually, please.
    # (With gnome-terminal>=3.9, the solarized install script is not
    # compatible with the newer profiles format.)
    dconf write /org/gnome/terminal/legacy/default-show-menubar false
}

main
