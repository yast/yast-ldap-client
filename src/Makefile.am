#
# Makefile.am for y2c_ldap_client/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
yincludedir = $(YAST2DIR)/include/ldap_client
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	ldap_client.ycp		\
	ldap_client_auto.ycp	\
	ldap_client_write.ycp

yinclude_DATA =		\
	ui.ycp

modules_DATA =		\
	Ldapclient.ycp

menu_DATA = menuentry_ldap_client.y2cc 

EXTRA_DIST = $(clients_DATA) $(yinclude_DATA) $(modules_DATA) $(menu_DATA) 
