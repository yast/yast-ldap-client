# encoding: utf-8

#  LDAPInit.ycp
#  Test of Ldap:LDAPInit, LDAPError, GetFirstServer, GetFirstPort functions
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class LDAPInitClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ = {
        "target" => { "size" => -1 },
        "ldap"   => {
          "error"   => { "msg" => "Initialization failed", "code" => 11 },
          "product" => { "features" => { "EVMS_CONFIG" => "nazdar" } }
        }
      }
      @EX = { "ldap" => true }
      @EX_F = { "ldap" => false }

      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Ldap"

      DUMP("==== init (one server, no port set) ==============")

      Ldap.server = "localhost"

      DUMP(Builtins.sformat("==== value of server: \"%1\"", Ldap.server))

      TEST(lambda { Ldap.LDAPInit }, [{}, {}, @EX], 0)

      DUMP("==== init (one server, nonsence port set) ========")

      Ldap.server = "localhost:sdgfd\#$"

      DUMP(Builtins.sformat("==== value of server: \"%1\"", Ldap.server))

      TEST(lambda { Ldap.LDAPInit }, [{}, {}, @EX], 0)

      DUMP("==== init (more servers set, TLS used) ===========")

      Ldap.server = "chimera.suse.cz:333 localhost"
      Ldap.ldap_tls = true
      Ldap.tls_cacertdir = "/etc/ssl/certs"

      DUMP(Builtins.sformat("==== value of server: \"%1\"", Ldap.server))

      TEST(lambda { Ldap.LDAPInit }, [{}, {}, @EX], 0)

      DUMP("==== init failed =================================")

      TEST(lambda { Ldap.LDAPInit }, [@READ, {}, @EX_F], 0)

      nil
    end
  end
end

Yast::LDAPInitClient.new.main
