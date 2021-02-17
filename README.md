# anyvpn - a tool to connect to the Cisco AnyConnect VPN

Getting your corporate password from your password
manager whenever you connect to the VPN is a pain.
This tool can help you make this less painful and
hopefully encourage users to use a password manager.

At this time, this script only supports the use of
LastPass and requires the `lpass` command-line utility
(available from e.g.,
[here](https://github.com/lastpass/lastpass-cli)) to
be installed.

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
     anyvpn -- connect to a Cisco AnyConnect VPN

SYNOPSIS
     anyvpn [-Vhv] [-m method] [-s site] on|off|sites

DESCRIPTION
     anyvpn is a simple script that allows you to connect to a Cisco AnyCon-
     nect VPN via the commandline by supplying your password and 2FA method so
     as to minimize interactions with the process.

OPTIONS
     The following options are supported by anyvpn:

     -V		Print the current version information and exit.

     -h		Display help and exit.

     -m method	Use this 2FA method.  Valid options are 'push' or a Duo 2FA
		code.  Defaults to 'push'.

     -s site	Connect to this site.  Defaults to the value of the VPN_SITE
		environment variable or, if that is unset, the first site con-
		figured in AnyConnect.

     -v		Be verbose.  Can be specified multiple times.

     Any other arguments are passed through to the AnyConnect VPN command.

DETAILS
     In order to connect to a VPN via Cisco AnyConnect, you may need to pro-
     vide your password as well as a second factor.  Retrieving your password
     from a password manager can be cumbersome, since AnyConnect does not
     integrate with e.g., LastPass, leading to many people choosing to use an
     easy to remember VPN password.

     anyvpn provides the necessary glue to make it easier to connect to the
     VPN without having to unlock your password manager and copy and paste
     your password.

EXIT STATUS
     The anyvpn utility will exit with a value of 255 if it encounters any
     problems prior to executing the AnyConnect 'vpn' command.	Otherwise,
     anyvpn will return with the exit value of the AnyConnect 'vpn' command.

ENVIRONMENT
     The following environment variables affect the execution of this tool:

     ANYCONNECT_PREFIX	  The path to where AnyConnect is installed.  Defaults
			  to "/opt/cisco/anyconnect".

     DOMAIN		  If LASTPASS_LOGIN is unset, then anyvpn will attempt
			  to construct a reasonable login address for Last-
			  Pass, using this domain.  If unset, anyvpn will try
			  to identify a suitable domain by looking at
			  /etc/resolv.conf or the output of the hostname(1)
			  command.

     LASTPASS_LOGIN	  The full LastPass user ID.  This may be e.g.,
			  "first.lass@company.tld", "${USER}@company.name"
			  etc.

			  If unset, then anyvpn will use "${USER}@${DOMAIN}".

     LASTPASS_VPN_ENTRY	  The name of the LastPass entry for your VPN login.

			  If unset, then anyvpn will use "VPN".

     USER		  The local username, as commonly set on most unix
			  systems.  This variable is not used directly, but
			  some of the other variables described here may
			  derive their default value from this variable.

			  If unset, then anyvpn will use the output of 'id
			  -un'.

     VPN_SITE		  The name of the VPN site to connect to.  Supported
			  values can be shown by specifying sites as the argu-
			  ment to anyvpn.

			  If unset, then anyvpn will use the first site con-
			  figured in AnyConnect.

     VPN_USER		  The short name / user ID, commonly your VPN or SSO
			  login name.

			  If unset, then anyvpn will use "${USER}".

SEE ALSO
     lpass(1)

HISTORY
     This script was originally written by Jan Schaumann
     <jschauma@netmeister.org> in June 2020.

BUGS
     Please report issues to the author via pull requests or email.
```
