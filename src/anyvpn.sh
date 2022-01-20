#! /bin/sh
#
# This script can be used to use Cisco Anyconnect to
# connect to a VPN and have lpass(1) or op(1) provide
# the password.

set -eu

PROGNAME="${0##*/}"
VERSION="1.0"
VERBOSITY=0

# These will be determined below in setVariables()
_DOMAIN=""

_LP_LOGIN=""
_OP_LOGIN=""
_SITES=""
_VPN_SITE=""
_VPN_USER=""

_FAIL=255
_FORCE_LOGOUT=0

_2FA="push"
_ANYCONNECT_PREFIX="${ANYCONNECT_PREFIX:-"/opt/cisco/anyconnect"}"
_ANYCONNECT="${_ANYCONNECT_PREFIX}/bin/vpn"
_LPASS="$(which lpass || true)"
_OPASS="$(which op || true)"
_OPASS_SIGNIN_ADDRESS="${ONEPASS_ADDRESS:-"my.1password.com"}"
_PASSWORD_MANAGER="lastpass"
_VPN_PW=""

_PM_VPN="${PM_VPN_ENTRY:-"VPN"}"
_LP_VPN="${LASTPASS_VPN_ENTRY:-"${_PM_VPN}"}"
_OP_VPN="${ONEPASS_VPN_ENTRY:-"${_PM_VPN}"}"

###
### Functions
###

checkAnyconnectState() {
	local state="$1"

	if [ x"${state}" != x"connected" ] && [ x"${state}" != x"disconnected" ]; then
		echo "Invalid state: ${state}" >&2
		exit ${_FAIL}
	fi

	if ${_ANYCONNECT} state 2>&1 | grep -q -i "state: ${state}" >/dev/null 2>&1; then
		echo "Already ${state}." >&2
		exit ${_FAIL}
		# NOTREACHED
	fi
}

checkEnv() {
	local l found

	case "${_PASSWORD_MANAGER}" in
		lpass)
			_PASSWORD_MANAGER="lastpass"
		;;
		opass|1pass|1password)
			_PASSWORD_MANAGER="onepass"
		;;
	esac

	if [ x"${_PASSWORD_MANAGER}" = x"lastpass" ]; then
		if [ -z "${_LPASS}" ]; then
			echo "Unable to find 'lpass(1)' in your PATH." >&2
			echo "Please install the lastpass-cli via e.g., 'brew install lastpass-cli' or from" >&2
			echo "https://github.com/lastpass/lastpass-cli"
			exit ${_FAIL}
		fi
	elif [ x"${_PASSWORD_MANAGER}" = x"onepass" ]; then
		if [ -z "${_OPASS}" ]; then
			echo "Unable to find the 'op(1)' in your PATH." >&2
			echo "Please install the 1Password command-line client from" >&2
			echo "https://support.1password.com/command-line-getting-started/" >&2
			exit ${_FAIL}
		fi
	else
		echo "Unsupported password manager." >&2
		exit ${_FAIL}
		# NOTREACHED
	fi

	if [ ! -x "${_ANYCONNECT}" ]; then
		echo "Unable to find '${_ANYCONNECT}'." >&2
		exit ${_FAIL}
	fi

	oIFS="${IFS}"
	IFS='
'

	found=0
	for l in ${_SITES}; do
		if [ x"${_VPN_SITE}" = x"${l}" ]; then
			found=1
			break
		fi
	done
	IFS="${oIFS}"

	if [ ${found} -ne 1 ]; then
		echo "Invalid VPN_SITE '${_VPN_SITE}'." >&2
		echo "Supported sites:" >&2
		echo "${_SITES}" >&2
		exit ${_FAIL}
		# NOTREACHED
	fi

	if [ x"${_2FA}" != x"push" ] &&
		! expr "${_2FA}" : "[0-9]*$" >/dev/null 2>&1 ; then
		echo "Invalid 2FA method '${_2FA}'." >&2
		exit ${_FAIL}
		# NOTREACHED
	fi
}

connectToVPN() {
	verbose "Connecting to '${_VPN_SITE}' as '${_VPN_USER}' with 2FA method '${_2FA}'..." 2

	${_ANYCONNECT} -s << EOF
connect "${_VPN_SITE}"
${_VPN_USER}
${_VPN_PW}
${_2FA}
EOF
}

getPasswordFromLastPass() {
	verbose "Trying to get your VPN password from LastPass..." 2

	if ! ${_LPASS} status -q; then
		verbose "Trying to log into LastPass..." 3
		${_LPASS} login "${_LP_LOGIN}"
	fi
	
	_VPN_PW="$(${_LPASS} show "${_LP_VPN}" --password)"
	if [ -z "${_VPN_PW}" ]; then
		echo "Got an empty password from LastPass??" >&2
		exit ${_FAIL}
		# NOTREACHED
	fi

	if expr "${_VPN_PW}" : "Multiple matches found." >/dev/null 2>&1; then
		echo "${_VPN_PW}" >&2
		echo >&2
		echo "If both are identical, you could delete one or the other." >&2
		echo "If they are different, you could rename one or the other." >&2
		echo "If you want to keep both as they are, then please set" >&2
		echo "the LASTPASS_VPN_ENTRY environment variable to the correct ID." >&2
		exit ${_FAIL}
		# NOTREACHED
	fi
}

