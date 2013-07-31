# encoding: utf-8

#  ConvertDefaultValues.ycp
#  Summary:	Test of Ldap::ConvertDefaultValues
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class ConvertDefaultValuesClient < Client
    def main
      # testedfiles: Ldap.ycp
      Yast.import "Testsuite"

      @READ = { "target" => { "tmpdir" => "/tmp", "stat" => {} } }
      Testsuite.Init([@READ], 0)

      Yast.import "Ldap"

      @template = {
        "suseDefaultValue" => [
          "homeDirectory=/home/%uid",
          "loginShell=/bin/bash",
          "testvalue=first=second",
          "novalue"
        ]
      }
      Testsuite.Test(lambda { Ldap.ConvertDefaultValues(@template) }, [@READ], 0)

      nil
    end
  end
end

Yast::ConvertDefaultValuesClient.new.main
