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
            textdomain 'OSS'
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
                     SCR.Write(path(".etc.schoolserver"),nil)
                     to_install = []
                     if SCR.Read(path(".etc.schoolserver.SCHOOL_TYPE")) == "cephalix"
                        to_install << "cephalix-java"
                        to_install << "cephalix-web"
                        to_install << "cephalix-base"
                     else
                        if Package.PackageAvailable("oss-web")
                           to_install << "oss-web"
                           to_install << "oss-java"
                        else
                           to_install << "ubs-web"
                           to_install << "ubs-java"
                        end
                     end
                     Package.DoInstall(to_install)
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

