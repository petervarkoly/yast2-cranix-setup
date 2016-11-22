# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'yast'
require 'ui/dialog'
require 'oss-setup/dialogs'

Yast.import 'UI'
Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Popup'
Yast.import 'Lan'
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
                         if !File.exist?("/etc/sysconfig/schoolserver")
                            `cp /usr/share/oss/templates/schoolserver /etc/sysconfig/schoolserver`
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
		     SCR.Write(path(".etc.schoolserver"),nil)
                when :abort, :cancel
		     break
                end
            end
        end
        
        def event_loop
        end
    end
end

