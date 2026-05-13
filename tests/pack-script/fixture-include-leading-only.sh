# shellcheck shell=bash disable=SC2034
# SUR-2842 fixture: only the leading `@include[[:space:]]` form should
# match. Lines that mention `@include` mid-line, or `@includes` (note
# the trailing `s`), or `@include` without any following whitespace
# argument, must not be picked up.
echo "this line mentions @include log but is not a directive"
# @include log
@includes log
@include
@include log
