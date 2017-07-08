#!/bin/sh
set -eu

# usage: ./symlink_dropbox_dotfiles.sh
# Create symbolic links in Dropbox/dotfiles to keep everything in sync.
#
# This script is idempotent.

: "${DROPBOX:=${HOME}/Dropbox}"
: "${DROPBOX_DOTFILES:=${DROPBOX}/dotfiles}"

main() {
    mkdir -p "${DROPBOX_DOTFILES}"

    if which dropbox >/dev/null 2>/dev/null; then
        dropbox stop
    fi

    symlink_dotfile bashrc
    symlink_dotfile vimrc
    symlink_dotfile inputrc
    symlink_dotfile xsessionrc
    symlink_dotfile haskeline
    symlink_file "${HOME}/.xmonad/xmonad.hs" "${DROPBOX_DOTFILES}/xmonad.hs"

    if which dropbox >/dev/null 2>/dev/null; then
        dropbox start
    fi
}

# usage: symlink_file SOURCE_FILE TARGET_FILE
# Make TARGET_FILE a symbolic link to SOURCE_FILE.
# If TARGET_FILE exists, it must equal SOURCE_FILE in content.
symlink_file() {
    if ! [ -f "$1" ]; then
        printf \
            'skipping "%s" -- "%s" (source does not exist)\n' "$1" "$2"
        return
    fi
    if [ -h "$2" ]; then
        if [ "$(readlink -f "$1")" != "$(readlink -f "$2")" ]; then
            printf 'error: "%s" already points to "%s", not "%s"\n' \
                "$2" "$(readlink -f "$2")" "$1"
            return 1
        fi
        printf 'skipping "%s" -- "%s" (already linked)\n' "$1" "$2"
        return 0
    fi
    if [ -e "$2" ]; then
        if ! diff -q "$1" "$2"; then
            printf \
                'error: target "%s" exists but differs from source "%s"\n' \
                "$2" "$1"
            return 1
        fi
        rm "$2"
    fi
    printf 'linking "%s" -- "%s"\n' "$1" "$2"
    ln -s "$1" "$2"
}

# usage: symlink_dotfile DOTFILE_STEM
# where DOTFILE_STEM is like "bashrc" (no dot)
symlink_dotfile() {
    symlink_file "${HOME}/.$1" "${DROPBOX_DOTFILES}/$1"
}

main
