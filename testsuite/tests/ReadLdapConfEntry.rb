# encoding: utf-8

#  ReadLdapConfEntry.ycp
#  Test of Ldap::ReadLdapConfEntry function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class ReadLdapConfEntryClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ = {
        "etc"     => {
          "ldap_conf" => {
            "v" => {
              "/etc/ldap.conf" => {
                "host"            => nil,
                "base"            => "dc=suse,dc=cz",
                "nss_base_passwd" => nil
              }
            }
          }
        },
        "product" => { "features" => { "EVMS_CONFIG" => "nazdar" } },
        "target"  => { "size" => -1 }
      }

      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Ldap"

      TEST(lambda { Ldap.ReadLdapConfEntry("host", "localhost") }, [
        @READ,
        {},
        {}
      ], 0)

      TEST(lambda { Ldap.ReadLdapConfEntry("base", "dc=test") }, [@READ, {}, {}], 0)

      TEST(lambda { Ldap.ReadLdapConfEntry("nss_base_passwd", "") }, [
        @READ,
        {},
        {}
      ], 0)

      nil
    end
  end
end

Yast::ReadLdapConfEntryClient.new.main
