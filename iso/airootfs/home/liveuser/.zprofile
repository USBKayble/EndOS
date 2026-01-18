#!/usr/bin/env bash

export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

export DOTFILES="${HOME}/dots-hyprland"

export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

if [[ -z "${DISPLAY}" && "${XDG_VTNR}" -eq 1 ]]; then
    exec startx
fi
