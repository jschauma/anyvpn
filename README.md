# anyvpn - a tool to connect to the Cisco AnyConnect VPN

Getting your corporate password from your password
manager whenever you connect to the VPN is a pain.
This tool can help you make this less painful and
hopefully encourage users to use a password manager.

At this time, this script supports the use of the
macOS keychain, LastPass, and 1Password.  For use with
LastPass, you need to install the `lpass` command-line
utility (available from e.g.,
[here](https://github.com/lastpass/lastpass-cli)); for
use with 1Password, you need to install the `op`
command-line utility (available from e.g.,
[here](https://support.1password.com/command-line-getting-started/)).



Installation
============

To install the command and manual page somewhere
convenient, run `make install`; the Makefile defaults
to '/usr/local' but you can change the PREFIX:

```
$ make PREFIX=~ install
```

Documentation
=============

Please see the manual page for all details:


```
NAME
     anyvpn - connect to a Cisco AnyConnect VPN

SYNOPSIS
     anyvpn [-Vhlv] [-m method] [-p app] [-s site] [-u user] on|off|sites

DESCRIPTION
     anyvpn is a simple script that allows you to connect to a Cisco AnyConnect
     VPN via the commandline by supplying your password and 2FA method so as to
     minimize interactions with the process.

OPTIONS
     The following options are supported by anyvpn:

     -V		Print the current version information and exit.

     -l		Log out of the password manager after fetching the password.

     -h		Display help and exit.

     -m method	Use this 2FA method.  Valid options are 'push' or a Duo 2FA
		code.  Defaults to 'push'.

     -p app	Use this password manager app.	Currently supported: keychain,
		lastpass, onepass.  If not specified, anyvpn will use
		'lastpass'.

     -s site	Connect to this site.  Defaults to the value of the VPN_SITE
		environment variable or, if that is unset, the first site
		condigured in AnyConnect.

     -u user	Set the username to use when connecting to the VPN.  This is
		similar to but overrides setting the value via the VPN_USER
		environment variable.  (This option exists to allow the user to
		use a different username ad-hoc, but set a default different
		from the local username for common usage.)

     -v		Be verbose.  Can be specified multiple times.

     Any other arguments are passed through to the AnyConnect VPN command.

DETAILS
     In order to connect to a VPN via Cisco AnyConnect, you may need to provide
     your password as well as a second factor.	Retrieving your password from a
     password manager can be cumbersome, since AnyConnect does not integrate
     with e.g., LastPass, leading to many people choosing to use an easy to
     remember VPN password.

     anyvpn provides the necessary glue to make it easier to connect to the VPN
     without having to unlock your password manager and copy and paste your
     password.

PASSWORD MANAGER CONSIDERATIONS
     In order to retrieve your password from your password manager, and unless
     you are using the macOS keychain (-p keychain), anyvpn needs to begin a
     session with the password manager or reuse an existing one.

     The behavior with respect to new sessions is as outlined below:

     o	 If an existing session is found ("lpass status -q" for lpass(1); a
	 valid session token in the ONEPASS_SESSION environment variable for
	 op(1)), anyvpn will reuse that session.

     o	 If no existing session is found, anyvpn will initiate a new session.

     Since a new session for op(1) is exposed only via an in-memory token,
     termination of anyvpn effectively makes that session unavailable for any
     other processes, even if it still remains technically active, which is why
     anyvpn explicitly invalidates it if it originally started it.

     On the other hand, a lpass(1) session initiated by anyvpn will remain
     active after the script terminates.  Such a valid password manager session
     may then allow other processes to access secrets from that password
     manager.  This is by design and can in fact be useful when using other
     tools that may require a password to be pulled from the password manager.

     To ensure anyvpn invalidates the newly started session, pass the -f flag.

EXIT STATUS
     The anyvpn utility will exit with a value of 255 if it encounters any
     problems prior to executing the AnyConnect 'vpn' command.	Otherwise,
     anyvpn will return with the exit value of the AnyConnect 'vpn' command.

EXAMPLES
     The following examples illustrate common usage of the anyvpn utility.

     To add a new password to the "VPN" keychain service and then use anyvpn to
     connect to the VPN using that password from the keychain:

	   security add-generic-password -a ${USER} -s VPN -w '<password>'
	   anyvpn -k keychain on

     To connect to the VPN using the password stored under the "Yahoo" login
     entry in your LastPass password manager for the "jschauma@yahoo.com"
     account:

	   export LASTPASS_LOGIN="jschauma@yahoo.com"
	   export PM_VPN_ENTRY="Yahoo"
	   anyvpn on

     To connect to the VPN using the password stored under the "Yahoo" login
     entry in your 1Password password manager for the "jschauma@yahoo.com"
     account in your company's team vault "mycorp.1password.com":

	   export USER="jschauma"
	   export DOMAIN="yahoo.com"
	   export PM_VPN_ENTRY="Yahoo"
	   export ONEPASS_ADDRESS="mycorp.1password.com"
	   anyvpn -p onepass on

     To connect to the "NYC" VPN site using an existing 1Password session from
     your personal 1Password account:

	   export ONEPASS_SESSION="$(op signin --raw)"
	   export PM_VPN_ENTRY="Yahoo"
	   anyvpn -s NYC -p onepass on

ENVIRONMENT
     The following environment variables affect the execution of this tool:

     ANYCONNECT_PREFIX	  The path to where AnyConnect is installed.  Defaults
			  to "/opt/cisco/anyconnect".

     DOMAIN		  The domain to use when constructing your
			  LASTPASS_LOGIN or ONEPASS_LOGIN ID.

			  If unset, then anyvpn will try to identify a suitable
			  domain by looking at /etc/resolv.conf or the output of
			  the hostname(1) command.

     KEYCHAIN_VPN_ENTRY	  The name of the keychain entry ("service") for your
			  VPN login.

			  If unset, then anyvpn will use "VPN".

     LASTPASS_LOGIN	  The full LastPass user ID.  This may be e.g.,
			  "first.lass@company.tld", "${USER}@company.name" etc.

			  If unset, then anyvpn will use "${USER}@${DOMAIN}".

     LASTPASS_VPN_ENTRY	  The name of the LastPass entry for your VPN login.

			  If unset, then anyvpn will use the value of the
			  PM_VPN_ENTRY environment variable.

     LPASS_AGENT_TIMEOUT  Not directly used by anyvpn, but used by lpass(1),
			  this variable defines in seconds the validity of your
			  LastPass session.  Set this to e.g., 28800 for an 8
			  hour LastPass cache validity.

     ONEPASS_ADDRESS	  The 1Password "sign in address".  If not specified,
			  defaults to "my.1password.com".  See
			  https://is.gd/BR670l for details.

     ONEPASS_LOGIN	  The 1Password user ID.  This may be e.g.,
			  "first.lass@company.tld", "${USER}@company.name" etc.

			  If unset, then anyvpn will use "${USER}@${DOMAIN}".

     ONEPASS_SESSION	  The 1Password op(1) session token to use.  Setting
			  this in your environment allows you to sign in to your
			  1Password account in your shell, and anyvpn to
			  retrieve the password without requiring your master
			  password to be entered.

			  If unset, then anyvpn will sign in to your 1Password
			  account, prompting you for your master password,
			  retrieve the VPN password, and then invalidate the
			  session.

     ONEPASS_VPN_ENTRY	  The name of the 1Password entry for your VPN login.

			  If unset, then anyvpn will use the value of the
			  PM_VPN_ENTRY environment variable.

     PM_VPN_ENTRY	  The name of the password manager entry for your VPN
			  login.  If unset, then anyvpn will use "VPN".

     USER		  The local username, as commonly set on most unix
			  systems.  This variable is not used directly, but some
			  of the other variables described here may derive their
			  default value from this variable.

			  If unset, then anyvpn will use the output of 'id -un'.

     VPN_SITE		  The name of the VPN site to connect to.  Supported
			  values can be shown by specifying sites as the
			  argument to anyvpn.

			  If unset, then anyvpn will use the first site
			  configured in AnyConnect.

     VPN_USER		  The short name / user ID, commonly your VPN or SSO
			  login name.

			  If unset, then anyvpn will use "${USER}".

			  Note: specifying the user via the -u flag overrides
			  this value.

SEE ALSO
     lpass(1), op(1), security(1)

HISTORY
     This script was originally written by Jan Schaumann
     <jschauma@netmeister.org> in June 2020.

BUGS
     Please file bugs and feature requests via GitHub pull requests and issues
     or by emailing the author.
```
