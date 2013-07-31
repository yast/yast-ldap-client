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

# File:	include/ldap/routines.ycp
# Package:	Configuration of LDAP
# Summary:	Helper routines for string manupulations
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
module Yast
  module LdapRoutinesInclude
    def initialize_ldap_routines(include_target)
      textdomain "ldap-client"

      Yast.import "Ldap"
    end

    # Get RDN (relative distinguished name) from dn
    def get_rdn(dn)
      dn_list = Builtins.splitstring(dn, ",")
      Ops.get_string(dn_list, 0, dn)
    end

    # Get first value from dn (don't have to be "cn")
    def get_cn(dn)
      rdn = get_rdn(dn)
      Builtins.issubstring(rdn, "=") ?
        Builtins.substring(rdn, Ops.add(Builtins.search(rdn, "="), 1)) :
        rdn
    end

    # Create DN from cn by adding base config DN
    # (Can't work in general cases!)
    def get_dn(cn)
      Builtins.sformat("cn=%1,%2", cn, Ldap.base_config_dn)
    end

    # Create new DN from DN by changing leading cn value
    # (Can't work in general cases!)
    def get_new_dn(cn, dn)
      Builtins.tolower(
        Builtins.sformat(
          "cn=%1%2",
          cn,
          Builtins.issubstring(dn, ",") ?
            Builtins.substring(dn, Builtins.search(dn, ",")) :
            ""
        )
      )
    end

    # Get string value of attribute from map.
    # (Generaly, it is supposed to be list or string.)
    def get_string(object, attr)
      object = deep_copy(object)
      if Ops.is_list?(Ops.get(object, attr))
        return Ops.get_string(object, [attr, 0], "")
      end
      Ops.get_string(object, attr, "")
    end
  end
end
