#!/bin/bash

# Filename:      bashutils-files.bash
# Description:   Miscellaneous utility functions for dealing with files.
# Maintainer:    Jeremy Cantrell <jmcantrell@gmail.com>
# Last Modified: Sun 2009-12-13 01:06:01 (-0500)

[[ $BASH_LINENO ]] || exit 1
[[ $BASHUTILS_FILES_LOADED ]] && return

source bashutils-messages
source bashutils-modes
source bashutils-utils

commonpath() #{{{1
{
    # Gets the common paths of the passed arguments.
    #
    # Usage examples:
    #     commonpath /home/user /home/user/bin  #==> /home/user

    [[ $1 == /* ]] || return 1
    [[ $2 == /* ]] || return 1

    local OIFS=$IFS; local IFS=/
    local dst=($(squeeze "/" <<<"$1"))
    local src=($(squeeze "/" <<<"$2"))
    IFS=$OIFS

    local tokens=()

    local idx
    for idx in "${!dst[@]}"; do
        [[ ${dst[$idx]} != ${src[$idx]} ]] && break
        tokens=("${tokens[@]}" "${dst[$idx]}")
    done

    OIFS=$IFS; IFS=/
    echo "/${tokens[*]}"
    IFS=$OIFS
}

extname() #{{{1
{
    # Get the extension of the given filename.
    #
    # Usage examples:
    #     extname     foo.tar.gz  #==> gz
    #     extname -n2 foo.tar.gz  #==> tar.gz

    local levels=1

    unset OPTIND
    while getopts ":n:" options; do
        case $options in
            n) levels=$OPTARG ;;
        esac
    done && shift $(($OPTIND - 1))

    local filename=${1##*/}
    local fn=$filename
    local exts ext

    for i in $(seq 1 $levels); do
        ext=.${fn##*.}
        exts=$ext$exts
        fn=${fn%$ext}
        [[ $exts == $filename ]] && return 1
    done

    echo "$exts"
}

filename() #{{{1
{
    # Gets the filename of the given path.
    #
    # Usage examples:
    #     filename /path/to/file.txt  #==> file

    local levels=1

    unset OPTIND
    while getopts ":n:" options; do
        case $options in
            n) levels=$OPTARG ;;
        esac
    done && shift $(($OPTIND - 1))

    local ext=$(extname -n $levels "$1")

    if [[ $ext ]]; then
        basename "$1" $ext
    else
        basename "$1"
    fi
}

increment_file() #{{{1
{
    # Get the next filename in line for the given file.
    #
    # Usage examples:
    #     increment_file does_not_exist  #==> does_not_exist
    #     increment_file does_exist      #==> does_exist (1)

    local file=$1
    local count=1

    while [[ -e $file ]]; do
        file="$1 ($((count++)))"
    done

    echo "$file"
}

listdir() #{{{1
{
    # Get the files in the given directory (1 level deep).

    local dir=$1; shift
    find "$dir" -maxdepth 1 -mindepth 1 "$@"
}

mimetype() #{{{1
{
    # Get the mimetype of the given file.

    file -ibL "$1" | awk -F";" '{print $1}'
}

mount_path() #{{{1
{
    # Get the mount path for the given device.

    grep "^$1[[:space:]]" /etc/fstab | awk '{print $2}'
}

mount_device() #{{{1
{
    # Get the device for the given mount path.

    grep "[[:space:]]$1[[:space:]]" /etc/fstab | awk '{print $1}'
}

mounted_path() #{{{1
{
    # Check to see if a given device is mounted.

    mount | awk '{print $3}' | grep -q "^${1:-/}$"
}

mounted_device() #{{{1
{
    # Check to see if a given device is mounted.

    mount | awk '{print $1}' | grep -q "^${1:-/}$"
}

relpath() #{{{1
{
    # Gets the relative path from src to dst.
    # It should give the same output as the python function os.path.relpath().
    # All arguments should be given as absolute paths.
    # All arguments default to the current directory.
    #
    # Usage examples:
    #     relpath /home/user     /home/user/bin  #==> bin
    #     relpath /home/user/bin /home/user      #==> ..
    #     relpath /foo/bar/baz   /               #==> ../../..
    #     relpath /foo/bar       /baz            #==> ../../baz
    #     relpath /home/user     /home/user      #==> .

    # Make sure that any duplicate slashes are removed.
    local dst=/$(squeeze "/" <<<"${1:-$PWD}")
    local src=/$(squeeze "/" <<<"${2:-$PWD}")

    local common=$(commonpath "$dst" "$src")

    dst=${dst#$common}; dst=${dst#/}
    src=${src#$common}; src=${src#/}

    local OIFS=$IFS; local IFS=/
    src=($src)
    IFS=$OIFS

    local rel=
    for i in "${!src[@]}"; do
        rel+=../
    done

    rel=${rel}${dst}

    # Handle some corner cases.
    # Arguments were the same path.
    [[ $rel ]] || rel=.
    # Make sure there are no trailing slashes.
    # ...except for root.
    [[ $rel == / ]] || rel=${rel%%/}

    echo "$rel"
}

truncate() #{{{1
{
    # Removes all similar unused files.
    #
    # Usage examples:
    #
    #     Given the following files/dirs:
    #         file1
    #         file2
    #         file3
    #
    #     And the symlink:
    #         file -> file3
    #
    #     The command:
    #         tuncate file
    #
    #     Will remove the files/dirs:
    #         file1
    #         file2

    local name=$1

    if [[ ! -L $name ]]; then
        error "Name not provided."
        return 1
    fi

    local target=$(readlink -f "$name")

    if [[ ! -e $target ]]; then
        error "Target file does not exist."
        return 1
    fi

    local dir=$(dirname "$target")
    local file

    for file in "$dir/$(basename "$name")"*; do
        [[ -f $file ]] || continue
        if [[ $file != $target ]]; then
            rm -r $(interactive_option) $(verbose_echo "-v") "$file"
        fi
    done
}

#}}}1

BASHUTILS_FILES_LOADED=1
