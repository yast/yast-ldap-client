#
# Makefile.am for y2c_ldap_client/src
#
# $Id$
#

yincludedir = $(YAST2DIR)/include/ldap_client
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries

client_DATA =		\
	ldap_client.ycp		\
	ldap_client_auto.ycp	\
	ldap_client_write.ycp

yinclude_DATA =		\
	ui.ycp

module_DATA =		\
	Ldapclient.ycp

config_DATA = ldap_client.y2cc 

EXTRA_DIST = $(client_DATA) $(yinclude_DATA) $(module_DATA) $(config_DATA)
