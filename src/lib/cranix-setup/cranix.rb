      #Load sssd configurations
      _sections = SCR.Dir(path(".etc.sssd_conf.section"))
      _sections.each { |s|
         _values = SCR.Read(path( ".etc.sssd_conf.all.\"#{s}\"" ) )
         _values["value"].each { |v|
            next if v["kind"] == "comment"
            @auth["sssd_conf"][s][v["name"]] = v["value"]
         }
      }

