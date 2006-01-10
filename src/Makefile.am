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
	ldap-client.ycp	\
	ldap_config.ycp	\
	ldap_browser.ycp

ynclude_DATA =		\
	ui.ycp		\
	wizards.ycp	\
	routines.ycp

module_DATA =		\
	Ldap.ycp	\
	LdapPopup.ycp

desktop_DATA = ldap.desktop

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

ldap:
	ln -sf . ldap

ycpchook = ldap

include $(top_srcdir)/Makefile.am.common
