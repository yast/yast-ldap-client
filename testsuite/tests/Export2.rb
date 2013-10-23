# encoding: utf-8

#  Read.ycp
#  Test of Ldap:Read function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class Export2Client < Client
    def main
      # testedfiles: Ldap.ycp
      Yast.import "Testsuite"

      @READ = {
        "etc"       => {
          "nsswitch_conf" => {
            "passwd"        => "sss",
            "group"         => "sss",
            "passwd_compat" => nil,
            "group_compat"  => nil
          },
          "ldap_conf"     => {
            "v" => {
              "/etc/ldap.conf" => {
                "host"            => "localhost",
                "base"            => "dc=suse,dc=cz",
                "nss_base_passwd" => nil,
                "nss_base_shadow" => nil,
                "nss_base_group"  => "ou=group,dc=suse,dc=cz",
                "nss_base_automount"  => nil,
                "ldap_version"    => nil,
                "ssl"             => nil,
                "pam_password"    => "crypt",
                "tls_cacertdir"   => "/etc/openldap/cacerts/",
                "tls_cacertfile"  => nil,
                "tls_checkpeer"   => nil,
                "uri"             => nil
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
          },
          "sssd_conf"     => {
            "v" => {
              "domain/default" => {
                "krb5_realm"             => "SUSE.CZ",
                "krb5_kdcip"             => "kdc.suse.cz",
                "ldap_schema"            => "rfc2307",
                "cache_credentials"      => "true",
                "enumerate"              => "true",
                "ldap_id_use_start_tls"  => nil,
                # will lead to ldap_tls true
                "ldap_user_search_base"  => "ou=users,dc=suse,dc=cz",
                "ldap_group_search_base" => nil,
                "ldap_autofs_search_base" => nil
              }
            }
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
        "target"    => { "size" => -1, "stat" => { 1 => 2 } }
      }

      @EX = {
        "target" => {
          "bash"        => 0,
          "bash_output" => {
            # for Pam::Enabled ("mkhomedir") call
            "stdout" => "something:"
          }
        },
        "passwd" => { "init" => true }
      }
      Testsuite.Init([@READ, {}, {}], nil)

      Yast.import "Ldap"

      Testsuite.Test(lambda { Ldap.Read }, [@READ, {}, @EX], 0)

      Testsuite.Test(lambda { Ldap.Export }, [@READ, {}, @EX], 0)

      nil
    end
  end
end

Yast::Export2Client.new.main
