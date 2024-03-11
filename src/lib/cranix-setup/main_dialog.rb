# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2021 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'cranix-setup/dialogs'

module Yast
    SERVICES_TO_STOP = [
      'cron',
      'cranix-api',
      'samba-ad',
      'samba-fileserver',
      'samba-printserver',
      'smbd',
      'unbound'
    ]
    class MainDialog < Client
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            Yast.import 'Icon'
            Yast.import 'Label'
            Yast.import 'Lan'
            Yast.import 'Popup'
            Yast.import 'Package'
            Yast.import 'Service'
            Yast.import 'UI'
            Yast.import 'Wizard'
            textdomain 'cranix'
            Builtins.y2milestone("initialize CRANIX started")
            @readBackup = false
            Wizard.OpenNextBackStepsDialog()
            SCR.Read(path(".sysconfig.network.config"))
            SCR.Write(path(".sysconfig.network.config.LINK_REQUIRED"),"no")
            SCR.Write(path(".sysconfig.network.config"),nil)
            Lan.Read(:nocache)
            SERVICES_TO_STOP.each do |service|
              system("/usr/bin/systemctl stop #{service}")
            end
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
                when :network
                        ret = DialogsInst.CardDialog()
                when :write
                     SCR.Execute(path(".target.bash"), "/usr/share/cranix/tools/register.sh")
		     if SCR.Read(path(".etc.cranix.CRANIX_INTERNET_FILTER")) == "squid"
                        Package.DoInstall(["cranix-proxy"])
		     else
                        Package.DoInstall(["cranix-unbound"])
		     end
                     ret = DialogsInst.CranixSetup()
                     Package.DoInstall(["cranix-clone","cranix-web"])
                     break
                when :abort, :cancel
                     break
                end
            end
            SCR.Execute(path(".target.bash"), "rm -rf /var/lib/YaST2/reconfig_system")
            return :next
        end
    end
end

