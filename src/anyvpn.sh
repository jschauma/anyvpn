#! /bin/sh
#
# This script can be used to use Cisco Anyconnect to
# connect to a VPN and have lpass(1) or op(1) provide
# the password.

set -eu

PROGNAME="${0##*/}"
VERSION="1.4"
VERBOSITY=0

# These will be determined below in setVariables()
_DOMAIN=""
_DOMAIN_SRC="default         "

_LP_LOGIN=""
_OP_LOGIN=""
_SITES=""
_VPN_SITE=""
_VPN_USER=""

_FAIL=255
_FLAGS=""
_FORCE_LOGOUT=0

_2FA="push"
_ANYCONNECT_PREFIX="${ANYCONNECT_PREFIX:-"/opt/cisco/anyconnect"}"
_ANYCONNECT="${_ANYCONNECT_PREFIX}/bin/vpn"
_KC="$(which security || true)"
_LPASS="$(which lpass || true)"
_OPASS="$(which op || true)"
_OPASS_SIGNIN_ADDRESS="${ONEPASS_ADDRESS:-"my.1password.com"}"
_PASSWORD_MANAGER="lastpass"
_VPN_PW=""

_PM_VPN="${PM_VPN_ENTRY:-"VPN"}"
_KC_VPN="${KEYCHAIN_VPN_ENTRY:="${_PM_VPN}"}"
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
	elif [ x"${_PASSWORD_MANAGER}" = x"keychain" ]; then
		if [ -z "${_KC}" ]; then
			echo "Unable to find 'security(1)' in your PATH." >&2
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

dumpVars() {
	verbose "Dumping the values of all relevant variables we use..."

	local ac="default             "
	if [ -n "${ANYCONNECT_PREFIX:-""}" ]; then
		ac="\${ANYCONNECT_PREFIX}"
	fi

	local pm="${_LPASS}"
	local pmentry="default              "
	if [ -n "${PM_VPN_ENTRY:-""}" ]; then
		pmentry="\${PM_VPN_ENTRY}      "
	fi
	local pmval="${_PM_VPN}"
	local pmlogin="\${user}@\${domain}"
	local pmloginval
	case "${_PASSWORD_MANAGER}" in
		"lastpass")
			pm="${_LPASS}"
			pmloginval="${_LP_LOGIN}"
			if [ -n "${LASTPASS_VPN_ENTRY:-""}" ]; then
				pmentry="\${LASTPASS_VPN_ENTRY}"
				pmval="${_LP_VPN}"
			fi
			if [ -n "${LASTPASS_LOGIN:=""}" ]; then
				pmlogin="\${LASTPASS_LOGIN}"
			fi
		;;
		"onepass")
			pm="${_OPASS}"
			pmloginval="${_OP_LOGIN}"
			if [ -n "${ONEPASS_VPN_ENTRY:-""}" ]; then
				pmentry="\${ONEPASS_VPN_ENTRY} "
				pmval="${_OP_VPN}"
			fi
			if [ -n "${ONEPASS_LOGIN:=""}" ]; then
				pmlogin="\${ONEPASS_LOGIN} "
			fi
		;;
		"keychain")
			pm="${_KC}"
			pmlogin="N/A"
			pmloginval="N/A"
			if [ -n "${KEYCHAIN_VPN_ENTRY:-""}" ]; then
				pmentry="\${KEYCHAIN_VPN_ENTRY}"
				pmval="${_KC_VPN}"
			fi
		;;
	esac
	local pmo="default"
	if expr "${_FLAGS}" : ".* p" >/dev/null; then
		pmo="-p     "
	fi

	local vpnu="\${USER}    "
	if [ -n "${VPN_USER:-""}" ]; then
		vpnu="\${VPN_USER}"
	fi
	if expr "${_FLAGS}" : ".* u" >/dev/null; then
		vpnu="-u         "
	fi

	local vpns="default    "
	if [ -n "${VPN_SITE:-""}" ]; then
		vpns="\${VPN_SITE}"
	fi
	if expr "${_FLAGS}" : ".* s" >/dev/null; then
		vpns="-s         "
	fi

	local mfo="default"
	if expr "${_FLAGS}" : ".* m" >/dev/null; then
		mfo="-m     "
	fi

	cat <<EOF
Setting                      Derived from            Value used
-----------------------------------------------------------------------------
AnyConnect Path              ${ac}    "${_ANYCONNECT_PREFIX}"
Domain                       ${_DOMAIN_SRC}        "${_DOMAIN}"
MFA Option                   ${mfo}                 "${_2FA}"
Password Manager             ${pmo}                 "${_PASSWORD_MANAGER}"
Password Manager Executable                          "${pm}"
Password Manager Entry       ${pmentry}   "${pmval}"
Password Manager Login       ${pmlogin}       "${pmloginval}
VPN User                     ${vpnu}             "${_VPN_USER}"
VPN Site                     ${vpns}             "${_VPN_SITE}"
EOF
}

getPasswordFromKeychain() {
	verbose "Trying to get your VPN password from the keychain..." 2

	_VPN_PW="$(${_KC} find-generic-password -a ${USER} -s ${_KC_VPN} -w || true)"
	if [ -z "${_VPN_PW}" ]; then
		echo "Unable to retrieve password from keychain service '${_KC_VPN}'." >&2
		exit ${_FAIL}
		# NOTREACHED
	fi
}

getPasswordFromLastPass() {
	verbose "Trying to get your VPN password from LastPass..." 2

	# 'lpass status' may sometimes report being
	# "Logged in as (null)", and 'lpass status -q'
	# would return successfully, so we can't rely
	# on that and instead have to check for an
	# email address.
	if ! ${_LPASS} status | grep -q -i 'Logged in as .*@'; then
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
		keychain)
			getPasswordFromKeychain
		;;
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
	local user

	if [ -n "${DOMAIN:-""}" ]; then
		_DOMAIN="${DOMAIN}"
		_DOMAIN_SRC="\${DOMAIN}     "
	elif [ -z "${_DOMAIN:-""}" ]; then
		if [ -f "/etc/resolv.conf" ]; then
			_DOMAIN="$(sed -n -E 's/^(search|domain) ([^ ]+).*/\2/p' /etc/resolv.conf)"
			_DOMAIN_SRC="/etc/resolv.conf"
	else
		# 'hostname -f' is not portable
			_DOMAIN="$(hostname)"
			_DOMAIN_SRC="hostname(1)     "
		fi
	fi

	if [ -n "${USER:-""}" ]; then
		user="${USER}"
	else
		user="$(id -un)"
	fi

	_LP_LOGIN="${LASTPASS_LOGIN:-"${user}@${_DOMAIN}"}"
	_OP_LOGIN="${ONEPASS_LOGIN:-"${user}@${_DOMAIN}"}"

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
Usage: ${PROGNAME} [-Vhlv] [-m method] [-p app] [-s site] [-u user] on|off|sites|vars
	-V         print version number and exit
	-h         print this help and exit
	-l         log out of the password manager after fetching the password
	-m method  use this 2FA method (default: push)
	-p app     use this password manager (keychain, lastpass, onepass; default: lastpass)
	-s site    connect to this site (default: ${_VPN_SITE})
	-u user    use this username to connect to the VPN (default: ${_VPN_USER})
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

while getopts 'Vhlm:p:s:u:v' opt; do
	_FLAGS="${_FLAGS} ${opt}"
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
		u)
			_VPN_USER="${OPTARG}"
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
	vars)
		dumpVars
	;;
	*)
		${_ANYCONNECT} "$@"
	;;
esac
