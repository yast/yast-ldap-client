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

# File:	include/ldap-client/wizards.ycp
# Package:	Configuration of ldap-client
# Summary:	Wizards definitions
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
module Yast
  module LdapWizardsInclude
    def initialize_ldap_wizards(include_target)
      Yast.import "UI"

      textdomain "ldap-client"

      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Stage"

      Yast.include include_target, "ldap/ui.rb"
    end

    # Main workflow of the ldap-client configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "ldap"      => lambda { LdapDialog() },
        "advanced"  => lambda { AdvancedConfigurationDialog() },
        "configure" => lambda { ModuleConfigurationDialog() },
        "read_ldap" => [lambda { LDAPReadDialog() }, true]
      }

      sequence = {
        "ws_start"  => "ldap",
        "ldap"      => {
          :abort    => :abort,
          :cancel   => :abort,
          :advanced => "advanced",
          :next     => :next
        },
        "read_ldap" => {
          :abort  => :abort,
          :cancel => :abort,
          :next   => "configure",
          :skip   => "ldap"
        },
        "advanced"  => {
          :abort     => :abort,
          :cancel    => :abort,
          :next      => "ldap",
          :configure => "read_ldap"
        },
        "configure" => {
          :abort  => :abort,
          :cancel => :abort,
          :next   => "advanced"
        }
      }

      ret = Sequencer.Run(aliases, sequence)

      deep_copy(ret)
    end

    # Whole configuration of ldap-client but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def LdapAutoSequence
      # dialog label
      caption = _("LDAP Client Configuration")
      # label (init dialog)
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("ldap")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = MainSequence()

      UI.CloseDialog
      Convert.to_symbol(ret)
    end

    # Whole configuration of ldap-client
    # @return sequence result
    def LdapSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      if Stage.cont
        Wizard.CreateDialog
      else
        Wizard.OpenNextBackDialog
        Wizard.HideAbortButton
      end
      Wizard.SetDesktopTitleAndIcon("ldap")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      Convert.to_symbol(ret)
    end
  end
end
