# encoding: utf-8

#  Read.ycp
#  Test of Ldap:Read function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class ReadClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ = {
        "etc"       => {
          "nsswitch_conf" => {
            "passwd"        => "compat",
            "group"         => "compat",
            "passwd_compat" => "ldap",
            "group_compat"  => "ldap"
          },
          "ldap_conf"     => {
            "v" => {
              "/etc/ldap.conf" => {
                "host"            => "localhost",
                "base"            => "dc=suse,dc=cz",
                "nss_base_passwd" => nil,
                "nss_base_shadow" => nil,
                "nss_base_group"  => nil,
                "nss_base_automount"  => nil,
                "ldap_version"    => nil,
                "ssl"             => nil,
                "pam_password"    => "crypt",
                "tls_cacertdir"   => "/etc/openldap/cacerts/",
                "tls_cacertfile"  => nil,
                "tls_checkpeer"   => "no",
                "uri"             => "ldap://localhost:333"
              }
            }
          },
          "krb5_conf"     => {
            "v" => {
              "libdefaults" => { "default_realm" => ["SUSE.CZ"] },
              "SUSE.CZ"     => { "kdc" => ["kdc.suse.cz"] }
            }
          },
          # /etc/security/pam_*
          "security"      => {
            "section" => { "/etc/security/pam_unix2.conf" => {} },
            "v"       => { "/etc/security/pam_unix2.conf" => { "auth" => "" } }
          }
        },
        "sysconfig" => {
          "ldap" => {
            "BASE_CONFIG_DN" => nil,
            "BIND_DN"        => "uid=manager,dc=suse,dc=cz",
            "FILE_SERVER"    => "no"
          }
        },
        "init"      => { "scripts" => { "exists" => false } },
        "passwd"    => {
          "passwd" => { "plusline" => "+", "pluslines" => ["+"] }
        },
        "product"   => { "features" => { "EVMS_CONFIG" => "nazdar" } },
        "target"    => { "size" => -1, "stat" => {} }
      }

      @EX = {
        "target" => { "bash" => 0, "bash_output" => { "stdout" => "" } },
        "passwd" => { "init" => true }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Ldap"

      DUMP("==== reading... ============================")

      TEST(lambda { Ldap.Read }, [@READ, {}, @EX], 0)

      DUMP("============================================")

      DUMP(Builtins.sformat("ldap used: -%1-", Ldap.start))

      DUMP(Builtins.sformat("nsswitch: -%1-", Ldap.nsswitch))

      DUMP(Builtins.sformat("base config DN: -%1-", Ldap.base_config_dn))

      DUMP(Builtins.sformat("bind DN: -%1-", Ldap.bind_dn))

      DUMP(Builtins.sformat("server: -%1-", Ldap.server))

      nil
    end
  end
end

Yast::ReadClient.new.main
