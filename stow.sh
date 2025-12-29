#!/usr/bin/env bash

set -euo pipefail

# Instala os dotfiles
rm -rf ~/.config/.bashrc ~/.config/fish ~/.gitconfig ~/.config/nvim ~/.ssh/config ~/.config/yazi ~/.config/zellij
cd ~/.dotfiles-dev
stow bash fish git nvim ssh yazi zellij

