#!/bin/bash
#shellcheck disable=SC2317,SC2188,SC2034,SC2155,SC2059
#shellcheck source=/dev/null
#
#  lib.sh
#
#  Copyright (c) 2023,2023 by vcatafesta <vcatafesta@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

#debug
export PS4='${red}${0##*/}${green}[$FUNCNAME]${pink}[$LINENO]${reset} '
#set -x
#set -e
#shopt -s extglob

export LC_ALL=C
APP="${0##*/}"

nocolor() { unset RED GREEN YELLOW CYAN PURPLE CRESET; }
msgempty() { printf "$reset %-$((COLUMNS - 10))s\r" ""; }
msgr() { printf "$green==>$reset %-$((COLUMNS - 10))s\r" "$1"; }
msg() { printf "${green}==>${reset} %s\n" "$1"; }
msg2() { printf "${green} ->${reset} %s\n" "$1"; }
msginst() { printf "[${green}i${reset}] %s\n" "$1"; }
msgmiss() { printf "[${yellow}m${reset}] %s\n" "$1"; }
msgnoinst() { printf "[-] %s\n" "$1"; }
msgerr() { printf "${red}ERROR:${reset} %s\n" "$1" >&2; }
msgwarn() { printf "${yellow}WARNING:${reset} %s\n" "$1" >&2; }
settermtitle() { printf "\033]0;$*\a"; }
msg_portnotfound() { echo "Port '$1' not found."; }
msg_portnotinstalled() { echo "Port '$1' not installed."; }
msg_portalreadyinstalled() { echo "Port '$1' already installed."; }

