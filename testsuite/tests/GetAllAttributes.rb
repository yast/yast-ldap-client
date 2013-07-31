# encoding: utf-8

#  GetAllAttributes.ycp
#  Test of Ldap::GetAllAttributes.ycp function
#  Author:	Jiri Suchomel <jsuchome@suse.cz>
#  $Id$
module Yast
  class GetAllAttributesClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: Ldap.ycp

      @READ1 = {
        "target" => { "size" => -1 },
        "ldap"   => {
          "schema"  => {
            "oc" => {
              "desc" => "User object template",
              "may"  => ["secondarygroup"],
              "must" => ["cn"],
              "oid"  => "1.3.6.1.4.1.7057.10.1.5",
              "sup"  => ["objecttemplate"]
            }
          },
          "product" => { "features" => { "EVMS_CONFIG" => "nazdar" } }
        }
      }

      TESTSUITE_INIT([@READ1, {}, {}], nil)
      Yast.import "Ldap"

      Ldap.object_classes =
        # "userConfiguration": $[
        #     "all": ["minPasswordLength", "maxPasswordLength", "passwordHash",
        # 	    "skelDir", "defaultBase", "nextUniqueId", "minUniqueId",
        # 	    "maxUniqueId", "defaultTemplate", "searchFilter", "cn",
        # 	    "objectClass"],
        #     "desc":"Configuration of user management tools",
        #     "may": ["minPasswordLength", "maxPasswordLength", "passwordHash",
        # 	    "skelDir"],
        #     "must":[],
        #     "oid":"1.3.6.1.4.1.7057.10.1.3",
        #     "sup":["moduleConfiguration"]
        # ],
        # "userTemplate": $[
        #     "all": ["secondaryGroup", "cn", "defaultObjectClass",
        # 	    "requiredAttribute", "allowedAttribute", "defaultValue",
        # 	    "namingAttribute", "objectClass"],
        #     "desc":"User object template",
        #     "may": ["secondaryGroup"],
        #     "must":["cn"],
        #     "oid":"1.3.6.1.4.1.7057.10.1.5",
        #     "sup":["objectTemplate"]
        # ]
        {
          "objecttemplate" => {
            "all"  => [
              "defaultobjectclass",
              "requiredattribute",
              "allowedattribute",
              "defaultvalue",
              "namingattribute",
              "cn",
              "objectclass"
            ],
            "desc" => "Base Class for Object-Templates",
            "may"  => [
              "defaultobjectclass",
              "requiredattribute",
              "allowedattribute",
              "defaultvalue",
              "namingattribute"
            ],
            "must" => ["cn"],
            "oid"  => "1.3.6.1.4.1.7057.10.1.4",
            "sup"  => ["top"]
          },
          "top"            => {
            "all"  => ["objectclass"],
            "desc" => "top of the superclass chain",
            "may"  => [],
            "must" => ["objectclass"],
            "oid"  => "2.5.6.0",
            "sup"  => []
          }
        }

      DUMP("==================================================")
      DUMP(
        Builtins.sformat(
          "===== current object_classes (keys):\n %1",
          Builtins.maplist(
            Convert.convert(
              Ldap.object_classes,
              :from => "map",
              :to   => "map <string, map <string, any>>"
            )
          ) { |k, v| k }
        )
      )
      DUMP("==================================================")
      DUMP("===== looking for 'userTemplate'==================")
      DUMP("===== (superior classes already in cache) ========")
      DUMP("==================================================")


      TEST(lambda { Ldap.GetAllAttributes("usertemplate") }, [@READ1, {}, {}], 0)

      DUMP("==================================================")
      DUMP(
        Builtins.sformat(
          "===== updated object_classes (keys):\n %1",
          Builtins.maplist(
            Convert.convert(
              Ldap.object_classes,
              :from => "map",
              :to   => "map <string, map <string, any>>"
            )
          ) { |k, v| k }
        )
      )

      DUMP("==================================================")
      DUMP("===== looking for non-existent class =============")
      DUMP("==================================================")

      @READ2 = {
        "target" => { "size" => -1 },
        "ldap"   => { "schema" => { "oc" => nil } }
      }

      TEST(lambda { Ldap.GetAllAttributes("usertemplat") }, [@READ2, {}, {}], 0)

      DUMP("==================================================")
      DUMP(
        Builtins.sformat(
          "===== updated object_classes (keys):\n %1",
          Builtins.maplist(
            Convert.convert(
              Ldap.object_classes,
              :from => "map",
              :to   => "map <string, map <string, any>>"
            )
          ) { |k, v| k }
        )
      )

      nil
    end
  end
end

Yast::GetAllAttributesClient.new.main
