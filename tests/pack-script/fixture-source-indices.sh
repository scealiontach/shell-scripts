# shellcheck shell=bash disable=SC2034
# SUR-1817 fixture: a target file whose content references multiple
# BASH_SOURCE indices. Intentionally not executable and contains no shebang;
# it is fed to bash/pack-script as a target via -f, never sourced or run.

self0="${BASH_SOURCE[0]}"
self1="${BASH_SOURCE[1]}"
self_last="${BASH_SOURCE[-1]}"
self_two="${BASH_SOURCE[2]}"
echo "$self0 $self1 $self_last $self_two"
