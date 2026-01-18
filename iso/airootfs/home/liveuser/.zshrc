#!/usr/bin/env bash

ZDOTDIR="${HOME}/.config/zsh"

if [[ -d "${ZDOTDIR}/zshrc.d" ]]; then
    for file in "${ZDOTDIR}"/zshrc.d/*.sh; do
        if [[ -r "${file}" ]]; then
            source "${file}"
        fi
    done
    unset file
fi
