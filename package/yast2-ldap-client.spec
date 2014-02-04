#
# spec file for package yast2-ldap-client
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-ldap-client
Version:        3.1.5
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
BuildRequires:	doxygen perl-XML-Writer update-desktop-files yast2 yast2-pam yast2-testsuite yast2-network
BuildRequires:  yast2-devtools >= 3.1.10

PreReq:         %fillup_prereq

# SLPAPI.pm
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22

Requires:	yast2-network

# .close
Requires:	yast2-ldap >= 2.20.1

# etc_sssd_conf.scr
Requires:	yast2-pam >= 2.20.0

Provides:	yast2-config-ldap_client
Obsoletes:	yast2-config-ldap_client
Provides:	yast2-trans-ldap_client
Obsoletes:	yast2-trans-ldap_client

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - LDAP Client Configuration

%description
With this YaST2 module you can configure an LDAP client so that an
OpenLDAP server will be used for user authentication.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%post
%{fillup_only -n ldap}

%files
%defattr(-,root,root)
%{yast_desktopdir}/ldap.desktop
%{yast_desktopdir}/ldap_browser.desktop
%dir %{yast_yncludedir}/ldap
%{yast_yncludedir}/ldap/*
%{yast_moduledir}/Ldap.rb
%{yast_moduledir}/LdapPopup.rb
%{yast_clientdir}/ldap*.rb
%{yast_scrconfdir}/*.scr
%{yast_schemadir}/autoyast/rnc/ldap_client.rnc
%doc %{yast_docdir}

/var/adm/fillup-templates/sysconfig.ldap
