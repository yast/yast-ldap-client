#
# Makefile.am for y2c_ldap_client/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/ldap_client
modulesdir = $(YAST2DIR)/modules
menudir = $(YAST2DIR)/menuentries

clients_DATA =		\
	ldap_client.ycp		\
	ldap_client_auto.ycp	\
	ldap_client_write.ycp

include_DATA =		\
	ui.ycp

modules_DATA =		\
	Ldapclient.ycp

menu_DATA = menuentry_ldap_client.y2cc 

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(modules_DATA) $(menu_DATA) 
