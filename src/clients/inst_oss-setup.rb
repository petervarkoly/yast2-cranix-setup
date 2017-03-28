module Yast
  class InstOssSetup < Client
    def main
        SCR.Execute(path(".target.bash"), "touch /var/lib/YaST2/reconfig_system")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_CONTROL_FILE"), "/etc/YaST2/oss-firstboot.xml")
        SCR.Write(path(".sysconfig.firstboot.LICENSE_REFUSAL_ACTION"), "continue")
        SCR.Write(path(".sysconfig.firstboot"), nil)
        :next
    end
  end
end

Yast::InstOssSetup.new.main

