# Sources for ldap-client

module_DATA = \
  modules/Ldap.rb \
  modules/LdapPopup.rb

client_DATA = \
  clients/ldap.rb \
  clients/ldap_browser.rb \
  clients/ldap_auto.rb \
  clients/ldap-client.rb \
  clients/ldap_config.rb

yncludedir = @yncludedir@/ldap
ynclude_DATA = \
  include/ldap/wizards.rb \
  include/ldap/ui.rb \
  include/ldap/routines.rb

scrconf_DATA = \
  scrconf/cfg_ldap.scr \
  scrconf/nscd_conf.scr \
  scrconf/ldap_conf.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/ldap_client.rnc

desktop_DATA = \
  desktop/ldap.desktop \
  desktop/ldap_browser.desktop

fillup_DATA = \
  fillup/sysconfig.ldap

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA) $(fillup_DATA)

include $(top_srcdir)/Makefile.am.common