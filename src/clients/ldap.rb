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
# Summary:	Client file, including commandline handlers
# Authors:	Thorsten Kukuk <kukuk@suse.de>
#		Anas Nashif <nashif@suse.de>
#
# $Id$

#**
# <h3>Configuration of the ldap</h3>
module Yast
  class LdapClient < Client
    def main
      Yast.import "UI"

      textdomain "ldap-client"

      Yast.import "CommandLine"
      Yast.import "Ldap"
      Yast.import "RichText"
      Yast.import "Service"

      Yast.include self, "ldap/wizards.rb"

      @ret = :auto


      # the command line description map
      @cmdline = {
        "id"         => "ldap",
        # translators: command line help text for Ldap client module
        "help"       => _(
          "LDAP client configuration module"
        ),
        "guihandler" => fun_ref(method(:LdapSequence), "symbol ()"),
        "initialize" => fun_ref(Ldap.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Ldap.method(:WriteNow), "boolean ()"),
        "actions"    => {
          "pam"       => {
            "handler" => fun_ref(
              method(:LdapEnableHandler),
              "boolean (map <string, string>)"
            ),
            # translators: command line help text for pam action
            "help"    => _(
              "Enable or disable authentication with LDAP"
            )
          },
          "summary"   => {
            "handler" => fun_ref(method(:LdapSummaryHandler), "boolean (map)"),
            # translators: command line help text for summary action
            "help"    => _(
              "Configuration summary of the LDAP client"
            )
          },
          "configure" => {
            "handler" => fun_ref(
              method(:LdapChangeConfiguration),
              "boolean (map <string, string>)"
            ),
            # translators: command line help text for configure action
            "help"    => _(
              "Change the global settings of the LDAP client"
            )
          }
        },
        "options"    => {
          "enable"            => {
            # translators: command line help text for pam enable option
            "help" => _(
              "Enable the service"
            )
          },
          "disable"           => {
            # translators: command line help text for pam disable option
            "help" => _(
              "Disable the service"
            )
          },
          "server"            => {
            # translators: command line help text for the server option
            "help" => _(
              "The LDAP server name"
            ),
            "type" => "string"
          },
          "base"              => {
            # translators: command line help text for the base option
            "help" => _(
              "Distinguished name (DN) of the search base"
            ),
            "type" => "string"
          },
          "createconfig"      => {
            # command line help text for the 'createconfig' option
            "help" => _(
              "Create default configuration objects."
            )
          },
          "ldappw"            => {
            # command line help text for the 'ldappw' option
            "help" => _(
              "LDAP Server Password"
            ),
            "type" => "string"
          },
          "automounter"       => {
            # help text for the 'automounter' option
            "help"     => _(
              "Start or stop automounter"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "mkhomedir"         => {
            # help text for the 'mkhomedir' option
            "help"     => _(
              "Create Home Directory on Login"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "tls"               => {
            # help text for the 'tls' option
            "help"     => _(
              "Encrypted connection (StartTLS)"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "sssd"              => {
            # help text for the 'sssd' option
            "help"     => _(
              "Use System Security Services Daemon (SSSD)"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "cache_credentials" => {
            # help text for the 'cache_credentials' option
            "help"     => _(
              "SSSD Offline Authentication"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "realm"             => {
            # command line help text for the 'realm' option
            "help" => _(
              "Kerberos Realm"
            ),
            "type" => "string"
          },
          "kdc"               => {
            # command line help text for the 'kdc' option
            "help" => _(
              "KDC Server Address"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "pam"       => [
            "enable",
            "disable",
            "server",
            "base",
            "createconfig",
            "ldappw",
            "automounter",
            "mkhomedir",
            "tls",
            "sssd",
            "realm",
            "kdc",
            "cache_credentials"
          ],
          "summary"   => [],
          "configure" => [
            "server",
            "base",
            "createconfig",
            "ldappw",
            "automounter",
            "mkhomedir",
            "tls",
            "sssd",
            "realm",
            "kdc",
            "cache_credentials"
          ]
        }
      }

      @ret = CommandLine.Run(@cmdline)
      deep_copy(@ret)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Print summary of basic options
    # @return [Boolean] false
    def LdapSummaryHandler(options)
      options = deep_copy(options)
      CommandLine.Print(RichText.Rich2Plain(Ops.add("<br>", Ldap.ShortSummary)))
      false # do not call Write...
    end

    # Change basic configuration of LDAP client (server, base DN)
    # @param [Hash{String => String}] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def LdapChangeConfiguration(options)
      options = deep_copy(options)
      server = Ops.get(options, "server", "")
      if server != ""
        Ldap.server = server
        Ldap.modified = true
      end
      base = Ops.get(options, "base", "")
      if base != ""
        Ldap.SetDomain(base)
        Ldap.modified = true
      end

      ldappw = Ops.get(options, "ldappw", "")
      if ldappw != ""
        Ldap.bind_pass = ldappw
        Ldap.modified = true
      end
      if Ops.get(options, "automounter", "") == "yes" && !Ldap._start_autofs
        Ldap._start_autofs = true
        Ldap.modified = true
      end
      if Ops.get(options, "automounter", "") == "no" && Ldap._start_autofs
        Ldap._start_autofs = false
        Ldap.modified = true
      end
      if Ops.get(options, "mkhomedir", "") != ""
        mkhomedir = Ops.get(options, "mkhomedir", "") == "yes"
        if Ldap.mkhomedir != mkhomedir
          Ldap.mkhomedir = mkhomedir
          Ldap.modified = true
        end
      end
      if Ops.get(options, "tls", "") != ""
        tls = Ops.get(options, "tls", "") == "yes"
        if Ldap.ldap_tls != tls
          Ldap.ldap_tls = tls
          Ldap.modified = true
        end
      end

      if Ops.get(options, "sssd", "") != ""
        sssd = Ops.get(options, "sssd", "") == "yes"
        if Ldap.sssd != sssd
          Ldap.sssd = sssd
          Ldap.modified = true
        end
      end

      if Ops.get(options, "cache_credentials", "") != ""
        cache_credentials = Ops.get(options, "cache_credentials", "") == "yes"
        if Ldap.sssd_cache_credentials != cache_credentials
          Ldap.sssd_cache_credentials = cache_credentials
          Ldap.modified = true
        end
      end

      if Ops.get(options, "realm", "") != ""
        realm = Ops.get(options, "realm", "")
        if Ldap.krb5_realm != realm
          Ldap.krb5_realm = realm
          Ldap.modified = true
        end
      end
      if Ops.get(options, "kdc", "") != ""
        kdc = Ops.get(options, "kdc", "")
        if Ldap.krb5_server != kdc
          Ldap.krb5_server = kdc
          Ldap.modified = true
        end
      end

      if Ldap.krb5_server != "" && Ldap.krb5_realm != ""
        Ldap.sssd_with_krb = true
      end

      if Builtins.haskey(options, "createconfig")
        if Ldap.bind_pass == nil
          # password entering label
          Ldap.bind_pass = CommandLine.PasswordInput(_("LDAP Server Password:"))
        end
        Ldap.create_ldap = true
        Ldap.modified = true
      end

      Ldap.modified
    end

    # Enable or disable LDAP authentication
    # @param [Hash{String => String}] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def LdapEnableHandler(options)
      options = deep_copy(options)
      # check the "command" to be present exactly once
      command = CommandLine.UniqueOption(options, ["enable", "disable"])
      return false if command == nil

      Ldap.RestartSSHD(
        command == "enable" && !Ldap.start && Service.Status("sshd") == 0
      )

      if Ldap.start && command == "disable" ||
          !Ldap.start && command == "enable"
        Ldap.modified = true
      end

      Ldap.start = command == "enable"

      LdapChangeConfiguration(options)
    end
  end
end

Yast::LdapClient.new.main
