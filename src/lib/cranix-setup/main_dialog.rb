# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'yast'
require 'ui/dialog'
require 'cranix-setup/dialogs'

Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Lan'
Yast.import 'Popup'
Yast.import 'Package'
Yast.import 'Service'
Yast.import 'UI'
Yast.import 'Wizard'

module CRANIX
    class MainDialog
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            textdomain 'cranix'
            Builtins.y2milestone("initialize CRANIX started")
            @readBackup = false
            Wizard.OpenNextBackStepsDialog()
	    SCR.Read(path(".sysconfig.network.config"))
	    SCR.Write(path(".sysconfig.network.config.LINK_REQUIRED"),"no")
	    SCR.Write(path(".sysconfig.network.config"),nil)
            Lan.Read(:nocache)
            Builtins.y2milestone("initialize CRANIX finished")
        end

        def run
            ret = :start
            SCR.Read(path(".etc.cranix"))
            loop do
                case ret
                when :start
                     if DialogsInst.ReadBackupDialog()
                         @readBackup = true 
                         SCR.Read(path(".etc.cranix"))
                         ret = :network
                     else
                        if ! File.exist?("/etc/sysconfig/cranix")
                          if File.exist?("/var/adm/fillup-templates/sysconfig.cranix")
                             SCR.Execute(path(".target.bash"), "cp /var/adm/fillup-templates/sysconfig.cranix /etc/sysconfig/cranix")
                          else
                             SCR.Execute(path(".target.bash"), "cp /usr/share/fillup-templates/sysconfig.cranix /etc/sysconfig/cranix")
                          end
                        end
                        SCR.Read(path(".etc.cranix"))
                        ret = :basic
                     end
                when :basic
                     ret = DialogsInst.BasicSetting()
                when :expert
                     ret = DialogsInst.ExpertSetting()
                when :network
                     ret = DialogsInst.CardDialog()
                when :write
                     SCR.Execute(path(".target.bash"), "/usr/share/cranix/tools/register.sh")
                     ret = DialogsInst.CranixSetup()
                     Package.DoInstall(["cranix-clone","cranix-proxy","cranix-web"])
		     Package.DoRemove(["firewalld","yast2-firewall","firewalld-lang"])
                     Service.Enable("xinetd")
                     Service.Enable("vsftpd")
                     Service.Enable("squid")
                     Service.Enable("cranix-api")
                     Service.Enable("sshd")
                     break
                when :abort, :cancel
                     break
                end
            end
	    SCR.Execute(path(".target.bash"), "rm -rf /var/lib/YaST2/reconfig_system")
            return :next
        end
        
        def event_loop
        end
    end
end

