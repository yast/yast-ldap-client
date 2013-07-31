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

# File:	clients/ldap_auto.ycp
# Package:	Configuration of LDAP client
# Summary:	Client for autoinstallation
# Authors:	Thorsten Kukuk <kukuk@suse.de>
#		Anas Nashif <nashif@suse.de>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param first a map of LDAP settings
# @return [Hash] edited settings or an empty map if canceled
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallModule ("ldap_auto", [ mm ]);
module Yast
  class LdapAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "ldap-client"
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Ldap auto started")

      Yast.import "Ldap"
      Yast.include self, "ldap/wizards.rb"


      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)


      @abort_block = lambda { false }

      # Import Data
      if @func == "Import"
        @ret = Ldap.Import(@param)
      # Create a  summary
      elsif @func == "Summary"
        @ret = Ldap.Summary
      # Reset configuration
      elsif @func == "Reset"
        Ldap.Import({})
        Ldap.modified = false
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = LdapAutoSequence()
      # Return actual state
      elsif @func == "Export"
        @ret = Ldap.Export
      elsif @func == "Read"
        @ret = Ldap.Read
      # Return if configuration  was changed
      # return boolean
      elsif @func == "GetModified"
        @ret = Ldap.modified
      # Set modified flag
      # return boolean
      elsif @func == "SetModified"
        Ldap.modified = true
        @ret = true
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        Ldap.write_only = true
        @progress_orig = Progress.set(false)
        @ret = Ldap.Write(@abort_block)
        Progress.set(@progress_orig)
      elsif @func == "Packages"
        @ret = Ldap.AutoPackages
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Ldap auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::LdapAutoClient.new.main