sh_setvarcolors() {
	RED='\033[31m'
	GREEN='\033[32m'
	YELLOW='\033[33m'
	CYAN='\033[36m'
	PURPLE='\033[35m'
	CRESET='\033[0m'

	if [ -n "$(command -v "tput")" ]; then
		#tput setaf 127 | cat -v  #capturar saida
		#tput sgr0 # reset colors
		bold="$(tput bold)"
		reset="$(tput sgr0)"
		black="$(tput bold)$(tput setaf 0)"
		red="$(tput bold)$(tput setaf 196)"
		green="$(tput setaf 2)"
		yellow="$(tput bold)$(tput setaf 3)"
		blue="$(tput setaf 4)"
		pink="$(tput setaf 5)"
		cyan="$(tput bold)$(tput setaf 6)"
		white="$(tput bold)$(tput setaf 7)"
		orange="$(tput setaf 3)"
		purple="$(tput setaf 125)"
		violet="$(tput setaf 61)"
	fi

	if [ -z "${COLUMNS}" ]; then
		COLUMNS=$(stty size)
		COLUMNS=${COLUMNS##* }
	fi

	if [ "${COLUMNS}" = "0" ]; then
		COLUMNS=80
	fi
	COL=$((COLUMNS - 8))
	SET_COL="\\033[${COL}G" # at the $COL char
	CURS_ZERO="\\033[0G"

	COL_NC='\e[0m' # No Color
	COL_LIGHT_GREEN='\e[1;32m'
	COL_LIGHT_RED='\e[1;31m'
	TICK="${white}[${COL_LIGHT_GREEN}✓${COL_NC}${white}]"
	CROSS="${white}[${COL_LIGHT_RED}✗${COL_NC}${white}]"
	IGNORE="${white}[${yellow}i${COL_NC}${white}]"
	# shellcheck disable=SC2034
	DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
	OVER="\\r\\033[K"
	NORMAL="${reset}"
	SUCCESS="${green}"
	WARNING="${yellow}"
	FAILURE="${red}"
	BRACKET="${blue}"
	BMPREFIX="    "
	DOTPREFIX="  ${blue}::${reset} "

	SUCCESS_PREFIX=" $TICK "
	SUCCESS_SUFFIX="${BRACKET}[${SUCCESS}   ↑   ${BRACKET}]${NORMAL}"
	FAILURE_PREFIX=" $CROSS "
	FAILURE_SUFFIX="${BRACKET}[${FAILURE}   ↓   ${BRACKET}]${NORMAL}"
	IGNORE_PREFIX=" $IGNORE "
	IGNORE_SUFFIX="${BRACKET}[${FAILURE}   S   ${BRACKET}]${NORMAL}"
	WARNING_PREFIX="${WARNING}  W  ${NORMAL}"
	WARNING_SUFFIX="${BRACKET}[${WARNING} WARN ${BRACKET}]${NORMAL}"
	WAIT_PREFIX="${WARNING}  R  ${NORMAL}"
	WAIT_SUFFIX="${BRACKET}[${WARNING} WAIT ${BRACKET}]${NORMAL}"
}

sh_unsetvarcolors() {
	unset reset green red bold blue cyan
	unset orange pink white yellow violet purple
}

sh_check_lockfile() {
	local pkg="$1"
	LOCK_FILE="/tmp/pkgbuild.$pkg.lock"

	[ -f "$LOCK_FILE" ] && {
		msgerr "Cannot build same package simultaneously."
		die "remove '$LOCK_FILE' if no build process for '$name'."
	}
}

sh_seek_script() {
	local xpath="$1"

	if ! test -f "$xpath/$BUILD_SCRIPT"; then
		BUILD_SCRIPT='spkgbuild'
	fi
}
export -f sh_seek_script

mkfetch() {
	local fetch_pkgname=$1

	[[ -z "$fetch_pkgname" ]] && fetch_pkgname=$name # from scratch
	local pkgver=$version                            # from scratch
	local pkgrel=$release                            # from scratch
	local path_fetch_conf='/etc/fetch/fetch.conf'
	export public_url
	export public_pkgdesc
	export public_license
	export public_arch
	export public_deps
	export public_depends
	export public_source
	export public_validpgpkeys
	export public_sha256sums
	export FETCH_PKG
	set +e

	[[ -e "$path_fetch_conf" ]] && source "$path_fetch_conf"
	[[ -z "$fetch_pkgname" ]] && fetch_pkgname=$pkgname # from PKGBUILD
	[[ -z "$pkgver" ]] && pkgver=$pkgver                # from PKGBUILD
	[[ -z "$pkgrel" ]] && pkgrel=$pkgrel                # from PKGBUILD
	[[ -z "$public_arch" ]] && public_arch=x86_64

	source "$ppath/$BUILD_SCRIPT"
	[[ -z "$public_deps" ]] && {
		public_deps=$(sed -n 's/^# depends[[:blank:]]*:[[:blank:]]*//p' "$ppath/$BUILD_SCRIPT" | awk '!a[$0]++' | tr '\n' ' ' | sed 's/,//g')
	}
	[[ -z "$public_deps" ]] && {
		public_deps=${depends[*]}
		public_depends=${depends[*]}
	}
	public_url=$url
	public_arch=${arch[*]}
	public_pkgdesc=$pkgdesc
	public_license=${license[*]}
	public_source=${source[*]}
	public_validpgpkeys=${validpgpkeys[*]}
	public_sha256sums=${sha256sums[*]}

	LC_ALL=POSIX
	BASE=$(basename $WORKDIR/$fetch_pkgname-$pkgver)
	#	[[ $PKG_EXT = 'mz' ]] && FETCH_PKG=$LFS/repo/$BASE-$pkgrel || FETCH_PKG=$LFS/repo/$BASE-$pkgrel-x86_64
	[[ $PKG_EXT = 'mz' ]] && FETCH_PKG=$LFS/repo/$BASE-$pkgrel || FETCH_PKG=$LFS/repo/$BASE-$pkgrel-$public_arch
	repo=$FETCH_PKG
	mkdir -p $repo
	#  make -j$(nproc) DESTDIR=$FETCH_PKG install

	pushd $FETCH_PKG >/dev/null || return 1
	#	log_wait_msg "Unpacking $PACKAGE_DIR/$PKGNAME files..."
	log_msg "Unpacking $PACKAGE_DIR/$PKGNAME files..."
	tar -xvf $PACKAGE_DIR/$PKGNAME >/dev/null 2>&1
	#	log_wait_msg "Gziping arquivos man files..."
	log_msg "Gziping arquivos man files..."
	find $repo/usr/share/man/ -iname '*[0-9]' -type f -exec gzip -9 -f {} \; >/dev/null 2>&1
	#  fetch -Sg -f
	fetch -C --force
	cd ..

	fetch -Sl $FETCH_PKG --noconfirm
	popd >/dev/null || return 1
	LC_ALL=pt_BR.UTF8
	return 0
}
export -f mkfetch

log_wait_msg() {
	printf "${BMPREFIX}${@}"
	printf "${CURS_ZERO}${WAIT_PREFIX}${SET_COL}${WAIT_SUFFIX}\n"
	return 0
}

bashcat() {
	while IFS= read -r linha; do
		echo "$linha"
	done <"$1"
}

log_msg() {
	retval="$?"
	pcount=$#

	[ "$pcount" -ge 2 ] && {
		retval=$1
		shift
	}
	if [ "$retval" = 0 ]; then
		printf "%b\\n" " ${TICK} ${*}"
	else
		printf "%b\\n" " ${CROSS} ${*}"
		#		exit 1
	fi
}

die() {
	printf "%b\\n" " ${CROSS} ${*}"
	exit 1
}

abort() {
	retval="$1"
	shift
	if [ $# -ge 1 ]; then
		if [ "$retval" = 0 ]; then
			printf "%b\\n" " ${TICK} ${*}"
		else
			printf "%b\\n" " ${CROSS} ${*}"
		fi
	fi
	rm -f "$LOCK_FILE"
	pkg_cleanup
	exit "$retval"
}

ret() {
	retval="$1"
	shift
	if [ $# -ge 1 ]; then
		if [ "$retval" = 0 ]; then
			printf "%b\\n" " ${TICK} ${*}"
		else
			printf "%b\\n" " ${CROSS} ${*}"
		fi
	fi
	# remove lock and all tmp files on exit
	rm -f "$ROOT_DIR/$LOCK_FILE" "$TMP_PKGADD" "$TMP_PKGINSTALL" "$TMP_CONFLICT"
	exit "$retval"
}

log_error() {
	printf "%b\\n" "${BMPREFIX} $*"
	return 0
}

log_info_msg() {
	printf "%b" "${BMPREFIX} $*"
	return 0
}

log_success_msg() {
	#	printf "%b" "${BMPREFIX} $*"
	#	printf "%b" "${CURS_ZERO}${SUCCESS_PREFIX}${SET_COL}${SUCCESS_SUFFIX}"
	printf "%b\\n" "${CURS_ZERO}${SUCCESS_PREFIX}"
	return 0
}

log_skip_msg() {
	printf "%b\\n" "${CURS_ZERO}${IGNORE_PREFIX}"
	return 0
}

log_failure_msg() {
	#	printf "%b" "${BMPREFIX} $*"
	#	printf "%b" "${CURS_ZERO}${FAILURE_PREFIX}${SET_COL}${FAILURE_SUFFIX}"
	printf "%b\\n" "${CURS_ZERO}${FAILURE_PREFIX}"
	return 0
}

evaluate_retval() {
	error_value="$?"
	error_fatal="$2"
	cmsgdie="$3"

	[ -z "$error_fatal" ] && error_fatal=1

	if [ $# -gt 0 ]; then
		error_value="$1"
	fi

	if [ "$error_fatal" -eq 2 ]; then
		log_skip_msg ''
	elif [ "$error_value" -eq 0 ]; then
		log_success_msg ''
	else
		log_failure_msg ''
	fi

	if [ "$error_value" -ge 1 ]; then
		if [ "$error_fatal" -eq 1 ]; then
			if [ -z "$cmsgdie" ]; then
				die "Aborted!"
			else
				die "$cmsgdie"
			fi
		elif [ "$error_fatal" -eq 2 ]; then
			:
			#		else
			#			log_error "Error not fatal!"
		fi
	fi
	return "$error_value"
}

#--yesno "$*\n" \
#--backtitle "[debug]$0" \
#--title "[debug]$0[${LINENO[0]}]" \
debug() {
	#	local script_name0="${0##*/}[${FUNCNAME[0]}]:${BASH_LINENO[0]}"
	#	local script_name1="${0##*/}[${FUNCNAME[1]}]:${BASH_LINENO[1]}"
	#	local script_name2="${0##*/}[${FUNCNAME[2]}]:${BASH_LINENO[2]}"
	#	local afuncs
	#	local nfuncs=${#FUNCNAME[*]}
	#	for ((i = $nfuncs; i >= 1; i--)); do
	#		afuncs+="[${FUNCNAME[i]}:${BASH_LINENO[i - 1]}]"
	#	done
	#	local script_name3="${0##*/}$afuncs"
	#	local script_name3="${0##*/}$(
	#		IFS=,
	#		echo "[${FUNCNAME[*]:1}:${BASH_LINENO[*]:0:-1}]"
	#	)"

	#	local script_name="${BASH_SOURCE[0]##*/}"
	local func_seq=""

	for ((i = ${#FUNCNAME[@]} - 1; i >= 1; i--)); do
		func_seq+="[${BASH_SOURCE[i]##*/}=>${FUNCNAME[i]}:${BASH_LINENO[i - 1]}]"
	done

	whiptail \
		--fb \
		--clear \
		--backtitle "[debug]$0" \
		--title "$func_seq" \
		--yesno "$1\n$2\n$3\n$4\n$5\n" \
		0 40
	result=$?
	if (($result)); then
		exit
	fi
	return $result
}

sh_setvarcolors
