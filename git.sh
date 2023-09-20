#!/usr/bin/env bash
#
#   git.sh - function for handling the download and "extraction" of Git sources
#
#   Copyright (c) 2015-2021 Pacman Development Team <pacman-dev@archlinux.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

[[ -n "$LIBMAKEPKG_SOURCE_GIT_SH" ]] && return
LIBMAKEPKG_SOURCE_GIT_SH=1

source "source.sh"
source "message.sh"
source "pkgbuild.sh"

download_git() {
	# abort early if parent says not to fetch
	if declare -p get_vcs > /dev/null 2>&1; then
		(( get_vcs )) || return
	fi
	local netfile=$1
	local dir=$(get_filepath "$netfile")
	local dir=$2
	SRCDEST=$SOURCE_DIR

	[[ -z "$dir" ]] && dir="$SRCDEST/$(get_filename "$netfile")"
	local repo=$(get_filename "$netfile")
	local url=$(get_url "$netfile")
	url=${url#git+}
	url=${url%%#*}
	url=${url%%\?*}

#debug url=$url dir=$dir SRCDEST=$SRCDEST

	if [[ ! -d "$dir" ]] || dir_is_empty "$dir" ; then
		msg2 "$(gettext "Clonando %s %s repo em: %s")" "${repo}" "git" "$dir"
		if ! git clone --mirror "$url" "$dir"; then
			error "$(gettext "Falha enquanto downloading %s %s repo")" "${repo}" "git"
			plainerr "$(gettext "Abortando...")"
			exit 1
		fi
	elif (( ! HOLDVER )); then
		cd_safe "$dir"
		# Make sure we are fetching the right repo
		if [[ "$url" != "$(git config --get remote.origin.url)" ]] ; then
#debug srcdir=$srcdir dir=$dir
			error "$(gettext "%s não é um clone de %s")" "$dir" "$url"
			plainerr "$(gettext "Abortando...")"
			exit 1
		fi
		msg2 "$(gettext "Atualizando %s %s repo em: %s")" "${repo}" "git" "$dir"
		if ! git fetch --all -p; then
			# only warn on failure to allow offline builds
			warning "$(gettext "Falha enquanto atuaizava %s %s repo")" "${repo}" "git"
		fi
	fi
}

extract_git() {
	local netfile=$1
	local tagname
	local fragment=$(get_uri_fragment "$netfile")
	local repo=$(get_filename "$netfile")
	local dir=$(get_filepath "$netfile")
	local dir=$2
	local dest=$3

	[[ -z "$dir" ]] && dir="$SRCDEST/$(get_filename "$netfile")"
	msg2 "$(gettext "Criando copia de trabalho %s %s repo em: %s")" "${repo}" "git" "$dir"
	pushd "$srcdir" >/dev/null 2>&1
	local updating=0

	if [[ -d "${dir##*/}" ]]; then
		updating=1
		cd_safe "${dir##*/}"
		if ! git fetch; then
			error "$(gettext "git fetch - Falha enquanto atualizava copia de trabalho de %s %s repo")" "${repo}" "git"
			plainerr "$(gettext "Abortando...")"
			exit 1
		fi
		cd_safe "$srcdir"
	elif ! git clone --shared "$dir" "${dir##*/}"; then
		error "$(gettext "git clone - Falha enquanto atualizava copia de trabalho de %s %s repo")" "${repo}" "git"
		plainerr "$(gettext "Abortando...")"
		exit 1
	fi

	cd_safe "${dir##*/}"

	local ref=origin/HEAD
	if [[ -n $fragment ]]; then
		case ${fragment%%=*} in
			commit|tag)
				ref=${fragment##*=}
				;;
			branch)
				ref=origin/${fragment##*=}
				;;
			*)
				error "$(gettext "Unrecognized reference: %s")" "${fragment}"
				plainerr "$(gettext "Aborting...")"
				exit 1
		esac
	fi

	if [[ ${fragment%%=*} = tag ]]; then
		tagname="$(git tag -l --format='%(tag)' "$ref")"
		if [[ -n $tagname && $tagname != "$ref" ]]; then
			error "$(gettext "Failure while checking out version %s, the git tag has been forged")" "$ref"
			plainerr "$(gettext "Aborting...")"
			exit 1
		fi
	fi

	if [[ $ref != "origin/HEAD" ]] || (( updating )) ; then
		if ! git checkout --force --no-track -B makepkg "$ref" --; then
			error "$(gettext "git checkout - Falha enquanto atualizava copia de trabalho de %s %s repo")" "${repo}" "git"
			plainerr "$(gettext "Aborting...")"
			exit 1
		fi
	fi
	popd >/dev/null 2>&1
}

