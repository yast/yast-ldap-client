# encoding: utf-8

#  LDAPBind.ycp
#  Test of Ldap:LDAPBind function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class LDAPBindClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ = {
        "target" => { "size" => -1 },
        "ldap"   => {
          "error"   => { "msg" => "Bind failed" },
          "product" => { "features" => { "EVMS_CONFIG" => "nazdar" } }
        }
      }
      @EX = { "ldap" => true }
      @EX_F = { "ldap" => false }

      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Ldap"

      DUMP("==== bind anonymously ==============================")

      Ldap.anonymous = true

      TEST(lambda { Ldap.LDAPBind("pw") }, [{}, {}, @EX], 0)

      Ldap.anonymous = false
      Ldap.bind_dn = "uid=manager,dc=suse,dc=cz"

      DUMP("==== bind failed ====================================")

      TEST(lambda { Ldap.LDAPBind("p") }, [@READ, {}, @EX_F], 0)

      DUMP("==== bind ok ========================================")

      TEST(lambda { Ldap.LDAPBind("pw") }, [{}, {}, @EX], 0)

      nil
    end
  end
end

Yast::LDAPBindClient.new.main
