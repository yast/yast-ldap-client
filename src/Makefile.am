#
# Makefile.am for ldap-client/src
#
# $Id$
#

yncludedir = @yncludedir@/ldap

YCPCFLAGS = -I .

client_DATA =		\
	ldap.ycp	\
	ldap_auto.ycp	\
	ldap-client.ycp

ynclude_DATA =		\
	ui.ycp		\
	wizards.ycp	\
	routines.ycp

module_DATA =		\
	Ldap.ycp	\
	LdapPopup.ycp

desktop_DATA = ldap.desktop

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

symlinks:
	test -L ldap || ln -sf . ldap

ycpchook = symlinks

include $(top_srcdir)/Makefile.am.common
