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

# File:	clients/ldap/ldap_browser.ycp
# Package:	Configuration of LDAP
# Summary:	Simple browser and editor of LDAP tree
# Author:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
#
module Yast
  class LdapBrowserClient < Client
    def main
      Yast.import "UI"
      Yast.import "CommandLine"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "LdapPopup"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include self, "ldap/routines.rb"

      textdomain "ldap-client"

      @cmdline = { "id" => "ldap_browser", "mappings" => {} }
      if Ops.greater_than(Builtins.size(WFM.Args), 0)
        return CommandLine.Run(@cmdline)
      end

      @root_dn = ""
      @current_dn = ""
      @data = {}
      @tmp_data = {}
      # map of already read subtrees
      @dns = {}
      @subdns = []
      @tree_items = []
      @topdns = {}
      @open_items = {}

      @help_text =
        # general help text for LDAP browser
        _("<p>Browse the LDAP tree in the left part of the dialog.</p>") +
          # help text for LDAP browser
          _(
            "<p>Once the LDAP object is selected in the tree, the table shows the object data. Use <b>Edit</b> to change the value of the selected attribute. Use <b>Save</b> to save your changes to LDAP.</p>"
          )

      # popup question (Continue/Cancel follows)
      @unsaved = _(
        "There are unsaved changes in the current entry.\nDiscard these changes?\n"
      )

      @contents = HBox(
        HWeight(1, ReplacePoint(Id(:treeContents), Top(HBox()))),
        HWeight(1, ReplacePoint(Id(:entryContents), Top(HBox())))
      )
      @display_info = UI.GetDisplayInfo
      @textmode = Ops.get_boolean(@display_info, "TextMode", false)

      Wizard.CreateDialog

      Wizard.SetDesktopTitleAndIcon("ldap_browser")
      # dialog caption
      Wizard.SetContentsButtons(
        _("LDAP Browser"),
        @contents,
        @help_text,
        "",
        Label.CloseButton
      )

      Wizard.HideBackButton
      Wizard.HideAbortButton

      # read current LDAP configuration
      Ldap.Read

      @configurations = []
      @configurations_file = Ops.add(Directory.vardir, "/ldap_servers.ycp")
      # combobox item
      @default_name = _("Current LDAP Client settings")
      @configuration = {
        "server"   => Ldap.GetFirstServer(Ldap.server),
        "bind_dn"  => Ldap.GetBindDN,
        "ldap_tls" => Ldap.ldap_tls,
        "name"     => @default_name
      }
      # read configuration of LDAP browser
      if FileUtils.Exists(@configurations_file)
        @configurations = Convert.to_list(
          SCR.Read(path(".target.ycp"), @configurations_file)
        )
        if @configurations == nil || !Ops.is_list?(@configurations)
          @configurations = []
        end
      end
      @configurations = [@configuration] if @configurations == []

      @configuration = Ops.get_map(@configurations, 0, {})
      # ask which LDAP connection to choose
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(0.2),
          VBox(
            VSpacing(0.2),
            HSpacing(40),
            HBox(
              ReplacePoint(
                Id(:rpcombo),
                ComboBox(
                  Id(:configs),
                  Opt(:hstretch, :notify),
                  # combo box label
                  _("LDAP Connections"),
                  []
                )
              ),
              VBox(Label(""), PushButton(Id(:add), Label.AddButton)),
              VBox(Label(""), PushButton(Id(:delete), Label.DeleteButton))
            ),
            # textentry label
            InputField(
              Id("server"),
              Opt(:hstretch, :notify),
              _("LDAP Server"),
              Ops.get_string(@configuration, "server", "")
            ),
            InputField(
              Id("bind_dn"),
              Opt(:hstretch, :notify),
              # textentry label
              _("Administrator DN"),
              Ops.get_string(@configuration, "bind_dn", "")
            ),
            # password entering label
            Password(Id("pw"), Opt(:hstretch), _("&LDAP Server Password")),
            VSpacing(0.2),
            # check box label
            Left(
              CheckBox(
                Id("ldap_tls"),
                Opt(:notify),
                _("L&DAP TLS"),
                Ops.get_boolean(@configuration, "ldap_tls", false)
              )
            ),
            ButtonBox(
              PushButton(Id(:ok), Opt(:key_F10, :default), Label.OKButton),
              # button label
              PushButton(Id(:anon), Opt(:key_F6), _("A&nonymous Access")),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
            ),
            VSpacing(0.2)
          ),
          HSpacing(0.2)
        )
      )

      @current_name = Ops.get_string(@configuration, "name", "")
      update_connection_items(@current_name)
      @ret = nil
      while true
        @ret = UI.UserInput
        @conf = Convert.to_integer(UI.QueryWidget(Id(:configs), :Value))

        # save configuration currently selected before switching to new one
        if @ret == :ok || @ret == :anon || Ops.is_string?(@ret)
          @configuration = Ops.get_map(@configurations, @conf, {})
          @current_name = Ops.get_string(@configuration, "name", "")
          if @current_name != @default_name
            Builtins.foreach(["server", "bind_dn", "ldap_tls"]) do |s|
              Ops.set(@configuration, s, UI.QueryWidget(Id(s), :Value))
            end
            @i = -1
            @configurations = Builtins.maplist(
              Convert.convert(
                @configurations,
                :from => "list",
                :to   => "list <map>"
              )
            ) do |c|
              @i = Ops.add(@i, 1)
              @i == @conf ? @configuration : c
            end
          end
        end
        if @ret == :configs
          @configuration = Ops.get_map(@configurations, @conf, {})
          @current_name = Ops.get_string(@configuration, "name", "")
          UI.ChangeWidget(Id(:delete), :Enabled, @current_name != @default_name)
          Builtins.foreach(["server", "bind_dn", "ldap_tls"]) do |s|
            UI.ChangeWidget(Id(s), :Enabled, @current_name != @default_name)
            UI.ChangeWidget(
              Id(s),
              :Value,
              s == "ldap_tls" ?
                Ops.get_boolean(@configuration, s, false) :
                Ops.get_string(@configuration, s, "")
            )
          end
        end
        if @ret == :add
          UI.OpenDialog(
            Opt(:decorated),
            HBox(
              HSpacing(0.2),
              VBox(
                VSpacing(0.2),
                InputField(
                  Id(:new),
                  # InputField label
                  _("Enter the name of the new LDAP connection")
                ),
                ButtonBox(
                  PushButton(Id(:ok), Opt(:default), Label.OKButton),
                  PushButton(Id(:cancel), Label.CancelButton)
                )
              ),
              HSpacing(0.2)
            )
          )
          @r = UI.UserInput
          @new = Convert.to_string(UI.QueryWidget(Id(:new), :Value))
          UI.CloseDialog
          next if @r == :cancel || @new == ""
          @configuration = { "name" => @new }
          @configurations = Builtins.add(@configurations, @configuration)
          update_connection_items(@new)
        end
        if @ret == :delete
          @configurations = Builtins.remove(@configurations, @conf)
          update_connection_items(@default_name)
        end
        if @ret == :ok || @ret == :anon
          Ldap.server = Convert.to_string(UI.QueryWidget(Id("server"), :Value))
          Ldap.bind_dn = Convert.to_string(
            UI.QueryWidget(Id("bind_dn"), :Value)
          )
          Ldap.bind_pass = Convert.to_string(UI.QueryWidget(Id("pw"), :Value))
          Ldap.ldap_tls = Convert.to_boolean(
            UI.QueryWidget(Id("ldap_tls"), :Value)
          )
          Ldap.SetAnonymous(@ret == :anon)

          @error = Ldap.LDAPInitWithTLSCheck({})
          if @error != ""
            Ldap.LDAPErrorMessage("init", @error)
            next
          end

          @error = Ldap.LDAPBind(Ldap.bind_pass)
          if @error != ""
            Ldap.LDAPErrorMessage("bind", @error)
            next
          end
          @error = Ldap.InitSchema
          if @error != ""
            Ldap.LDAPErrorMessage("schema", @error)
            next
          end
          break
        end
        break if @ret == :cancel
      end
      UI.CloseDialog
      if @ret == :cancel
        Wizard.CloseDialog
        return deep_copy(@ret)
      end
      SCR.Write(path(".target.ycp"), @configurations_file, @configurations)

      # LDAP initialized, we can open the browser now

      set_tree_term

      @current_dn = Convert.to_string(UI.QueryWidget(Id(:tree), :CurrentItem))
      @current_dn = "" if @current_dn == nil

      set_entry_term
      UI.SetFocus(Id(:tree)) if @textmode

      @result = :notnext
      @current = :ldaptree

      while true
        @event = UI.WaitForEvent
        @result = Ops.get_symbol(@event, "ID")

        @result = :not_next if @result == :cancel && !Popup.ReallyAbort(false)

        break if @result == :back || @result == :cancel

        @result = :tree if @result == :open

        @current_dn = Convert.to_string(UI.QueryWidget(Id(:tree), :CurrentItem))
        @current_dn = "" if @current_dn == nil

        # switch to different entry while current was modified
        if @result == :tree && Modified()
          if Popup.ContinueCancel(@unsaved)
            # discard the changes
            @tmp_data = {}
          else
            @result = :not_next
            next
          end
        end

        # events in tree
        if @result == :tree
          if !Ops.get(@dns, @current_dn, false)
            UI.BusyCursor
            @subdns = Convert.convert(
              SCR.Read(
                path(".ldap.search"),
                {
                  "base_dn"      => @current_dn,
                  "scope"        => 1,
                  "dn_only"      => true,
                  "not_found_ok" => true
                }
              ),
              :from => "any",
              :to   => "list <string>"
            )
            if @subdns == nil
              Builtins.y2warning(
                "the search for %1 returned nil...",
                @current_dn
              )
              next
            else
              @subdns = Builtins.sort(@subdns)
            end
            Ops.set(@dns, @current_dn, true)
            if Ops.greater_than(Builtins.size(@subdns), 0)
              # TODO if size (subdns) > 0) || dn has glyph
              @open_items = Convert.to_map(UI.QueryWidget(:tree, :OpenItems))
              @tree_items = update_items(@tree_items)
              UI.ReplaceWidget(
                Id(:reptree),
                @textmode ?
                  Tree(Id(:tree), @root_dn, @tree_items) :
                  Tree(Id(:tree), Opt(:notify), @root_dn, @tree_items)
              )
              UI.ChangeWidget(Id(:tree), :CurrentItem, @current_dn)
              @open_items = {}
            end
            @current_dn = Convert.to_string(
              UI.QueryWidget(Id(:tree), :CurrentItem)
            )
            @current_dn = "" if @current_dn == nil
          end
          @data = Ldap.GetLDAPEntry(@current_dn)
          @tmp_data = {}
          set_entry_term
          UI.NormalCursor
          UI.SetFocus(Id(:tree)) if @textmode
        end

        if @result == :reload
          @tree_items = []
          @open_items = {}
          @dns = {}
          @topdns = {}
          @subdns = []
          @root_dn = ""
          set_tree_term
        end
        # events in Edit Entry part
        @result = :table if @result == :edit
        if @result == :table &&
            Ops.get_string(@event, "EventReason", "") == "SelectionChanged"
          @attr = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          @enable = true
          if Ops.less_than(Builtins.size(@attr), Builtins.size(@current_dn)) &&
              Builtins.substring(
                @current_dn,
                0,
                Ops.add(Builtins.size(@attr), 1)
              ) ==
                Ops.add(@attr, "=")
            Builtins.y2debug("disabling %1 for editing...", @attr)
            @enable = false
          end
          @enable = false if @attr == "objectClass"
          UI.ChangeWidget(Id(:edit), :Enabled, @enable)
        elsif @result == :table
          @attr = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          if UI.QueryWidget(Id(:edit), :Enabled) == false
            Builtins.y2milestone(
              "editing the value of attribute '%1' is not allowed",
              @attr
            )
            @result = :notnext
            next
          end
          @value = Ops.get_list(
            @tmp_data,
            @attr,
            Ops.get_list(@data, @attr, [])
          )
          @value = LdapPopup.EditAttribute(
            {
              "attr"   => @attr,
              "value"  => @value,
              "single" => Ldap.SingleValued(@attr)
            }
          )
          if @value ==
              Ops.get_list(@tmp_data, @attr, Ops.get_list(@data, @attr, []))
            @result = :notnext
            next
          end
          UI.ChangeWidget(
            Id(:table),
            term(:Item, @attr, 1),
            Builtins.mergestring(@value, ",")
          )
          UI.ChangeWidget(Id(:save), :Enabled, true)
          Ops.set(@tmp_data, @attr, @value)
        end
        if @result == :save
          if Modified()
            @cont = false
            Builtins.foreach(Ops.get_list(@data, "objectClass", [])) do |oc|
              next if @cont
              Builtins.foreach(Ldap.GetRequiredAttributes(oc)) do |attr|
                val = Ops.get(@tmp_data, attr)
                if !@cont && (val == [] || val == "")
                  #error popup, %1 is attribute name
                  Popup.Error(
                    Builtins.sformat(
                      _("The \"%1\" attribute is mandatory.\nEnter a value."),
                      attr
                    )
                  )
                  UI.SetFocus(Id(:table))
                  @cont = true
                end
              end
            end
            if @cont
              @result = :not_next
              next
            end
            if Ops.get_string(@tmp_data, "modified", "") == ""
              Ops.set(@tmp_data, "modified", "edited")
            end
            if Ldap.WriteLDAP({ @current_dn => @tmp_data })
              @tmp_data = {}
              UI.ChangeWidget(Id(:save), :Enabled, false)
            end
          end
        end

        # general events
        if @result == :next
          if Modified() && !Popup.ContinueCancel(@unsaved)
            @result = :not_next
            next
          end
          break
        end
      end
      Wizard.CloseDialog
      :finish
    end

    # helper: data modified?
    def Modified
      Ops.greater_than(Builtins.size(@tmp_data), 0)
    end


    # helper: create the value that should be shown instead of whole DN in tree
    def show_dn(dn)
      return dn if Ops.get_boolean(@topdns, dn, false)
      get_rdn(dn)
    end

    # helper for set_tree_term function: create new items for subtrees
    def update_items(its)
      its = deep_copy(its)
      Builtins.maplist(its) do |it|
        dn = Ops.get_string(it, [0, 0], "")
        if dn == @current_dn
          next Item(Id(dn), show_dn(dn), true, Builtins.maplist(@subdns) do |k|
            Item(Id(k), show_dn(k), false, [])
          end)
        end
        last = Ops.subtract(Builtins.size(it), 1)
        next deep_copy(it) if Builtins.size(Ops.get_list(it, last, [])) == 0
        # `OpenItems doesn't work in ncurses...
        open = Builtins.haskey(@open_items, dn) && !@textmode
        Item(
          Id(dn),
          show_dn(dn),
          open,
          update_items(Ops.get_list(it, last, []))
        )
      end
    end

    # -----------------------------
    # create the term with LDAP tree
    def set_tree_term
      cont = HBox(
        VSpacing(20),
        VBox(
          HSpacing(70),
          VSpacing(0.2),
          HBox(
            HSpacing(),
            ReplacePoint(Id(:reptree), Tree(Id(:tree), @root_dn, [])),
            ReplacePoint(Id(:repbuttons), Empty()),
            HSpacing()
          ),
          HBox(
            HSpacing(1.5),
            HStretch(),
            @textmode ?
              # button label
              PushButton(Id(:open), Opt(:key_F6), _("&Open")) :
              Empty(),
            # button label
            PushButton(Id(:reload), Opt(:key_F8), _("&Reload")),
            HSpacing(1.5)
          ),
          VSpacing(0.6)
        )
      )

      UI.ReplaceWidget(:treeContents, cont)

      if Builtins.size(@tree_items) == 0
        out = Convert.convert(
          SCR.Read(
            path(".ldap.search"),
            {
              "base_dn"      => @root_dn,
              "scope"        => 1,
              "dn_only"      => true,
              "not_found_ok" => true
            }
          ),
          :from => "any",
          :to   => "list <string>"
        )
        if Ops.greater_than(Builtins.size(out), 0)
          @tree_items = Builtins.maplist(out) do |dn|
            Ops.set(@dns, dn, false)
            Ops.set(@topdns, dn, true)
            Item(Id(dn), dn, false, [])
          end
        end
      end

      if Ops.greater_than(Builtins.size(@tree_items), 0)
        UI.ReplaceWidget(
          Id(:reptree),
          @textmode ?
            Tree(Id(:tree), @root_dn, @tree_items) :
            Tree(Id(:tree), Opt(:notify), @root_dn, @tree_items)
        )
        # no item is selected
        UI.ChangeWidget(:tree, :CurrentItem, nil)
      elsif @root_dn == ""
        bases = Convert.to_list(
          SCR.Read(
            path(".ldap.search"),
            { "base_dn" => "", "scope" => 0, "attrs" => ["namingContexts"] }
          )
        )
        if Ops.greater_than(Builtins.size(bases), 0)
          @tree_items = Builtins.maplist(
            Ops.get_list(bases, [0, "namingContexts"], [])
          ) do |dn|
            Ops.set(@topdns, dn, true)
            Item(Id(dn), dn, false, [])
          end
        end
        if Ops.greater_than(Builtins.size(@tree_items), 0)
          UI.ReplaceWidget(
            Id(:reptree),
            @textmode ?
              Tree(Id(:tree), @root_dn, @tree_items) :
              Tree(Id(:tree), Opt(:notify), @root_dn, @tree_items)
          )
          UI.ChangeWidget(:tree, :CurrentItem, nil)
        end
        if Builtins.size(@topdns) == 1
          @root_dn = Ops.get_string(bases, [0, "namingContexts", 0], "")
        end
      end

      UI.SetFocus(Id(:tree)) if @textmode

      UI.ChangeWidget(Id(:tree), :CurrentItem, @current_dn) if @current_dn != ""

      nil
    end

    # -----------------------------
    # create the term with LDAP entry data table
    def set_entry_term
      items = []

      # generate table items from already existing values
      Builtins.foreach(
        Convert.convert(@data, :from => "map", :to => "map <string, any>")
      ) do |attr, val|
        next if Ops.is_map?(val) || val == nil
        value = []
        if Ops.is_list?(val)
          value = Convert.convert(val, :from => "any", :to => "list <string>")
        end
        if Ops.is_byteblock?(val) ||
            Ops.is_list?(val) && Ops.is_byteblock?(Ops.get(value, 0))
          Builtins.y2warning("binary value (%1) cannot be edited", attr)
          next
        elsif Ops.is_integer?(val)
          value = [Builtins.sformat("%1", val)]
          Ops.set(@data, attr, value)
        elsif Ops.is_string?(val)
          value = [Convert.to_string(val)]
          Ops.set(@data, attr, value)
        end
        items = Builtins.add(
          items,
          Item(Id(attr), attr, Builtins.mergestring(value, ","))
        )
      end

      # generate table items with empty values
      # (not set for this user/group yet)
      # we need to read available attributes from Ldap
      Builtins.foreach(
        Convert.convert(
          Builtins.sort(Ops.get_list(@data, "objectClass", [])),
          :from => "list",
          :to   => "list <string>"
        )
      ) do |_class|
        Builtins.foreach(
          Convert.convert(
            Ldap.GetAllAttributes(_class),
            :from => "list",
            :to   => "list <string>"
          )
        ) do |at|
          if !Builtins.haskey(@data, at)
            Ops.set(@data, at, [])
            items = Builtins.add(items, Item(Id(at), at, ""))
          end
        end
      end

      cont = HBox(
        HSpacing(1.5),
        VBox(
          Left(Label(@current_dn)),
          Table(
            Id(:table),
            Opt(:notify, :immediate),
            Header(
              # table header 1/2
              _("Attribute") + "  ",
              # table header 2/2
              _("Value")
            ),
            items
          ),
          HBox(
            PushButton(Id(:edit), Opt(:key_F4), Label.EditButton),
            HStretch(),
            PushButton(Id(:save), Opt(:key_F2), Label.SaveButton)
          ),
          VSpacing(0.5)
        ),
        HSpacing(1.5)
      )

      UI.ReplaceWidget(:entryContents, cont)

      if Builtins.size(items) == 0
        UI.ChangeWidget(Id(:edit), :Enabled, false)
      else
        # no item is selected
        UI.ChangeWidget(:table, :CurrentItem, nil)
      end

      UI.ChangeWidget(Id(:edit), :Enabled, false)
      UI.ChangeWidget(Id(:save), :Enabled, false)
      UI.SetFocus(Id(:table))

      nil
    end

    # helper function: generate items for combo box
    def connection_items(selected)
      i = -1
      Builtins.maplist(
        Convert.convert(@configurations, :from => "list", :to => "list <map>")
      ) do |conf|
        i = Ops.add(i, 1)
        Item(
          Id(i),
          Ops.get_string(conf, "name", ""),
          Ops.get_string(conf, "name", "") == selected
        )
      end
    end

    # update the combo box with LDAP connections list
    def update_connection_items(selected)
      UI.ChangeWidget(Id(:delete), :Enabled, selected != @default_name)
      UI.ReplaceWidget(
        Id(:rpcombo),
        ComboBox(
          Id(:configs),
          Opt(:hstretch, :notify),
          # combo box label
          _("LDAP Connections"),
          connection_items(selected)
        )
      )
      Builtins.foreach(["server", "bind_dn", "ldap_tls"]) do |s|
        UI.ChangeWidget(Id(s), :Enabled, selected != @default_name)
        UI.ChangeWidget(
          Id(s),
          :Value,
          s == "ldap_tls" ?
            Ops.get_boolean(@configuration, s, false) :
            Ops.get_string(@configuration, s, "")
        )
      end

      nil
    end
  end
end

Yast::LdapBrowserClient.new.main
