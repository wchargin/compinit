#!/bin/sh
set -eux

# usage: ./update_dotfiles.sh
# Copy dotfiles from their true locations back into this installer's
# "dotfiles/" folder.

mkdir -p "./dotfiles"

cp -v -u "${HOME}/.vimrc" "./dotfiles/vimrc"
cp -v -u "${HOME}/.bashrc" "./dotfiles/bashrc"
cp -v -u "${HOME}/.inputrc" "./dotfiles/inputrc"
cp -v -u "${HOME}/.xsessionrc" "./dotfiles/xsessionrc"
cp -v -u "${HOME}/.gitconfig" "./dotfiles/gitconfig"
cp -v -u "${HOME}/.gitignore_global" "./dotfiles/gitignore_global"
cp -v -u "${HOME}/.xmonad/xmonad.hs" "./dotfiles/xmonad.hs"
cp -v -u "${HOME}/.haskeline" "./dotfiles/haskeline"
