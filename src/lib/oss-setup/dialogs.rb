# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'yast'
require 'ui/dialog'

Yast.import 'UI'
Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Popup'


module OSS
    class Dialogs
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            #textdomain 'OSS'
	    true
        end

        def ReadBackupDialog
          backup = Popup.YesNoHeadline(
            _("Do you want to read the configuration of another OSS?"),
            _("You can save the /etc/sysconfig/schoolserver file from another OSS without path on an USB-stick.\n") +
            _("If you have created a backup from an OSS this backup also contains this file.\n") +
            _("If the backup is on an external HD, you can connect this HD to allow the OSS to read the configuration.\n")
          )
          return :next if !backup
          while true
            if !Popup.ContinueCancel(_("Please insert the USB-stick with the configuration file!"))
              break
            end
            if FindSysconfigFile()
              backup = true
              break
            end
            if !Popup.YesNoHeadline(
                _("No configuration file was found."),
                _("Do you want to try it again?")
              )
              break
            end
          end
          backup 
        end

	#Some internal use only functions
	:privat
        def FindSysconfigFile
          mountpoint = "/tmp/ossmount"
          SCR.Execute( path(".target.bash"), Builtins.sformat("mkdir -p %1", mountpoint) )
          probe = Convert.convert(
            SCR.Read(path(".probe.usb")),
            :from => "any",
            :to   => "list <map>"
          )
          ok = false
          Builtins.foreach(probe) do |d|
            if Ops.get_string(d, "bus", "USB") == "SCSI" &&
                Builtins.haskey(d, "dev_name")
              i = 0
              dev = Ops.get_string(d, "dev_name", "")
              Builtins.y2milestone("dev %1", dev)
              while SCR.Read(path(".target.lstat"), dev) != {}
                if !Convert.to_boolean( SCR.Execute( path(".target.mount"), [dev, mountpoint], "-o shortname=mixed" ) )
                  WFM.Execute(path(".local.mount"), [dev, mountpoint])
                end
                Builtins.y2milestone("trying to find 'schoolserver' on %1", dev)
                if SCR.Read(
                    path(".target.lstat"),
                    Ops.add(mountpoint, "/schoolserver")
                  ) != {}
                  Builtins.y2milestone("found")
                  ok = true
                  SCR.Execute( path(".target.bash"), Ops.add( Ops.add("mkdir -p /var/adm/oss/; cp ", mountpoint), "/schoolserver /var/adm/oss/old-schoolserver" ) )
                  break
                else
                  WFM.Execute(path(".local.umount"), mountpoint)
                end
                Builtins.y2milestone("not found")
                i = Ops.add(i, 1)
                dev = Ops.add(
                  Ops.get_string(d, "dev_name", ""),
                  Builtins.sformat("%1", i)
                )
                Builtins.y2milestone( "mountpoint: %1 %2", dev, SCR.Read(path(".target.lstat"), dev) )
              end
            end
          end
          ok
        end
    end

    DialogsInst = Dialogs.new
end
