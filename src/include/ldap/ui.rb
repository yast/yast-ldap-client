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

# File:	include/ldap/ui.ycp
# Package:	Configuration of LDAP
# Summary:	User interface functions.
# Authors:	Thorsten Kukuk <kukuk@suse.de>
#		Anas Nashif <nashif@suse.de>
#
# $Id$
#
# All user interface functions.
module Yast
  module LdapUiInclude
    def initialize_ldap_ui(include_target)
      Yast.import "UI"
      textdomain "ldap-client"

      Yast.import "Address"
      Yast.import "Autologin"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Ldap"
      Yast.import "LdapPopup"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Pam"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "SLPAPI"
      Yast.import "Stage"
      Yast.import "Wizard"

      Yast.include include_target, "ldap/routines.rb"
    end

    def Modified
      Ldap.modified || Ldap.ldap_modified
    end

    # The dialog that appears when the [Abort] button is pressed.
    # @return `abort if user really wants to abort, `back otherwise
    def ReallyAbort
      ret = Modified() || Stage.cont ? Popup.ReallyAbort(true) : true

      if ret
        return :abort
      else
        return :back
      end
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      ret = Ldap.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `next
    def WriteDialog
      # popup text
      abort = lambda do
        if UI.PollInput == :abort &&
            # popup text
            Popup.YesNo(_("Really abort the writing process?"))
          next true
        end
        false
      end

      if Modified()
        # help text
        Wizard.RestoreHelp(_("Writing LDAP Client Settings"))
        return Ldap.Write(abort)
      end
      :next
    end

    # Check syntax of entry with servers:
    # multiple adresses are allowed (separated by spaces), address may contain
    # port number
    def check_address(servers)
      ret = true
      Builtins.foreach(Builtins.splitstring(servers, " \t")) do |server|
        next if server == ""
        if Builtins.issubstring(server, ":")
          pos = Builtins.search(server, ":")
          port = Builtins.substring(server, Ops.add(pos, 1))
          if port == "" || Builtins.tointeger(port) == nil
            ret = false
          else
            ret = ret && Address.Check(Builtins.substring(server, 0, pos))
          end
        else
          ret = ret && Address.Check(server)
        end
      end
      ret
    end

    # Select from LDAP servers provided by SLP
    def BrowseServers
      servers = ""

      UI.OpenDialog(
        # popup window
        Label(_("Scanning for LDAP servers provided by SLP..."))
      )

      UI.BusyCursor

      items = []
      Builtins.foreach(SLPAPI.FindSrvs("service:ldap", "")) do |service|
        s = Ops.get_string(service, "pcHost", "")
        # TODO take address+port from url
        # if (service["pcHost"]:"" == "")
        # 		s	= service["srvurl"]:"";
        items = Builtins.add(items, s) if s != ""
      end
      UI.CloseDialog
      UI.OpenDialog(
        VBox(
          HSpacing(36),
          ReplacePoint(
            Id(:rp),
            MultiSelectionBox(
              Id(:sel),
              # multiselection box label
              _("LDAP &Servers Provided by SLP"),
              items
            )
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      UI.NormalCursor
      ret = ""
      begin
        ret = UI.UserInput
        servers = Builtins.mergestring(
          Convert.convert(
            UI.QueryWidget(Id(:sel), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          ),
          " "
        )
      end while ret != :ok && ret != :cancel

      UI.CloseDialog
      ret == :ok ? servers : ""
    end

    # Try to check if certificate file has a valid format (bnc#792413)
    # (Just a simple check, for a warning that something might be wrong)
    # Return the check result
    def check_certificate(file)
      # first, check for DER encoded certificate
      if FileUtils.Exists("/usr/bin/openssl") &&
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/usr/bin/openssl x509 -in %1 -inform der", file)
          ) == 0
        return true
      end

      # check the contents of possible plain text certificates
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "grep -I '\\-----BEGIN CERTIFICATE' %1 && grep -I '\\-----END CERTIFICATE' %1",
            file
          )
        )
      )
      if Ops.get_integer(out, "exit", 1) != 0
        # warning popup
        Popup.Warning(
          _("The certificate file does not seem to have valid format.")
        )
        return false
      end
      true
    end

    def switch_ssl_config_widgets mode
      switch =
        case mode
          when :on  then true
          when :off then false
        end

      [
        :protocols,
        :tls_cacertdir,
        :br_tls_cacertdir,
        :tls_cacertfile,
        :br_tls_cacertfile,
        :url,
        :import_cert,
        :request_server_certificate
      ].each {|widget_id| UI.ChangeWidget(Id(widget_id), :Enabled, switch) }
    end

    # Popup for TLS/SSL related stuff
    def SSLConfiguration
      certTmpFile = Builtins.sformat("%1/__LDAPcert.crt", Directory.tmpdir)
      tls_cacertdir = Ldap.tls_cacertdir
      tls_cacertfile = Ldap.tls_cacertfile
      use_tls = Ldap.ldap_tls
      use_ldaps = Ldap.ldaps
      request_server_certificate = Ldap.request_server_certificate

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          VBox(
            VSpacing(0.6),
            HSpacing(75),
            Frame(
              _("SSL/TLS Configuration"),
              HBox(
                VBox(
                  Left(
                    CheckBox(
                      Id(:secure_ldap),
                      Opt(:notify),
                      _("Use SSL/TLS"),
                      Ldap.use_secure_connection?
                    )
                  ),
                  HSpacing(1),
                  VBox(
                    VSpacing(0.5),
                    HSpacing(75),
                    Frame(
                      _("Protocols"),
                      HBox(
                        HSpacing(0.5),
                        VBox(
                          VSpacing(0.4),
                          RadioButtonGroup(
                            Id(:protocols),
                            Left(
                              HVSquash(
                                VBox(
                                  Left(
                                    RadioButton(
                                      Id(:use_tls),
                                      Opt(:notify),
                                      _("StartTLS"),
                                      use_tls
                                    )
                                  ),
                                  Left(
                                    RadioButton(
                                      Id(:use_ldaps),
                                      Opt(:notify),
                                      _("LDAPS"),
                                      use_ldaps
                                    )
                                  ),
                                )
                              )
                            )
                          ),
                          VSpacing(0.4)
                        )
                      )
                    ),
                    VSpacing(0.5),
                    Frame(
                      _("TLS Options"),
                      HBox(
                        HSpacing(0.5),
                        VBox(
                          VSpacing(0.4),
                          HBox(
                            Left(
                              CheckBox(
                                Id(:request_server_certificate),
                                Opt(:notify),
                                _("Request server certificate"),
                                request_server_certificate == 'demand'
                              )
                            )
                          )
                        )
                      )
                    ),
                    VSpacing(0.5),
                    Frame(
                      _("Certificates"),
                      HBox(
                        HSpacing(0.5),
                        VBox(
                          VSpacing(0.4),
                          HBox(
                            InputField(
                              Id(:tls_cacertdir),
                              Opt(:hstretch),
                              # inputfield label
                              _("Cer&tificate Directory"),
                              tls_cacertdir
                            ),
                            VBox(
                              Bottom(
                                # button label
                                PushButton(Id(:br_tls_cacertdir), _("B&rowse"))
                              )
                            )
                          ),
                          HBox(
                            InputField(
                              Id(:tls_cacertfile),
                              Opt(:hstretch),
                              # inputfield label
                              _("CA Cert&ificate File"),
                              tls_cacertfile
                            ),
                            VBox(
                              Bottom(
                                # button label
                                PushButton(Id(:br_tls_cacertfile), _("Brows&e"))
                              )
                            )
                          ),
                          HBox(
                            InputField(
                              Id(:url),
                              Opt(:hstretch),
                              # inputfield label
                              _("CA Certificate URL for Download")
                            ),
                            VBox(
                              Bottom(
                                # push button label
                                PushButton(Id(:import_cert), _("Do&wnload CA Certificate"))
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          ),
          VSpacing(0.4)
        ),
        HSpacing(1)
        )
      )

      switch_ssl_config_widgets(:off) unless Ldap.use_secure_connection?

      result = :again

      begin
        result = Convert.to_symbol(UI.UserInput)

        case result
        when :secure_ldap
          secure_ldap = UI.QueryWidget(Id(:secure_ldap), :Value)
          case secure_ldap
          when true
            switch_ssl_config_widgets(:on)
          when false
            switch_ssl_config_widgets(:off)
            use_ldaps = false
            use_tls = false
          end

        when :use_tls
          use_tls = true
          use_ldaps = false
          Ldap.modified = true
          UI.ChangeWidget(Id(:request_server_certificate), :Value, true)

        when :use_ldaps
          use_ldaps = true
          use_tls = false
          Ldap.modified = true
          UI.ChangeWidget(Id(:request_server_certificate), :Value, true)

        when :request_server_certificate
          widget_checked = UI.QueryWidget(Id(:request_server_certificate), :Value)
          request_server_certificate = widget_checked ? 'demand' : 'allow'

        when :br_tls_cacertdir
          dir = UI.AskForExistingDirectory(
            tls_cacertdir,
            # popup label
            _("Choose the directory with certificates")
          )
          if dir != nil
            tls_cacertdir = dir
            UI.ChangeWidget(Id(:tls_cacertdir), :Value, dir)
          end

        when :br_tls_cacertfile
          file = UI.AskForExistingFile(
            tls_cacertfile,
            "*.pem *.crt",
            # popup label
            _("Choose the certificate file")
          )
          if file != nil
            check_certificate(file)
            tls_cacertfile = file
            UI.ChangeWidget(Id(:tls_cacertfile), :Value, file)
          end

        when :import_cert
          dir = tls_cacertdir
          dir = "/etc/openldap/cacerts/" if dir == ""

          success = false
          name = ""

          cert_url = Convert.to_string(UI.QueryWidget(Id(:url), :Value))
          curlcmd = Builtins.sformat(
            "curl -f --connect-timeout 60  --max-time 120  '%1' -o  %2",
            cert_url,
            certTmpFile
          )

          if SCR.Execute(path(".target.bash"), curlcmd) != 0
            # error message
            Popup.Error(
              _("Could not download the certificate file from specified URL.")
            )
          elsif FileUtils.CheckAndCreatePath(dir) &&
              check_certificate(certTmpFile)
            l = Builtins.splitstring(cert_url, "/")
            name = Ops.get(
              l,
              Ops.subtract(Builtins.size(l), 1),
              "downloaded-by-yast2-ldap-client.pem"
            )
            success = SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/bin/cp -a '%1' '%2/%3'",
                certTmpFile,
                dir,
                name
              )
            ) == 0
            # rehash cert directory (bnc#662937)
            out = Convert.to_map(
              SCR.Execute(
                path(".target.bash_output"),
                Builtins.sformat("/usr/bin/c_rehash %1", dir)
              )
            )
            if Ops.get_string(out, "stderr", "") != ""
              Builtins.y2error("something went wrong: %1", out)
            end
          end

          if success
            # popup message, %1 is file name, %2 directory
            Popup.Message(
              Builtins.sformat(
                _(
                  "The downloaded certificate file\n" +
                    "\n" +
                    "'%1'\n" +
                    "\n" +
                    "has been copied to '%2' directory.\n"
                ),
                name,
                dir
              )
            )

            tls_cacertdir = dir
            Ldap.modified = true
          end
        end

      end while result != :ok && result != :cancel

      UI.CloseDialog

      if result == :ok
        Ldap.tls_cacertfile = tls_cacertfile
        Ldap.tls_cacertdir = tls_cacertdir
        Ldap.request_server_certificate = request_server_certificate
        Ldap.ldap_tls = use_tls
        Ldap.ldaps = use_ldaps
      end

      result == :ok
    end

    # The main dialog for ldap-client configuration
    # @return	`back, `next or `abort
    def LdapDialog
      # help text 1/9
      help_text = _("<p>Set up your machine as an LDAP client.</p>\n") +
        # help text 2/9
        _(
          "<p>To authenticate your users with an OpenLDAP server, select <b>Use LDAP</b>. NSS and PAM will be configured accordingly.</p>"
        ) +
        # help text 3/9
        _(
          "<p>To deactivate LDAP services, click <b>Do Not Use LDAP</b>.\n" +
            "If you deactivate LDAP, the current LDAP entry for passwd in /etc/nsswitch.conf\n" +
            "will be removed. The PAM configuration will be modified and the LDAP entry\n" +
            "removed.</p>"
        ) +
        # help text 3.5/9
        _(
          "<p>To activate LDAP but forbid users from logging in to this machine, select <b>Enable LDAP Users but Disable Logins</b>.</p>"
        ) +
        # help text
        _(
          "<p>Check <b>Use System Security Services Daemon</b> if you want the system to use SSSD instead of nss_ldap.</p>"
        ) +
        # help text 4/9
        _(
          "<p>Enter the LDAP server's address (such as ldap.example.com or 10.20.0.2) in <b>Addresses</b> and the distinguished name of the search base (<b>Base DN</b>, such as dc=example,dc=com). Specify multiple servers\n" +
            "by separating their addresses with spaces. It must be possible to resolve the\n" +
            "addresses without using LDAP. You can also specify the port on which the server is running using the syntax \"server:port\", for example, <tt>ldap.example.com:379</tt>.\n" +
            "</p>\n"
        ) +
        # help text 5/9
        _(
          "<p>With <b>Find</b>, select the LDAP server from the list provided by the service location protocol (SLP). Using <b>Fetch DN</b>, read the base DN from server.</p>"
        ) +
        # help text 6/9
        _(
          "<p>Some LDAP servers support StartTLS (RFC2830).\n" +
            "If your server supports it and it is configured, activate <b>LDAP TLS/SSL</b>\n" +
            "to encrypt your communication with the LDAP server. You may download a CA\n" +
            "certificate file in PEM format from a given URL.</p>\n"
        ) +
        _(
          "<p>A TLS session may require special client configuration. One of the config
           options is TLS_REQCERT which specifies what checks to perform on server certificates.
           The value is the <b>level</b> that can be specified with keywords <i>never</i>, <i>allow</i>,
           <i>try</i> and <i>demand</i>. In the <b>SSL/TLS Configuration</b> dialog there is
           the option <b>Request server certificate</b> which will set the TLS_REQCERT
           configuration option to <i>demand</i> if it's enabled or to <i>allow</i> if it's disabled.</p>\n"
        ) +
        _(
          "<p>In addition to LDAP URLs and TLS/SSL encryption, LDAP supports LDAPS URLs.
          LDAPS URLs use SSL connections instead of plain connections. They have a syntax
          similar to LDAP URLs except the schemes are different and the default port for LDAPS URLs
          is 636 instead of 389.</p>\n"
        ) +
        # help text 8/9
        _(
          "<p>To configure advanced LDAP settings, click\n<b>Advanced Configuration</b>.</p>\n" +
          "<p>To configure security settings, click\n<b>SSL/TLS Configuration</b>.</p>\n"
        )
      # help text 9/9 (additional)
      autofs_help_text = _(
        "<p><b>Automounter</b> is a daemon that automatically mounts directories, such\n" +
          "as users' home directories. Its configuration files (auto.*) should already\n" +
          "exist locally or over LDAP. If the automounter is not installed yet but you\n" +
          "want to use it, it will be installed automatically.</p>\n"
      )


      # during installation, starting ldap is default
      installation = Stage.cont && !Builtins.contains(WFM.Args, "from_users")
      start = Ldap.start || installation
      base_dn = Ldap.GetBaseDN
      server = Ldap.server
      ldap_tls = Ldap.ldap_tls
      tls_checkpeer = Ldap.tls_checkpeer
      login_enabled = Ldap.login_enabled
      ssl_changed = false
      autofs = Ldap._start_autofs
      autofs_con = Empty()
      if Ldap._autofs_allowed
        autofs_con = VBox(
          VSpacing(0.5),
          # check box label
          Left(CheckBox(Id(:autofs), _("Start Auto&mounter"), autofs))
        )
        help_text = Ops.add(help_text, autofs_help_text)
      end

      mkhomedir = Ldap.mkhomedir
      mkhomedir_term = VBox(
        Left(
          CheckBox(
            Id(:mkhomedir),
            # checkbox label
            _("C&reate Home Directory on Login"),
            mkhomedir
          )
        )
      )
      disable_login_term = VBox(
        Left(
          CheckBox(
            Id(:ldapnologin),
            # checkbox label
            _("Disable User &Logins"),
            !login_enabled
          )
        )
      )

      con = VCenter(
        HBox(
          HSpacing(3),
          VBox(
            VSpacing(0.5),
            # frame label
            Frame(
              _("User Authentication"),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.4),
                  RadioButtonGroup(
                    Id(:rd),
                    Left(
                      HVSquash(
                        VBox(
                          Left(
                            RadioButton(
                              Id(:ldapno),
                              Opt(:notify),
                              # radio button label
                              _("Do &Not Use LDAP"),
                              !start
                            )
                          ),
                          Left(
                            RadioButton(
                              Id(:ldapyes),
                              Opt(:notify),
                              # radio button label
                              _("&Use LDAP"),
                              start
                            )
                          )
                        )
                      )
                    )
                  ),
                  VSpacing(0.4)
                )
              )
            ),
            VSpacing(0.4),
            # frame label
            Frame(
              _("LDAP Client"),
              HBox(
                HSpacing(0.5),
                VBox(
                  VSpacing(0.4),
                  HBox(
                    # text entry label
                    InputField(
                      Id(:server),
                      Opt(:hstretch),
                      _("Addresses of LDAP &Servers"),
                      server
                    ),
                    VBox(
                      Label(""),
                      # push button label
                      PushButton(Id(:slp), _("F&ind"))
                    )
                  ),
                  HBox(
                    InputField(
                      Id(:ldapbasedn),
                      Opt(:hstretch),
                      # text entry label
                      _("LDAP Base &DN"),
                      base_dn
                    ),
                    VBox(
                      Label(""),
                      # push button label
                      PushButton(Id(:fetch), _("F&etch DN"))
                    )
                  ),
                  VSpacing(0.4)
                ),
                HSpacing(0.5)
              )
            ),
            autofs_con,
            mkhomedir_term,
            disable_login_term,
            VSpacing(),
            HBox(
              # pushbutton label
              PushButton(Id(:ssl_config), _("SSL/TLS Configuration...")),
              # pushbutton label
              PushButton(Id(:advanced), _("&Advanced Configuration..."))
            )
          ),
          HSpacing(3)
        )
      )

      Wizard.SetContentsButtons(
        # dialog title
        _("LDAP Client Configuration"),
        con,
        help_text,
        Stage.cont ? Label.BackButton : Label.CancelButton,
        Stage.cont ? Label.NextButton : Label.OKButton
      )

      if Stage.cont
        Wizard.RestoreAbortButton
      else
        Wizard.HideAbortButton
      end


      UI.ChangeWidget(
        Id(:server),
        :ValidChars,
        Ops.add(Address.ValidChars, " ")
      )

      if Ldap.start && !Ldap.sssd
        if Popup.ContinueCancel(
            # question popup
            _(
              "Previous LDAP client configuration was detected.\n" +
                "\n" +
                "Current configuration does not use SSSD but nss_ldap.\n" +
                "Only SSSD based configurations are supported by YaST.\n" +
                "Do you want to continue and use SSSD or cancel to keep the old configuration?"
            )
          )
          Ldap.sssd = true
          ldap_tls = true
        else
          return :cancel
        end
      end

      result = :not_next
      begin
        result = Convert.to_symbol(UI.UserInput)

        rb = UI.QueryWidget(Id(:rd), :CurrentButton)
        start = rb != :ldapno
        login_enabled = UI.QueryWidget(Id(:ldapnologin), :Value) != true

        server = Convert.to_string(UI.QueryWidget(Id(:server), :Value))
        mkhomedir = Convert.to_boolean(UI.QueryWidget(Id(:mkhomedir), :Value))

        if result == :ssl_config
          ssl_changed = SSLConfiguration() || ssl_changed
          ldap_tls = Ldap.ldap_tls # re-read after possible change
        end
        if result == :slp
          srv = ""
          if !Package.Installed("yast-slp")
            if Package.Install("yast2-slp")
              SCR.RegisterAgent(path(".slp"), term(:ag_slp, term(:SlpAgent)))
              srv = BrowseServers()
            end
          else
            srv = BrowseServers()
          end
          UI.ChangeWidget(Id(:server), :Value, srv) if srv != ""
        end
        if result == :fetch
          Ldap.tls_switched_off = false
          if Ldap.ldap_initialized && Ldap.tls_when_initialized != ldap_tls
            Ldap.LDAPClose
          end
          dn = Ldap.ldap_initialized ?
            LdapPopup.BrowseTree("") :
            LdapPopup.InitAndBrowseTree(
              "",
              {
                "hostname"   => Ldap.GetFirstServer(server),
                "port"       => Ldap.GetFirstPort(server),
                "use_tls"    => ldap_tls ? "yes" : "no",
                "cacertdir"  => Ldap.tls_cacertdir,
                "cacertfile" => Ldap.tls_cacertfile
              }
            )
          UI.ChangeWidget(Id(:ldapbasedn), :Value, dn) if dn != ""
          # adapt the checkbox value
          UI.ChangeWidget(Id(:ldaps), :Value, false) if Ldap.tls_switched_off
        end

        if result == :next || result == :advanced
          base_dn = Convert.to_string(UI.QueryWidget(Id(:ldapbasedn), :Value))
          autofs = Ldap._autofs_allowed &&
            Convert.to_boolean(UI.QueryWidget(Id(:autofs), :Value))
        end

        if (result == :next || result == :advanced) && start
          if base_dn == ""
            # error popup label
            Report.Error(_("Enter an LDAP base DN."))
            result = :not_next
            next
          end

          if server == "" || Builtins.deletechars(server, " \t") == ""
            # error popup label
            Report.Error(_("Enter at least one address of an LDAP server."))
            result = :not_next
            next
          end
          if !check_address(server)
            # error popup label
            Report.Error(
              Ops.add(
                _("The LDAP server address is invalid.") + "\n\n",
                Address.Valid4
              )
            )
            UI.SetFocus(Id(:server))
            result = :not_next
            next
          end
        end
        if (result == :abort || result == :cancel || result == :back) &&
            ReallyAbort() != :abort
          result = :not_next
        end
        if result == :next && (start || autofs)
          if start && !Ldap.start && Ldap.nis_available
            # popup question: user enabled LDAP now, but probably has
            # enabled NIS client before
            if !Popup.YesNo(
                _(
                  "When you configure your machine as an LDAP client,\nyou cannot retrieve data with NIS. Really use LDAP instead of NIS?\n"
                )
              )
              result = :not_next
              next
            end
          end

          needed_packages = deep_copy(Ldap.sssd_packages)
          if Ldap.sssd_with_krb
            needed_packages = Convert.convert(
              Builtins.union(needed_packages, Ldap.kerberos_packages),
              :from => "list",
              :to   => "list <string>"
            )
          end

          if start && !Package.InstalledAll(needed_packages)
            Ldap.required_packages = Convert.convert(
              Builtins.union(Ldap.required_packages, needed_packages),
              :from => "list",
              :to   => "list <string>"
            )
          end

          if autofs && !Package.Installed("autofs")
            Ldap.required_packages = Convert.convert(
              Builtins.union(Ldap.required_packages, ["autofs"]),
              :from => "list",
              :to   => "list <string>"
            )
          end
          if !Package.InstallAll(Ldap.required_packages)
            if start && !Package.InstalledAll(needed_packages)
              Popup.Error(Message.FailedToInstallPackages)
              start = false
              result = :not_next
              UI.ChangeWidget(Id(:rd), :CurrentButton, :ldapno) if !installation
              next
            end
          end
          # test the connection in case of TLS
          if start && ldap_tls && Ldap.tls_when_initialized != ldap_tls
            args = {
              "hostname"   => Ldap.GetFirstServer(server),
              "port"       => Ldap.GetFirstPort(server),
              "use_tls"    => ldap_tls ? "yes" : "no",
              "cacertdir"  => Ldap.tls_cacertdir,
              "cacertfile" => Ldap.tls_cacertfile
            }
            if !Mode.config && !Ldap.CheckLDAPConnection(args)
              result = :not_next
              next
            end
          end
        end
      end while !Builtins.contains([:back, :next, :cancel, :abort, :advanced], result)

      if result == :next || result == :advanced
        if Ldap.start != start || Ldap.GetBaseDN != base_dn ||
            Ldap.server != server ||
            Ldap.ldap_tls != ldap_tls ||
            Ldap._start_autofs != autofs ||
            Ldap.login_enabled != login_enabled ||
            Ldap.mkhomedir != mkhomedir || ssl_changed
          if result == :next
            if start && !Ldap.start && !Mode.config
              Autologin.AskForDisabling(
                # popup text
                _("LDAP is now enabled.")
              )

              message = Stage.cont ?
                "" :
                # message popup, part 1/2
                _(
                  "This change only affects newly created processes and not already\n" +
                    "running services. Restart your services manually or reboot \n" +
                    "the machine to enable it for all services.\n"
                )

              if Service.Status("sshd") == 0
                Ldap.RestartSSHD(true)
                # message popup, part 1/2
                message = Ops.add(
                  message,
                  _(
                    "\n" +
                      "To enable remote login for LDAP users, sshd is\n" +
                      "restarted automatically by YaST.\n"
                  )
                )
              end
              Popup.Message(message) if message != ""
            end
            if ldap_tls && tls_checkpeer == "no"
              # yes/no question
              if Popup.YesNo(
                  _(
                    "The security connection is enabled, but server certificate verification is disabled.\nEnable certificate checks now?"
                  )
                )
                Ldap.tls_checkpeer = "yes"
              end
            end
            # check if user changed part of imported settings (#252094)
            if start && Stage.cont &&
                Ops.greater_than(Builtins.size(Ldap.initial_defaults), 0) &&
                Ldap.create_ldap &&
                server !=
                  Ops.get_string(Ldap.initial_defaults, "ldap_server", "") &&
                base_dn !=
                  Ops.get_string(Ldap.initial_defaults, "ldap_domain", "") &&
                Ldap.bind_dn ==
                  Ops.get_string(Ldap.initial_defaults, "bind_dn", "") &&
                !Builtins.issubstring(Ldap.bind_dn, base_dn)
              Builtins.y2warning(
                "Server and base DN changed but bind_dn remains imported -> disabling LDAP objects creation..."
              )
              Ldap.create_ldap = false
            end
          end
          Ldap.SetBaseDN(base_dn)
          Ldap.start = start
          Ldap.server = server
          Ldap.ldap_tls = ldap_tls
          Ldap._start_autofs = autofs
          Ldap.login_enabled = login_enabled
          Ldap.mkhomedir = mkhomedir
          Ldap.modified = true
        end
      end
      result
    end



    # Configuration of advanced settings (how to get to config data on server)
    def AdvancedConfigurationDialog
      help_text = {
        :client    => Ops.add(
          Ops.add(
            # help text caption 1
            _("<p><b>Advanced LDAP Client Settings</b></p>") +
              # help text 1/3
              _(
                "<p>If Kerberos authentication should be used, specify the <b>realm</b> and <b>KDC Address</b>.\n" +
                  "Determine if user credentials should be cached locally by checking <b>SSSD Offline Authentication</b>.\n" +
                  "For more info about SSSD settings, check the man page of <tt>sssd.conf</tt>.</p>\n"
              ) +
              # help text 2/3
              _(
                "<p><b>Password Change Protocol</b> refers to the pam_password attribute of the\n<tt>/etc/ldap.conf</tt> file. See <tt>man pam_ldap</tt> for an explanation of its values.</p>"
              ),
            # help text 3/3, %1 is attribute name
            Builtins.sformat(
              _(
                "<p>Set the type of LDAP groups to use.\nThe default value for <b>Group Member Attribute</b> is <i>%1</i>.</p>\n"
              ),
              "member"
            )
          ),
          _(
            "<p>If secure connection requires certificate checking, specify where your\n" +
              "certificate file is located. Enter either a directory containing certificates\n" +
              "or the explicit path to one certificate file.</p>"
          )
        ),
        :admin =>
          # help text caption 2
          _("<p><b>Access to Server</b></p>") +
            # help text 1/4
            _(
              "<p>First, set <b>Configuration Base DN</b>.\n" +
                "This is the base for storing your configuration data on the LDAP\n" +
                "server.</p>\n"
            ) +
            # help text 2/4
            _(
              "<p>To access the data stored on the server, enter the\n" +
                "<b>Administrator DN</b>.\n" +
                "You can enter the full DN (for example, cn=Administrator,dc=mydomain,dc=com) or \n" +
                "the relative DN (for example, cn=Administrator). The LDAP base DN is appended automatically if the appropriate option is checked.</p>\n"
            ) +
            # help text 3/4
            _(
              "<p>To create the default configuration objects for LDAP users and groups,\ncheck <b>Create Default Configuration Objects</b>. The objects are only created when they do not already exist.</p>\n"
            ) +
            # help text 4/4
            _(
              "<p>Press <b>Configure</b> to configure settings stored on the\n" +
                "LDAP server. You will be asked for the password if you are not connected yet or\n" +
                "have changed your configuration.</p>\n"
            ),
        :searching =>
          # help text 1/1
          _(
            "<p>Specify the search bases to use for specific maps (users or groups) if they are different from the base DN. These values are\nset to the ldap_user_search_base, ldap_group_search_base and ldap_autofs_search_base attributes in /etc/sssd/sssd.conf file.</p>\n"
          )
      }

      bind_dn = Ldap.bind_dn
      base_dn = Ldap.GetBaseDN
      member_attribute = Ldap.member_attribute
      base_config_dn = Ldap.GetMainConfigDN
      create_ldap = Ldap.create_ldap
      append_base = bind_dn != "" && Builtins.issubstring(bind_dn, base_dn)
      pam_password = Ldap.pam_password
      krb5_realm = Ldap.krb5_realm
      krb5_server = Ldap.krb5_server
      sssd_with_krb = Ldap.sssd_with_krb
      sssd_ldap_schema = Ldap.sssd_ldap_schema
      sssd_enumerate = Ldap.sssd_enumerate
      sssd_cache_credentials = Ldap.sssd_cache_credentials
      nss_base_passwd = Ldap.nss_base_passwd
      nss_base_group = Ldap.nss_base_group
      nss_base_automount = Ldap.nss_base_automount

      member_attributes = [
        Item(Id("member"), "member", member_attribute == "member"),
        Item(
          Id("uniqueMember"),
          "uniqueMember",
          member_attribute == "uniqueMember"
        )
      ]
      if member_attribute != "member" && member_attribute != "uniqueMember"
        member_attributes = Builtins.add(
          member_attributes,
          Item(Id(member_attribute), member_attribute, true)
        )
      end

      # propose some good default
      if base_config_dn == ""
        base_config_dn = Builtins.sformat("ou=ldapconfig,%1", base_dn)
      end

      pam_password_items = [
        "ad",
        "crypt",
        "clear",
        "clear_remove_old",
        "exop",
        "exop_send_old",
        "md5",
        "nds",
        "racf"
      ]
      pam_password_items = Builtins.sort(
        Builtins.maplist(
          Convert.convert(
            Builtins.union(pam_password_items, [pam_password]),
            :from => "list",
            :to   => "list <string>"
          )
        ) { |it| Item(Id(it), it, it == pam_password) }
      )
      ldap_schemas = ["rfc2307", "rfc2307bis"]

      # mapping of browse button id's to appropriate text entries
      br2entry = {
        :br        => :base_config_dn,
        :br_passwd => :nss_base_passwd,
        :br_group  => :nss_base_group,
        :br_autofs => :nss_base_automount
      }

      tabs = [
        # tab label
        Item(Id(:client), _("C&lient Settings"), true),
        # tab label
        Item(Id(:admin), _("Ad&ministration Settings")),
        # tab label
        Item(Id(:searching), _("Naming Contexts"))
      ]

      contents = VBox(
        DumbTab(Id(:tabs), tabs, ReplacePoint(Id(:tabContents), VBox(Empty())))
      )
      has_tabs = true
      if !UI.HasSpecialWidget(:DumbTab)
        has_tabs = false
        tabbar = HBox()
        Builtins.foreach(tabs) do |it|
          label = Ops.get_string(it, 1, "")
          tabbar = Builtins.add(tabbar, PushButton(Ops.get_term(it, 0) do
            Id(label)
          end, label))
        end
        contents = VBox(
          Left(tabbar),
          Frame("", ReplacePoint(Id(:tabContents), Empty()))
        )
      end

      set_searching_term = lambda do
        cont = Top(
          HBox(
            HSpacing(4),
            VBox(
              VSpacing(1),
              VSpacing(0.4),
              HBox(
                InputField(
                  Id(:nss_base_passwd),
                  Opt(:hstretch),
                  # textentry label
                  _("&User Map"),
                  nss_base_passwd
                ),
                VBox(
                  Label(""),
                  # button label
                  PushButton(Id(:br_passwd), _("&Browse"))
                )
              ),
              HBox(
                InputField(
                  Id(:nss_base_group),
                  Opt(:hstretch),
                  # textentry label
                  _("&Group Map"),
                  nss_base_group
                ),
                VBox(
                  Label(""),
                  # button label
                  PushButton(Id(:br_group), _("Bro&wse"))
                )
              ),
              HBox(
                InputField(
                  Id(:nss_base_automount),
                  Opt(:hstretch),
                  # textentry label
                  _("&Autofs Map"),
                  nss_base_automount
                ),
                VBox(
                  Label(""),
                  # button label
                  PushButton(Id(:br_autofs), _("Bro&wse"))
                )
              ),
              VSpacing(0.4)
            ),
            HSpacing(4)
          )
        )

        UI.ReplaceWidget(:tabContents, cont)
        UI.ChangeWidget(Id(:tabs), :CurrentItem, :searching) if has_tabs

        nil
      end

      set_client_term = lambda do
        cont = Top(
          HBox(
            HSpacing(4),
            VBox(
              VSpacing(1),
              # checkbox label
              Left(
                CheckBox(
                  Id(:sssd_with_krb),
                  Opt(:notify),
                  _("&Use Kerberos"),
                  sssd_with_krb
                )
              ),
              VSpacing(0.4),
              HBox(
                HSpacing(2),
                # textentry label
                TextEntry(Id(:krb5_realm), _("Default Real&m"), krb5_realm),
                # textentry label
                TextEntry(Id(:krb5_server), _("&KDC Server Address"), krb5_server)
              ),
              VSpacing(),
              # combobox label
              ComboBox(
                Id(:sssd_ldap_schema),
                Opt(:notify, :hstretch),
                _("LDAP Schema"),
                Builtins.maplist(ldap_schemas) do |s|
                  Item(Id(s), s, s == sssd_ldap_schema)
                end
              ),
              VSpacing(0.4),
              HBox(
                HSpacing(0.4),
                # checkbox label
                Left(
                  CheckBox(
                    Id(:sssd_enumerate),
                    _("Enable user and group enumeration"),
                    sssd_enumerate
                  )
                )
              ),
              VSpacing(0.4),
              HBox(
                HSpacing(0.4),
                # check box label
                Left(
                  CheckBox(
                    Id(:sssd_cache_credentials),
                    _("SSSD O&ffline Authentication"),
                    sssd_cache_credentials
                  )
                )
              ),
              VSpacing(),
              ComboBox(
                Id(:pam_password),
                Opt(:notify, :hstretch, :editable),
                # combobox label
                _("Passwor&d Change Protocol"),
                pam_password_items
              ),
              ComboBox(
                Id(:group_style),
                Opt(:notify, :hstretch),
                # combobox label
                _("Group Member &Attribute"),
                member_attributes
              )
            ),
            HSpacing(4)
          )
        )

        UI.ReplaceWidget(:tabContents, cont)
        UI.ChangeWidget(Id(:tabs), :CurrentItem, :client) if has_tabs
        if Ldap.sssd
          UI.ChangeWidget(Id(:krb5_realm), :Enabled, sssd_with_krb)
          UI.ChangeWidget(Id(:krb5_server), :Enabled, sssd_with_krb)
        end

        nil
      end

      set_admin_term = lambda do
        cont = HBox(
          HSpacing(4),
          VBox(
            VSpacing(0.4),
            HBox(
              InputField(
                Id(:base_config_dn),
                Opt(:hstretch),
                # textentry label
                _("Configuration &Base DN"),
                base_config_dn
              ),
              VBox(
                Label(""),
                # button label
                PushButton(Id(:br), Opt(:key_F6), _("Bro&wse"))
              )
            ),
            VSpacing(0.4),
            HBox(
              InputField(
                Id(:bind_dn),
                Opt(:hstretch),
                # textentry label
                _("Administrator &DN"),
                bind_dn
              ),
              VBox(
                Label(""),
                # checkbox label
                CheckBox(Id(:append), _("A&ppend Base DN"), append_base)
              )
            ),
            VSpacing(0.4),
            Left(
              CheckBox(
                Id(:create_ldap),
                # checkbox label
                _("Crea&te Default Configuration Objects"),
                create_ldap
              )
            ),
            VSpacing(0.5),
            Right(
              PushButton(
                Id(:configure),
                # pushbutton label
                _("Configure User Management &Settings...")
              )
            ),
            VStretch()
          ),
          HSpacing(4)
        )

        UI.ReplaceWidget(:tabContents, cont)
        UI.ChangeWidget(Id(:tabs), :CurrentItem, :admin) if has_tabs

        # in autoyast-config mode, don't attach to server...
        UI.ChangeWidget(Id(:configure), :Enabled, false) if Mode.config

        nil
      end


      # dialog label
      Wizard.SetContentsButtons(
        _("Advanced Configuration"),
        contents,
        Ops.get_string(help_text, :client, ""),
        Label.CancelButton,
        Label.OKButton
      )

      Wizard.HideAbortButton

      result = :notnext
      current = :client

      set_client_term.call

      while true
        result = UI.UserInput
        result = :not_next if result == :cancel && ReallyAbort() != :abort

        break if result == :back || result == :cancel

        # 1. get the data from dialogs
        if current == :client
          member_attribute = Convert.to_string(
            UI.QueryWidget(Id(:group_style), :Value)
          )

          krb5_realm = Convert.to_string(
            UI.QueryWidget(Id(:krb5_realm), :Value)
          )
          krb5_server = Convert.to_string(
            UI.QueryWidget(Id(:krb5_server), :Value)
          )
          sssd_cache_credentials = Convert.to_boolean(
            UI.QueryWidget(Id(:sssd_cache_credentials), :Value)
          )
          sssd_enumerate = Convert.to_boolean(
            UI.QueryWidget(Id(:sssd_enumerate), :Value)
          )
          sssd_ldap_schema = Convert.to_string(
            UI.QueryWidget(Id(:sssd_ldap_schema), :Value)
          )
          pam_password = Convert.to_string(
            UI.QueryWidget(Id(:pam_password), :Value)
          )
        end
        if current == :searching
          nss_base_passwd = Convert.to_string(
            UI.QueryWidget(Id(:nss_base_passwd), :Value)
          )
          nss_base_group = Convert.to_string(
            UI.QueryWidget(Id(:nss_base_group), :Value)
          )
          nss_base_automount = Convert.to_string(
            UI.QueryWidget(Id(:nss_base_automount), :Value)
          )
        end
        if current == :admin
          bind_dn = Convert.to_string(UI.QueryWidget(Id(:bind_dn), :Value))
          base_config_dn = Convert.to_string(
            UI.QueryWidget(Id(:base_config_dn), :Value)
          )
          create_ldap = Convert.to_boolean(
            UI.QueryWidget(Id(:create_ldap), :Value)
          )
          append_base = Convert.to_boolean(UI.QueryWidget(Id(:append), :Value))
          if append_base && !Builtins.issubstring(bind_dn, base_dn) &&
              bind_dn != ""
            bind_dn = Builtins.sformat("%1,%2", bind_dn, base_dn)
            UI.ChangeWidget(Id(:bind_dn), :Value, bind_dn)
          end
        end

        # 2. switch the tabs
        if result == :client || result == :admin || result == :searching
          current = Convert.to_symbol(result)
          Wizard.SetHelpText(Ops.get_string(help_text, current, ""))
          if result == :client
            set_client_term.call
          elsif result == :admin
            set_admin_term.call
          elsif result == :searching
            set_searching_term.call
          end
        end

        # 3. other events
        if Ops.is_symbol?(result) &&
            Builtins.haskey(br2entry, Convert.to_symbol(result))
          if Ldap.ldap_initialized && Ldap.tls_when_initialized != Ldap.ldap_tls
            Ldap.LDAPClose
          end
          dn = Ldap.ldap_initialized ?
            LdapPopup.BrowseTree(base_dn) :
            LdapPopup.InitAndBrowseTree(
              base_dn,
              {
                "hostname"   => Ldap.GetFirstServer(Ldap.server),
                "port"       => Ldap.GetFirstPort(Ldap.server),
                "use_tls"    => Ldap.ldap_tls ? "yes" : "no",
                "cacertdir"  => Ldap.tls_cacertdir,
                "cacertfile" => Ldap.tls_cacertfile
              }
            )
          UI.ChangeWidget(Id(Ops.get(br2entry, result)), :Value, dn) if dn != ""
        end
        if result == :sssd_with_krb
          sssd_with_krb = Convert.to_boolean(
            UI.QueryWidget(Id(:sssd_with_krb), :Value)
          )
          UI.ChangeWidget(Id(:krb5_realm), :Enabled, sssd_with_krb)
          UI.ChangeWidget(Id(:krb5_server), :Enabled, sssd_with_krb)
        end

        if result == :next || result == :configure
          if result == :configure && bind_dn == ""
            # error popup label
            Report.Error(_("Enter the DN used for binding to the LDAP server."))
            UI.SetFocus(Id(:bind_dn))
            next
          end

          if result == :configure && base_config_dn == ""
            # error popup label
            Report.Error(_("Enter the configuration base DN."))
            UI.SetFocus(Id(:base_config_dn))
            next
          end
          if krb5_realm == "" || krb5_server == "" || !Ldap.sssd
            sssd_with_krb = false
          end

          if Ldap.GetMainConfigDN != base_config_dn || Ldap.bind_dn != bind_dn ||
              Ldap.member_attribute != member_attribute ||
              Ldap.create_ldap != create_ldap ||
              Ldap.pam_password != pam_password ||
              Ldap.nss_base_passwd != nss_base_passwd ||
              Ldap.nss_base_group != nss_base_group ||
              Ldap.nss_base_automount != nss_base_automount ||
              Ldap.sssd_with_krb != sssd_with_krb ||
              Ldap.krb5_realm != krb5_realm ||
              Ldap.krb5_server != krb5_server ||
              Ldap.sssd_cache_credentials != sssd_cache_credentials ||
              Ldap.sssd_enumerate != sssd_enumerate ||
              Ldap.sssd_ldap_schema != sssd_ldap_schema
            Ldap.bind_dn = bind_dn
            Ldap.base_config_dn = base_config_dn
            Ldap.member_attribute = member_attribute
            Ldap.create_ldap = create_ldap
            Ldap.pam_password = pam_password
            Ldap.nss_base_passwd = nss_base_passwd
            Ldap.nss_base_group = nss_base_group
            Ldap.nss_base_automount = nss_base_automount
            Ldap.krb5_realm = krb5_realm
            Ldap.krb5_server = krb5_server
            Ldap.sssd_with_krb = sssd_with_krb
            Ldap.sssd_cache_credentials = sssd_cache_credentials
            Ldap.sssd_enumerate = sssd_enumerate
            Ldap.sssd_ldap_schema = sssd_ldap_schema
            Ldap.modified = true
          end
          break
        end
      end
      Convert.to_symbol(result)
    end

    # Initialize connection to LDAP server, bind and read the settings.
    # Everything is done before entering the Module Configuration Dialog.
    def LDAPReadDialog
      msg = ""
      read_now = false

      if !Ldap.bound || Modified()
        if !Ldap.bound || Ldap.modified
          # re-init/re-bind only when server information was changed (#39908)
          if !Ldap.bound || Ldap.old_server != Ldap.server || Ldap.BaseDNChanged
            msg = Ldap.LDAPInitWithTLSCheck({})
            if msg != ""
              Ldap.LDAPErrorMessage("init", msg)
              return :back
            end
          end

          if !Ldap.bound || Ldap.old_server != Ldap.server
            # Ldap::bind_pass might exist from server proposal...
            if Stage.cont && Ldap.bind_pass != nil
              msg = Ldap.LDAPBind(Ldap.bind_pass)
              if msg != ""
                Ldap.LDAPErrorMessage("bind", msg)
                Ldap.bind_pass = Ldap.LDAPAskAndBind(true)
              end
            else
              Ldap.bind_pass = Ldap.LDAPAskAndBind(true)
            end
            return :back if Ldap.bind_pass == nil

            read_now = true

            msg = Ldap.InitSchema
            Ldap.LDAPErrorMessage("schema", msg) if msg != ""
          end
        end
        return :back if !Ldap.CheckBaseConfig(Ldap.base_config_dn)
        if read_now || Ldap.modified && !Ldap.ldap_modified ||
            Ldap.ldap_modified &&
              Popup.AnyQuestion(
                Popup.NoHeadline,
                # yes/no popup
                _(
                  "If you reread settings from the server,\nall changes will be lost. Really reread?\n"
                ),
                Label.YesButton,
                Label.NoButton,
                :focus_no
              )
          msg = Ldap.ReadConfigModules
          Ldap.LDAPErrorMessage("read", msg) if msg != ""

          msg = Ldap.ReadTemplates
          Ldap.LDAPErrorMessage("read", msg) if msg != ""

          Ldap.ldap_modified = false
        end
        Ldap.bound = true
      end
      :next
    end

    # Dialog for configuration one object template
    def TemplateConfigurationDialog(templ)
      templ = deep_copy(templ)
      # help text 1/3
      help_text = _(
        "<p>Configure the template used for creating \nnew objects (like users or groups).</p>\n"
      ) +
        # help text 2/3
        _(
          "<p>Edit the template attribute values with <b>Edit</b>.\nChanging the <b>cn</b> value renames the template.</p>\n"
        ) +
        # help text 3/3
        _(
          "<p>The second table contains a list of <b>default values</b> used\n" +
            "for new objects. Modify the list by adding new values, editing or\n" +
            "removing current ones.</p>\n"
        )

      template_dn = Ldap.current_template_dn

      table_items = []
      template = Convert.convert(
        Builtins.eval(templ),
        :from => "map",
        :to   => "map <string, any>"
      )

      # helper function converting list value to string
      to_table = lambda do |attr, val|
        val = deep_copy(val)
        if Ldap.SingleValued(attr) || attr == "cn"
          return Ops.get(val, 0, "")
        elsif Builtins.contains(
            ["susesecondarygroup", "susedefaulttemplate"],
            Builtins.tolower(attr)
          )
          return Builtins.mergestring(val, " ")
        else
          return Builtins.mergestring(val, ",")
        end
      end

      Builtins.foreach(template) do |attr, value|
        val = deep_copy(value)
        # do not show internal attributes
        if Builtins.contains(
            [
              "susedefaultvalue",
              "default_values",
              "objectclass",
              "modified",
              "old_dn"
            ],
            Builtins.tolower(attr)
          )
          next
        end
        if Ops.is_list?(value)
          val = to_table.call(
            attr,
            Convert.convert(val, :from => "any", :to => "list <string>")
          )
        end
        table_items = Builtins.add(table_items, Item(Id(attr), attr, val))
      end

      default_items = []
      default_values = Ops.get_map(template, "default_values", {})
      Builtins.foreach(default_values) do |attr, value|
        default_items = Builtins.add(default_items, Item(Id(attr), attr, value))
      end

      contents = HBox(
        HSpacing(1.5),
        VBox(
          VSpacing(0.5),
          Table(
            Id(:table),
            Opt(:notify),
            Header(
              # table header 1/2
              _("Attribute"),
              # table header 2/2
              _("Value")
            ),
            table_items
          ),
          HBox(PushButton(Id(:edit), Label.EditButton), HStretch()),
          # label (table folows)
          Left(Label(_("Default Values for New Objects"))),
          Table(
            Id(:defaults),
            Opt(:notify),
            Header(
              # table header 1/2
              _("Attribute of Object"),
              # table header 2/2
              _("Default Value")
            ),
            default_items
          ),
          HBox(
            # button label (with non-default shortcut)
            PushButton(Id(:add_dfl), Opt(:key_F3), _("A&dd")),
            # button label
            PushButton(Id(:edit_dfl), Opt(:key_F4), _("&Edit")),
            PushButton(Id(:delete_dfl), Opt(:key_F5), Label.DeleteButton),
            HStretch()
          ),
          VSpacing(0.5)
        ),
        HSpacing(1.5)
      )

      Wizard.OpenNextBackDialog
      # dialog label
      Wizard.SetContentsButtons(
        _("Object Template Configuration"),
        contents,
        help_text,
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      UI.SetFocus(Id(:table)) if Ops.greater_than(Builtins.size(table_items), 0)
      UI.ChangeWidget(Id(:edit_dfl), :Enabled, default_items != [])
      UI.ChangeWidget(Id(:delete_dfl), :Enabled, default_items != [])

      result = nil
      while true
        result = UI.UserInput
        attr = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

        # edit attribute
        if result == :edit || result == :table
          next if attr == nil
          value = Ops.get_list(template, attr, [])
          offer = []
          conflicts = []
          if Builtins.tolower(attr) == "susesecondarygroup"
            offer = Ldap.GetGroupsDN(Ldap.GetBaseDN)
          end
          if Builtins.tolower(attr) == "susenamingattribute"
            classes = Ldap.GetDefaultObjectClasses(template)
            offer = Ldap.GetObjectAttributes(classes)
          end
          if attr == "cn"
            base = Builtins.issubstring(template_dn, ",") ?
              Builtins.substring(
                template_dn,
                Ops.add(Builtins.search(template_dn, ","), 1)
              ) :
              ""
            Builtins.foreach(Ldap.ReadDN(base, "")) do |dn|
              if Builtins.substring(dn, 0, 3) == "cn="
                conflicts = Builtins.add(conflicts, get_cn(dn))
              end
            end
          end
          value = LdapPopup.EditAttribute(
            {
              "attr"      => attr,
              "value"     => value,
              "conflicts" => conflicts,
              "single"    => Ldap.SingleValued(attr) || attr == "cn",
              "offer"     => offer,
              "browse"    => Builtins.tolower(attr) == "susesecondarygroup"
            }
          )

          next if value == Ops.get_list(template, attr, [])
          UI.ChangeWidget(
            Id(:table),
            term(:Item, attr, 1),
            to_table.call(attr, value)
          )
          Ops.set(template, attr, value)
        end
        # add default value
        if result == :add_dfl
          conflicts = Builtins.maplist(default_values) { |attr3, val| attr3 }
          classes = Ldap.GetDefaultObjectClasses(template)
          available = Ldap.GetObjectAttributes(classes)
          # filter out objectclass
          dfl = LdapPopup.AddDefaultValue(
            Builtins.sort(available),
            Builtins.add(conflicts, "objectClass")
          )
          next if Ops.get_string(dfl, "value", "") == ""
          attr2 = Ops.get_string(dfl, "attr", "")
          Ops.set(default_values, attr2, Ops.get_string(dfl, "value", ""))
          default_items = Builtins.add(
            default_items,
            Item(Id(attr2), attr2, Ops.get_string(dfl, "value", ""))
          )
          UI.ChangeWidget(Id(:defaults), :Items, default_items)
          UI.ChangeWidget(Id(:edit_dfl), :Enabled, default_items != [])
          UI.ChangeWidget(Id(:delete_dfl), :Enabled, default_items != [])
        end
        # edit default value
        if result == :edit_dfl || result == :defaults
          attr = Convert.to_string(UI.QueryWidget(Id(:defaults), :CurrentItem))
          next if attr == nil
          value = Ops.get(default_values, attr, "")
          l_value = LdapPopup.EditAttribute(
            { "attr" => attr, "value" => [value], "single" => true }
          )
          next if Ops.get_string(l_value, 0, "") == value
          value = Ops.get_string(l_value, 0, "")
          UI.ChangeWidget(Id(:defaults), term(:Item, attr, 1), value)
          Ops.set(default_values, attr, value)
        end
        # delete default value
        if result == :delete_dfl
          attr = Convert.to_string(UI.QueryWidget(Id(:defaults), :CurrentItem))
          next if attr == nil
          # yes/no popup, %1 is name
          if !Popup.YesNo(
              Builtins.sformat(
                _("Really delete default attribute \"%1\"?"),
                attr
              )
            )
            next
          end
          default_values = Builtins.remove(default_values, attr)
          default_items = Builtins.filter(default_items) do |it|
            Ops.get_string(it, 1, "") != attr
          end
          UI.ChangeWidget(Id(:defaults), :Items, default_items)
          UI.ChangeWidget(Id(:edit_dfl), :Enabled, default_items != [])
          UI.ChangeWidget(Id(:delete_dfl), :Enabled, default_items != [])
        end
        if Ops.is_symbol?(result) &&
            Builtins.contains(
              [:back, :cancel, :abort],
              Convert.to_symbol(result)
            )
          break
        end
        if result == :next
          cont = false

          # check the template required attributes...
          Builtins.foreach(Ops.get_list(template, "objectClass", [])) do |oc|
            next if cont
            Builtins.foreach(Ldap.GetRequiredAttributes(oc)) do |attr2|
              val = Ops.get(template, attr2)
              if !cont && val == nil || val == [] || val == ""
                #error popup, %1 is attribute name
                Popup.Error(
                  Builtins.sformat(
                    _("The \"%1\" attribute is mandatory.\nEnter a value."),
                    attr2
                  )
                )
                UI.SetFocus(Id(:table))
                cont = true
              end
            end
          end
          next if cont
          Ops.set(template, "default_values", default_values)
          break
        end
      end
      Wizard.CloseDialog
      deep_copy(template)
    end

    # Dialog for configuration of one "configuration module"
    def ModuleConfigurationDialog
      # helptext 1/4
      help_text = _(
        "<p>Manage the configuration stored in the LDAP directory.</p>"
      ) +
        # helptext 2/4
        _(
          "<p>Each configuration set is called a \"configuration module.\" If there\n" +
            "is no configuration module in the provided location (base configuration),\n" +
            "create one with <b>New</b>. Delete the current module\n" +
            "using <b>Delete</b>.</p>\n"
        ) +
        # helptext 3/4
        _(
          "<p>Edit the values of attributes in the table with <b>Edit</b>.\n" +
            "Some values have special meanings, for example, changing the <b>cn</b> value renames the\n" +
            "current module.</p>\n"
        ) +
        # helptext 4/4
        _(
          "<p>To configure the default template of the current module,\n" +
            "click <b>Configure Template</b>.\n" +
            "</p>\n"
        )

      current_dn = Ldap.current_module_dn
      modules_attrs_items = {} # map of list (table items), index is cn
      modules = Convert.convert(
        Ldap.GetConfigModules,
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      templates = Convert.convert(
        Ldap.GetTemplates,
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
      names = []
      templates_dns = Builtins.maplist(templates) { |dn, t| dn }

      # Helper for creating table items in ModuleConfiguration Dialog
      create_attrs_items = lambda do |cn|
        attrs_items = []
        dn = get_dn(cn)
        dn = Builtins.tolower(dn) if !Builtins.haskey(modules, dn)
        Builtins.foreach(Ops.get(modules, dn, {})) do |attr, value|
          val = deep_copy(value)
          if Builtins.contains(
              ["objectclass", "modified", "old_dn"],
              Builtins.tolower(attr)
            )
            next
          end
          if Ops.is_list?(value)
            lvalue = Convert.to_list(value)
            if Ldap.SingleValued(attr) || attr == "cn"
              val = Ops.get_string(lvalue, 0, "")
            else
              val = Builtins.mergestring(
                Convert.convert(value, :from => "any", :to => "list <string>"),
                ","
              )
            end
          end
          attrs_items = Builtins.add(attrs_items, Item(Id(attr), attr, val))
        end

        deep_copy(attrs_items)
      end

      Builtins.foreach(modules) do |dn, mod|
        cn = get_string(mod, "cn")
        next if cn == ""
        names = Builtins.add(names, cn)
        # attributes for table
        Ops.set(modules_attrs_items, cn, create_attrs_items.call(cn))
        current_dn = dn if current_dn == ""
      end
      current_cn = Ops.get_string(modules, [current_dn, "cn", 0]) do
        get_cn(current_dn)
      end

      # Helper for updating widgets in ModuleConfiguration Dialog
      replace_module_names = lambda do
        modules_items = [] # list of module names
        Builtins.foreach(names) do |cn|
          if Builtins.tolower(cn) == Builtins.tolower(current_cn)
            modules_items = Builtins.add(modules_items, Item(Id(cn), cn, true))
          else
            modules_items = Builtins.add(modules_items, Item(Id(cn), cn))
          end
        end
        UI.ReplaceWidget(
          Id(:rp_modnames),
          Left(
            ComboBox(
              Id(:modules),
              Opt(:notify),
              # combobox label
              _("Configuration &Module"),
              modules_items
            )
          )
        )
        ena = names != []
        UI.ChangeWidget(Id(:delete), :Enabled, ena)
        UI.ChangeWidget(Id(:edit), :Enabled, ena)
        UI.ChangeWidget(Id(:modules), :Enabled, ena)

        nil
      end

      # Helper for updating widgets in ModuleConfiguration Dialog
      replace_templates_items = lambda do
        items = Builtins.maplist(
          Ops.get_list(modules, [current_dn, "suseDefaultTemplate"], [])
        ) { |dn| Item(Id(dn), dn) }
        UI.ReplaceWidget(
          Id(:rp_templs),
          PushButton(
            Id(:templ_pb),
            Opt(:key_F7),
            # button label
            _("C&onfigure Template")
          )
        )
        UI.ChangeWidget(Id(:templ_pb), :Enabled, items != [])

        nil
      end

      contents = HBox(
        HSpacing(1.5),
        VBox(
          VSpacing(0.5),
          HBox(
            ReplacePoint(Id(:rp_modnames), Empty()),
            VBox(Label(""), PushButton(Id(:new), Opt(:key_F3), Label.NewButton)),
            VBox(
              Label(""),
              PushButton(Id(:delete), Opt(:key_F5), Label.DeleteButton)
            )
          ),
          VSpacing(0.5),
          Table(
            Id(:table),
            Opt(:notify),
            Header(
              # table header 1/2
              _("Attribute"),
              # table header 2/2
              _("Value")
            ),
            Ops.get_list(modules_attrs_items, current_cn, [])
          ),
          HBox(
            PushButton(Id(:edit), Opt(:key_F4), Label.EditButton),
            HStretch(),
            ReplacePoint(Id(:rp_templs), Empty())
          ),
          VSpacing(0.5)
        ),
        HSpacing(1.5)
      )

      # dialog label
      Wizard.SetContentsButtons(
        _("Module Configuration"),
        contents,
        help_text,
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      if Ops.greater_than(
          Builtins.size(Ops.get_list(modules_attrs_items, current_cn, [])),
          0
        )
        UI.SetFocus(Id(:table))
      end
      replace_templates_items.call
      replace_module_names.call

      # result could be symbol or string
      result = nil
      while true
        result = UI.UserInput
        attr = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

        # check the correctness of entry
        if Builtins.contains(
            Ops.get_list(modules, [current_dn, "suseDefaultTemplate"], []),
            result
          ) ||
            result == :next ||
            result == :modules ||
            result == :new
          Builtins.foreach(
            Ops.get_list(modules, [current_dn, "objectClass"], [])
          ) { |oc| Builtins.foreach(Ldap.GetRequiredAttributes(oc)) do |attr2|
            val = Ops.get(modules, [current_dn, attr2])
            if val == nil || val == [] || val == ""
              #error popup, %1 is attribute name
              Popup.Error(
                Builtins.sformat(
                  _("The \"%1\" attribute is mandatory.\nEnter a value."),
                  attr2
                )
              )
              UI.SetFocus(Id(:table))
              result = :notnext
              next
            end
          end }
        end
        # change the focus to new module
        if result == :modules
          current_cn = Convert.to_string(UI.QueryWidget(Id(:modules), :Value))
          current_dn = get_dn(current_cn)
          if !Builtins.haskey(modules, current_dn)
            current_dn = Builtins.tolower(current_dn)
          end
          UI.ChangeWidget(
            Id(:table),
            :Items,
            Ops.get_list(modules_attrs_items, current_cn, [])
          )
          replace_templates_items.call
        end
        # delete the module
        if result == :delete
          # yes/no popup, %1 is name
          if !Popup.YesNo(
              Builtins.sformat(_("Really delete module \"%1\"?"), current_cn)
            )
            next
          end
          modules_attrs_items = Builtins.remove(modules_attrs_items, current_cn)
          if Ops.get_string(modules, [current_dn, "modified"], "") != "added"
            Ops.set(modules, [current_dn, "modified"], "deleted")
          end
          names = Builtins.filter(names) { |n| n != current_cn }
          current_cn = Ops.get(names, 0, "")
          current_dn = get_dn(current_cn)
          if !Builtins.haskey(modules, current_dn)
            current_dn = Builtins.tolower(current_dn)
          end
          replace_module_names.call
          replace_templates_items.call
          UI.ChangeWidget(
            Id(:table),
            :Items,
            Ops.get_list(modules_attrs_items, current_cn, [])
          )
        end
        # new module
        if result == :new
          available = deep_copy(Ldap.available_config_modules)
          Builtins.foreach(modules) do |dn, mod|
            next if Ops.get_string(mod, "modified", "") == "deleted"
            Builtins.foreach(Ops.get_list(mod, "objectClass", [])) do |cl|
              available = Builtins.filter(available) do |c|
                Builtins.tolower(c) != Builtins.tolower(cl)
              end
            end
          end
          if available == []
            # message
            Popup.Message(
              _(
                "You currently have a configuration module of each \ntype, therefore you cannot add a new one.\n"
              )
            )
            next
          end
          # get new name and class
          new = LdapPopup.NewModule(available, names)
          cn = Ops.get_string(new, "cn", "")
          next if cn == ""
          current_cn = cn
          current_dn = get_dn(current_cn)
          if !Builtins.haskey(modules, current_dn)
            current_dn = Builtins.tolower(current_dn)
          end
          Ops.set(
            modules,
            current_dn,
            Ldap.CreateModule(cn, Ops.get_string(new, "class", ""))
          )
          names = Builtins.add(names, cn)
          Ops.set(modules_attrs_items, cn, create_attrs_items.call(cn))
          replace_module_names.call
          replace_templates_items.call
          UI.ChangeWidget(
            Id(:table),
            :Items,
            Ops.get_list(modules_attrs_items, current_cn, [])
          )
        end
        # module attribute modification
        if result == :edit || result == :table
          next if attr == nil
          value = Ops.get_list(modules, [current_dn, attr], [])
          offer = []
          conflicts = []
          conflicts = deep_copy(names) if attr == "cn"
          if Builtins.tolower(attr) == "susedefaulttemplate"
            offer = deep_copy(templates_dns)
          elsif Builtins.tolower(attr) == "susepasswordhash"
            offer = deep_copy(Ldap.hash_schemas)
          end

          value = LdapPopup.EditAttribute(
            {
              "attr"      => attr,
              "value"     => value,
              "conflicts" => conflicts,
              "single"    => Ldap.SingleValued(attr) || attr == "cn",
              "offer"     => offer,
              "browse" =>
                # TODO function, that checks if value should be DN
                Builtins.tolower(attr) == "susedefaultbase" ||
                  Builtins.tolower(attr) == "susedefaulttemplate"
            }
          )

          if value == Ops.get_list(modules, [current_dn, attr], []) #nothing was changed
            next
          end
          Ops.set(modules, [current_dn, attr], value)
          Ops.set(
            modules_attrs_items,
            current_cn,
            create_attrs_items.call(current_cn)
          )
          UI.ChangeWidget(
            Id(:table),
            :Items,
            Ops.get_list(modules_attrs_items, current_cn, [])
          )
          UI.ChangeWidget(Id(:table), :CurrentItem, attr)
          if attr == "cn" && value != []
            cn = Ops.get(value, 0, current_cn)
            Ops.set(
              modules_attrs_items,
              cn,
              Ops.get_list(modules_attrs_items, current_cn, [])
            )
            modules_attrs_items = Builtins.remove(
              modules_attrs_items,
              current_cn
            )
            if Ops.get_string(modules, [current_dn, "modified"], "") != "added" &&
                Ops.get_string(modules, [current_dn, "modified"], "") != "renamed"
              Ops.set(modules, [current_dn, "modified"], "renamed")
              Ops.set(modules, [current_dn, "old_dn"], current_dn)
            end
            Ops.set(modules, get_dn(cn), Ops.get(modules, current_dn, {}))
            if Builtins.tolower(get_dn(cn)) != Builtins.tolower(current_dn)
              modules = Builtins.remove(modules, current_dn)
            end
            names = Builtins.filter(names) { |n| n != current_cn }
            names = Builtins.add(names, cn)
            current_cn = cn
            current_dn = get_dn(cn)
            replace_module_names.call
          end
          if Builtins.tolower(attr) == "susedefaulttemplate"
            replace_templates_items.call
          end
        end
        # configure template
        if result == :templ_pb
          template_dn = Ops.get_string(
            modules,
            [current_dn, "suseDefaultTemplate", 0],
            ""
          )
          Ldap.current_template_dn = template_dn
          template = Builtins.eval(Ops.get(templates, template_dn, {}))
          # template not loaded, check DN:
          if template == {}
            template = Ldap.CheckTemplateDN(template_dn)
            if template == nil
              next
            elsif template == {}
              next if !Ldap.ParentExists(template_dn)
              template = Ldap.CreateTemplate(
                get_cn(template_dn),
                Ops.get_list(modules, [current_dn, "objectClass"], [])
              )
            end
            templates_dns = Builtins.add(templates_dns, template_dn)
          end
          Ops.set(templates, template_dn, TemplateConfigurationDialog(template))
          # check for template renaming
          if Ops.get_list(templates, [template_dn, "cn"], []) !=
              Ops.get_list(template, "cn", [])
            cn = get_string(Ops.get(templates, template_dn, {}), "cn")
            new_dn = get_new_dn(cn, template_dn)

            Ops.set(templates, new_dn, Ops.get(templates, template_dn, {}))
            if new_dn != template_dn
              templates = Builtins.remove(templates, template_dn)
            end
            if Ops.get_string(templates, [new_dn, "modified"], "") != "added"
              Ops.set(templates, [new_dn, "modified"], "renamed")
              Ops.set(templates, [new_dn, "old_dn"], template_dn)
            end
            templates_dns = Builtins.filter(templates_dns) do |dn|
              dn != template_dn
            end
            templates_dns = Builtins.add(templates_dns, new_dn)
            # update list of templates
            Ops.set(
              modules,
              [current_dn, "suseDefaultTemplate"],
              Builtins.maplist(
                Ops.get_list(modules, [current_dn, "suseDefaultTemplate"], [])
              ) do |dn|
                next new_dn if dn == template_dn
                dn
              end
            )
            Ops.set(
              modules_attrs_items,
              current_cn,
              create_attrs_items.call(current_cn)
            )
            UI.ChangeWidget(
              Id(:table),
              :Items,
              Ops.get_list(modules_attrs_items, current_cn, [])
            )
            replace_templates_items.call
          end
          UI.SetFocus(Id(:table))
        end
        if result == :next
          Ldap.current_module_dn = current_dn
          # save the edited values to global map...
          Ldap.CommitConfigModules(modules)
          # commit templates here!
          Ldap.CommitTemplates(templates)
          break
        end
        result = :not_next if result == :cancel && ReallyAbort() != :abort
        break if result == :back || result == :cancel
      end

      Convert.to_symbol(result)
    end
  end
end