getPasswordFromOnePass() {
	verbose "Trying to get your VPN password from 1Password..." 2

	local token="${ONEPASS_SESSION:-""}"
	local args="${_OPASS_SIGNIN_ADDRESS}"
	local signin=0

	if [ -z "${token}" ]; then
		verbose "Signing into 1Password..." 3
		# Provide the complete signin address only the
		# first time op signs in.  This will require
		# the user to provide the "Secret Key".
		if [ ! -f ~/.op/config ]; then
			args="${args} ${_OP_LOGIN}"
		fi
		token="$(${_OPASS} signin --raw "${args}")"
		signin=1
	fi

	_VPN_PW="$(${_OPASS} --session "${token}" get item "${_OP_VPN}" --fields password)"
	if [ -z "${_VPN_PW}" ]; then
		echo "Got an empty password from 1Password??" >&2
		exit ${_FAIL}
		# NOTREACHED
	fi

	if [ ${signin} -eq 1 ]; then
		verbose "Signing out of 1Password..." 3
		${_OPASS} --session "${token}" signout
	fi
}

getPasswordFromPasswordManager() {
	case "${_PASSWORD_MANAGER}" in
		lastpass)
			getPasswordFromLastPass
		;;
		onepass)
			getPasswordFromOnePass
		;;
	esac

	if [ ${_FORCE_LOGOUT} -gt 0 ]; then
		logoutPass
	fi
}

listSites() {
	echo "The following values are supported for VPN_SITE:"
	echo "${_SITES}"
	exit 0
}

logoutPass() {
	verbose "Logging out of ${_PASSWORD_MANAGER}..."

	case "${_PASSWORD_MANAGER}" in
		lastpass)
			${_LPASS} logout -f
		;;
		# For 1Password, we explicitly log in, or require a login
		# session to already exist.  If that already exists, we
		# don't want to log the user out here, so noop.
	esac
}

setVariables() {
	local domain
	local user

	if [ -n "${_DOMAIN:-""}" ]; then
		domain="${_DOMAIN}"
	elif [ -n "${DOMAIN:-""}" ]; then
		domain="${DOMAIN}"
	elif [ -f "/etc/resolv.conf" ]; then
		domain="$(sed -n -E 's/^(search|domain) ([^ ]+).*/\2/p' /etc/resolv.conf)"
	else
		# 'hostname -f' is not portable
		domain="$(hostname)"
	fi

	if [ -n "${USER:-""}" ]; then
		user="${USER}"
	else
		user="$(id -un)"
	fi

	_LP_LOGIN="${LASTPASS_LOGIN:-"${user}@${domain}"}"
	_OP_LOGIN="${ONEPASS_LOGIN:-"${user}@${domain}"}"

	_VPN_USER="${VPN_USER:-"${user}"}"

	_SITES="$(sed -n -e 's/.*<HostName>\(.*\)<\/HostName>.*/\1/p' ${_ANYCONNECT_PREFIX}/profile/*.xml)"

	if [ -n "${VPN_SITE:-""}" ]; then
		_VPN_SITE="${VPN_SITE}"
	else
		_VPN_SITE="$(echo "${_SITES}" | head -1)"
	fi
}

usage() {
	cat <<EOH
Usage: ${PROGNAME} [-Vhlv] [-m method] [-p app] [-s site] on|off|sites
	-V         print version number and exit
	-h         print this help and exit
	-l         log out of the password manager after fetching the password
	-m method  use this 2FA method (default: push)
	-p app     use this password manager (lastpass, onepass; default: lastpass)
	-s site    connect to this site (default: ${_VPN_SITE})
	-v         be verbose
EOH
}

verbose() {
	local msg="${1}"
	local level="${2:-1}"
	local i=0

	if [ ${level} -le ${VERBOSITY} ]; then
		while [ ${i} -lt ${level} ]; do
			printf "=" >&2
			i=$(( ${i} + 1 ))
		done
		echo "> ${msg}" >&2
	fi
}

vpnOff() {
	verbose "Disconnecting from VPN..."

	checkAnyconnectState "disconnected"
	${_ANYCONNECT} disconnect
}

vpnOn() {
	verbose "Connecting to VPN..."

	checkAnyconnectState "connected"
	getPasswordFromPasswordManager
	connectToVPN
}

###
### Main
###

setVariables

while getopts 'Vhlm:p:s:v' opt; do
	case ${opt} in
		V)
			echo "${PROGNAME} Version ${VERSION}"
			exit 0
			# NOTREACHED
		;;
		h\?)
			usage
			exit 0
			# NOTREACHED
		;;
		l)
			_FORCE_LOGOUT=1
		;;
		m)
			_2FA="${OPTARG}"
		;;
		p)
			_PASSWORD_MANAGER="${OPTARG}"
		;;
		s)
			_VPN_SITE="${OPTARG}"
		;;
		v)
			VERBOSITY=$(( ${VERBOSITY} + 1 ))
		;;
		*)
			usage
			exit 1
			# NOTREACHED
		;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
	usage
	exit 1
	# NOTREACHED
fi

checkEnv

case "${1}" in
	off)
		vpnOff
	;;
	on)
		vpnOn
	;;
	sites)
		listSites
	;;
	*)
		${_ANYCONNECT} "$@"
	;;
esac
