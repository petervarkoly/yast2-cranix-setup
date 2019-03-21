# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'yast'
require 'ui/dialog'
require 'oss-setup/dialogs'

Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Lan'
Yast.import 'Popup'
Yast.import 'Package'
Yast.import 'Service'
Yast.import 'UI'
Yast.import 'Wizard'

module OSS
    class MainDialog
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            textdomain 'oss'
            Builtins.y2milestone("initialize OSS started")
            @readBackup = false
            Wizard.OpenNextBackStepsDialog()
            Lan.Read(:nocache)
            Builtins.y2milestone("initialize OSS finished")
        end

        def run
            ret = :start
            SCR.Read(path(".etc.schoolserver"))
            loop do
                case ret
                when :start
                     if DialogsInst.ReadBackupDialog()
                         @readBackup = true 
                         SCR.Read(path(".etc.schoolserver"))
                         ret = :network
                     else
			if ! File.exist?("/etc/sysconfig/scoolserver")
			  if File.exist?("/var/adm/fillup-templates/sysconfig.schoolserver")
			     SCR.Execute(path(".target.bash"), "cp /var/adm/fillup-templates/sysconfig.schoolserver /etc/sysconfig/scoolserver")
			  else
			     SCR.Execute(path(".target.bash"), "cp /usr/share/fillup-templates/sysconfig.schoolserver /etc/sysconfig/scoolserver")
			  end
			end
                        SCR.Read(path(".etc.schoolserver"))
                        ret = :basic
                     end
                when :basic
                     ret = DialogsInst.BasicSetting()
                when :expert
                     ret = DialogsInst.ExpertSetting()
                when :network
                     ret = DialogsInst.CardDialog()
                when :write
		     SCR.Execute(path(".target.bash"), "/usr/share/oss/tools/register.sh")
                     to_install = []
                     to_install << "oss-web"
                     to_install << "oss-lang"
                     if SCR.Read(path(".etc.schoolserver.SCHOOL_TYPE")) == "cephalix"
                        to_install << "cephalix-java"
                        to_install << "cephalix-base"
                     else
                        to_install << "oss-java"
                     end
                     Builtins.y2milestone("Base packages to install %1", to_install )
                     Package.DoInstall(to_install)
                     Builtins.y2milestone("Base packages was installed.")
                     ret = DialogsInst.OssSetup()
                     Package.DoInstall(["oss-clone","oss-proxy"])
                     Service.Enable("xinetd")
                     Service.Enable("vsftpd")
                     Service.Enable("squid")
                     Service.Enable("oss-api")
                     Service.Enable("sshd")
                     break
                when :abort, :cancel
                     break
                end
            end
            return :next
        end
        
        def event_loop
        end
    end
end

