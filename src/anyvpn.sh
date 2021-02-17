#! /bin/sh
#
# This script can be used to use Cisco Anyconnect to
# connect to a VPN and have lpass(1) provide the
# password.

set -eu

PROGNAME="${0##*/}"
VERSION="0.4"
VERBOSITY=0

# These will be determined below in setVariables()
_LP_LOGIN=""
_SITES=""
_VPN_SITE=""
_VPN_USER=""

_FAIL=255

_2FA="push"
_ANYCONNECT_PREFIX="${ANYCONNECT_PREFIX:-"/opt/cisco/anyconnect"}"
_ANYCONNECT="${_ANYCONNECT_PREFIX}/bin/vpn"
_LPASS="$(which lpass || true)"
_LP_VPN="${LASTPASS_VPN_ENTRY:-"VPN"}"
_VPN_PW=""

###
### Functions
###

checkEnv() {
	local l found

	if [ -z "${_LPASS}" ]; then
		echo "Unable to find 'lpass(1)' in your PATH." >&2
		echo "Please install the lastpass-cli via e.g., 'brew install lastpass-cli' or from" >&2
		echo "https://github.com/lastpass/lastpass-cli"
		exit ${_FAIL}
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
}

listSites() {
	echo "The following values are supported for VPN_SITE:"
	echo "${_SITES}"
	exit 0
}

setVariables() {
	local domain
	local user

	if [ -n "${DOMAIN:-""}" ]; then
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
	_LP_VPN="${LASTPASS_VPN_ENTRY:-"VPN"}"
	_VPN_USER="${VPN_USERNAME:-"${user}"}"

	_SITES="$(sed -n -e 's/.*<HostName>\(.*\)<\/HostName>.*/\1/p' ${_ANYCONNECT_PREFIX}/profile/*.xml)"

	if [ -n "${VPN_SITE:-""}" ]; then
		_VPN_SITE="${VPN_SITE}"
	else
		_VPN_SITE="$(echo "${_SITES}" | head -1)"
	fi
}

usage() {
	cat <<EOH
Usage: ${PROGNAME} [-hv] [-m method] on|off|sites
	-V         print version number and exit
	-h         print this help and exit
	-m method  use this 2FA method (default: push)
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
	${_ANYCONNECT} disconnect
}

vpnOn() {
	verbose "Connecting to VPN..."
	getPasswordFromLastPass
	connectToVPN
}

###
### Main
###

setVariables

while getopts 'Vhlm:s:v' opt; do
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
		m)
			_2FA="${OPTARG}"
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
