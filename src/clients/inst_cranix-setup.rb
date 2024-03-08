# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2024 Dipl. Ing. Peter Varkoly, Nuernberg, Germany.
module Yast
  class InstCranixSetup < Client
    def main
        SCR.Execute(path(".target.bash"), "touch /var/lib/YaST2/reconfig_system")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_CONTROL_FILE"),  "/etc/YaST2/cranix-firstboot.xml")
        SCR.Write(path(".sysconfig.firstboot.LICENSE_REFUSAL_ACTION"),  "continue")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_FINISH_ACTION"), "reboot")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_FINISH_FILE"), "/usr/share/cranix/setup/cranix-wellcome.rtf")
        SCR.Write(path(".sysconfig.firstboot"), nil)
        :next
    end
  end
end

Yast::InstCranixSetup.new.main

