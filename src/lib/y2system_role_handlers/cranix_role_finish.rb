# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2020 Dipl. Ing. Peter Varkoly, Nuernberg, Germany.
require "yast"
module Y2SystemRoleHandlers
  class CranixRoleFinish < Client
    def run
	lang = Yast::Language.language || "de_DE"
        lang = Yast::Language.GetLocaleString(lang)
        SCR.Write(path(".sysconfig.language.RC_LANG"),  lang)
        SCR.Write(path(".sysconfig.language.RC_LC_ALL"),  lang)
        SCR.Write(path(".sysconfig.language.ROOT_USES_LANG"),  "yes")
        SCR.Write(path(".sysconfig.language"), nil)
        SCR.Execute(path(".target.bash"), "touch /var/lib/YaST2/reconfig_system")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_CONTROL_FILE"),  "/etc/YaST2/cranix-firstboot.xml")
        SCR.Write(path(".sysconfig.firstboot.LICENSE_REFUSAL_ACTION"),  "continue")
        SCR.Write(path(".sysconfig.firstboot.FIRSTBOOT_FINISH_ACTION"), "reboot")
        SCR.Write(path(".sysconfig.firstboot"), nil)
        true
    end
  end
end

