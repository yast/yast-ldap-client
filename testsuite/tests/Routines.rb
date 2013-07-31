# encoding: utf-8

#  File:	Routines.ycp
#  Summary:	Test of routines.ycp functions
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class RoutinesClient < Client
    def main
      # testedfiles: Ldap.ycp
      Yast.import "Testsuite"

      @READ = { "target" => { "tmpdir" => "/tmp", "stat" => {} } }
      Testsuite.Init([@READ], 0)

      Yast.import "Ldap"

      Yast.include self, "ldap/routines.rb"

      @dn = "uid=root,dc=suse,dc=cz"

      Testsuite.Test(lambda { Ldap.get_rdn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_cn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_new_dn("admin", @dn) }, [], 0)

      @dn = "uid=root"

      Testsuite.Test(lambda { Ldap.get_rdn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_cn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_new_dn("admin", @dn) }, [], 0)

      @dn = "root"

      Testsuite.Test(lambda { Ldap.get_rdn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_cn(@dn) }, [], 0)
      Testsuite.Test(lambda { Ldap.get_new_dn("admin", @dn) }, [], 0)

      nil
    end
  end
end

Yast::RoutinesClient.new.main
