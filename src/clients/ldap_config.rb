# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	clients/ldap.ycp
# Module:	Configuration of LDAP client
# Summary:	Manage the configuration stored in LDAP directory
#		(e.g. user/group templates)
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  class LdapConfigClient < Client
    def main
      Yast.import "UI"
      Yast.import "Ldap"
      Yast.import "Wizard"

      Yast.include self, "ldap/ui.rb"

      @param = ""
      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @param = Convert.to_string(WFM.Args(0))
      end
      Builtins.y2debug("param=%1", @param)

      @ret = LDAPReadDialog()
      return deep_copy(@ret) if @ret != :next

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("ldap")

      @ret = ModuleConfigurationDialog()

      if @ret == :next && Ldap.ldap_modified
        Ldap.WriteLDAP(Ldap.templates) if Ldap.WriteLDAP(Ldap.config_modules)
      end

      Wizard.CloseDialog

      deep_copy(@ret)
    end
  end
end

Yast::LdapConfigClient.new.main
