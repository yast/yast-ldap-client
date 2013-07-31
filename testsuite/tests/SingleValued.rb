# encoding: utf-8

#  SingleValued.ycp
#  Test of Ldap::SingleValued function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class SingleValuedClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ = {
        "target"  => { "size" => -1 },
        "product" => { "features" => { "EVMS_CONFIG" => "nazdar" } }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Ldap"

      DUMP("==================================================")
      DUMP("===== single attribute ===========================")
      @READ1 = {
        "ldap" => {
          "schema" => { "at" => { "desc" => "uid desc", "single" => true } }
        }
      }

      TEST(lambda { Ldap.SingleValued("uid") }, [@READ1, {}, {}], 0)

      DUMP("==================================================")
      DUMP("===== non-existent attribute =====================")

      @READ2 = { "ldap" => { "schema" => { "at" => nil } } }

      TEST(lambda { Ldap.SingleValued("skeldi") }, [@READ2, {}, {}], 0)

      DUMP("==================================================")
      DUMP("===== non-single attribute =======================")

      @READ3 = {
        "ldap" => { "schema" => { "at" => { "desc" => "skelDir desc" } } }
      }
      TEST(lambda { Ldap.SingleValued("skeldir") }, [@READ3, {}, {}], 0)

      DUMP("==================================================")
      DUMP("===== skelDir once again (already in cache) ======")

      TEST(lambda { Ldap.SingleValued("skeldir") }, [@READ3, {}, {}], 0)

      DUMP("==================================================")
      DUMP("===== cn (not single) ============================")

      @READ4 = {
        "ldap" => {
          "schema" => {
            "at" => {
              "desc"   => "cn attribute description",
              "oid"    => "1.2.3.4.5",
              "single" => false
            }
          }
        }
      }

      TEST(lambda { Ldap.SingleValued("cn") }, [@READ4, {}, {}], 0)

      DUMP("==================================================")
      DUMP("===== description of new attribute ===============")

      @READ5 = {
        "ldap" => {
          "schema" => {
            "at" => {
              "desc"   => "The DN of a template that should be used by default",
              "single" => false
            }
          }
        }
      }

      TEST(lambda { Ldap.AttributeDescription("defaulttemplate") }, [
        @READ5,
        {},
        {}
      ], 0)
      DUMP("==================================================")
      DUMP("===== description of used attribute (in cache) ===")

      TEST(lambda { Ldap.AttributeDescription("cn") }, [@READ5, {}, {}], 0)

      nil
    end
  end
end

Yast::SingleValuedClient.new.main
