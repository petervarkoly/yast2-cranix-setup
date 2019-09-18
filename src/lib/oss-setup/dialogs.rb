# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# Author: Peter Varkoly <peter@varkoly.de>

require 'yast'
require 'ui/dialog'
#require "y2firewall/firewalld"
#require "y2firewall/helpers/interfaces"
#require "y2firewall/firewalld/interface"
require "open3"


Yast.import 'UI'
Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Popup'
Yast.import 'Netmask'
Yast.import 'IP'
Yast.import "OSRelease"

module OSS
    class Dialogs
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            textdomain 'oss'
            true
        end

        def ReadBackupDialog
          Builtins.y2milestone("-- OSS-Setup ReadBackupDialog Called --")
          backup = Popup.YesNoHeadline(
            _("Do you want to read the configuration of another OSS?"),
            _("You can save the /etc/sysconfig/schoolserver file from another OSS without path on an USB media.\n") +
            _("If you have created a backup from an OSS this backup also contains this file.\n") +
            _("If the backup is on an external HD, you can connect this HD to allow the OSS to read the configuration.\n")
          )
          return false if !backup
          while true
            if !Popup.ContinueCancel(_("Please insert the USB media with the configuration file!"))
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

        #Card Dialog
        def CardDialog()
            Builtins.y2milestone("-- OSS-Setup CardDialog Called --")
            cards = read_net_cards("")
            # Dialog help
            help = _("Select the Network Card for the OSS and enter the IP-Address of the Default Gateway.") +
                   _("If yo can not identify the cards push or remove network cabel from a device.") + 
                   _("After them you can push 'Reload Network Cards' and you can see the changes if the device is connected.")
            is_gate = SCR.Read(path(".etc.schoolserver.SCHOOL_ISGATE")) == "yes" ? true : false
            if is_gate
               help = _("Select the Network Cards for OSS.")
                      _("If yo can not identify the cards push or remove network cabel from a device.") + 
                      _("After them you can push 'Reload Network Cards' and you can see the changes if the device is connected.")
            end
            
            # Dialog contents
            contents = HBox(
              HSpacing(8),
              VBox(
                VSpacing(3),
                ReplacePoint( Id(:rep_net1),SelectionBox(Id(:intdev), _("A&vailable Network Cards:"), cards) ),
                VSpacing(3),
                Left(InputField(Id(:def_gw), Opt(:hstretch), _("Default Gateway"), "")),
                VSpacing(3)
              ),
              HSpacing(8)
            )

            if is_gate
                contents = HBox(
                  HSpacing(8),
                  VBox(
                    VSpacing(3),
                    ReplacePoint( Id(:rep_net1),SelectionBox(Id(:intdev), _("Select the I&nternal Network Card:"), cards) ),
                    VSpacing(3),
                    ReplacePoint( Id(:rep_net2),SelectionBox(Id(:extdev), _("Select the E&xternal Network Card:"), cards) ),
                    VSpacing(3),
                    HBox(
                        Left(InputField(Id(:ext_ip), Opt(:hstretch), _("External IP"), "")),
                        Left(IntField(Id(:ext_nm),   Opt(:hstretch), _("External Netmask"), 8,24,24)),
                        Left(InputField(Id(:def_gw), Opt(:hstretch), _("Default Gateway"), "")),
                    ),
                    VSpacing(3)
                  ),
                  HSpacing(8)
                )
            end
            
            # Dialog
            Wizard.SetContentsButtons(
              _("Network Card Selection"),
              contents,
              help,
              _("Reload Network Cards"),
              Label.NextButton
            )
            if is_gate
               UI.SetFocus(Id(:ext_ip))
            else
               UI.SetFocus(Id(:def_gw))
            end
            
            ret = nil
            while true
              ret = UI.UserInput
              Builtins.y2debug("ret=%1", ret)
              case ret
              when :abort, :cancel
                if Popup.ReallyAbort(true)
                  return :abort
                else
                  next
                end
              when :back
                 cards = read_net_cards("")
                 if is_gate
                    UI.ReplaceWidget(Id(:rep_net1),SelectionBox(Id(:intdev), _("Select the I&nternal Network Card:"), cards ))
                    UI.ReplaceWidget(Id(:rep_net2),SelectionBox(Id(:extdev), _("Select the E&xternal Network Card:"), cards ))
                 else
                    UI.ReplaceWidget(Id(:rep_net1),SelectionBox(Id(:intdev), _("A&vailable Network Cards:"), cards ))
                 end
              when :next
                     ip = SCR.Read(path(".etc.schoolserver.SCHOOL_SERVER")) 
                   mail = SCR.Read(path(".etc.schoolserver.SCHOOL_MAILSERVER")) 
                   prox = SCR.Read(path(".etc.schoolserver.SCHOOL_PROXY")) 
                   prin = SCR.Read(path(".etc.schoolserver.SCHOOL_PRINTSERVER")) 
                 backup = SCR.Read(path(".etc.schoolserver.SCHOOL_BACKUP_SERVER")) 
                     nm = SCR.Read(path(".etc.schoolserver.SCHOOL_NETMASK")) 
                 intdev = Yast::UI.QueryWidget(Id(:intdev), :CurrentItem)
                 def_gw = Yast::UI.QueryWidget(Id(:def_gw), :Value)
                 extdev = nil

                 if !IP.Check4(def_gw)
                    Popup.Error(_("The gateway IP address is incorrect"))
                    UI.SetFocus(Id(:def_gw))
                    next
                 end
                 if is_gate
                    extdev = Yast::UI.QueryWidget(Id(:extdev), :CurrentItem)
                    if intdev == extdev
                       Popup.Error(_("The external and internal devices must not be the same."))
                       UI.SetFocus(Id(:extdev))
                       next
                    end
                    ext_ip = Yast::UI.QueryWidget(Id(:ext_ip), :Value)
                    ext_nm = Convert.to_integer(Yast::UI.QueryWidget(Id(:ext_nm), :Value))
                    str_nm = Netmask.FromBits(ext_nm)
                    if !IP.Check4(ext_ip)
                       Popup.Error(_("The external IP address is incorrect"))
                       UI.SetFocus(Id(:ext_ip))
                       next
                    end
                    if !IsInNetwork(ext_ip,str_nm,def_gw)
                       Popup.Error(_("The external IP address and the gateway are not in the same network."))
                       UI.SetFocus(Id(:ext_ip))
                       next
                    end
                    if IsInNetwork(ip,Netmask.FromBits(nm.to_i),def_gw)
                       Popup.Error(_("The IP address for the gateway must not be in the internal network."))
                       UI.SetFocus(Id(:def_gw))
                       next
                    end
                    SCR.Write(path(".etc.schoolserver.SCHOOL_NET_GATEWAY"),   ip )
                    SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_EXT_IP"), ext_ip )
                    SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_EXT_GW"), def_gw )
                    SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_EXT_NETMASK"), ext_nm )
                 else
                    if !IsInNetwork(ip,Netmask.FromBits(nm.to_i),def_gw)
                       Popup.Error(_("The IP address for the gateway is not in the internal network."))
                       UI.SetFocus(Id(:def_gw))
                       next
                    end
                    SCR.Write(path(".etc.schoolserver.SCHOOL_NET_GATEWAY"), def_gw )
                 end #end if is_gate
                 SCR.Write(path(".etc.schoolserver"),nil)
                 #Now let's start configuring network
                 Routing.Forward_v4 = false
                 Routing.Forward_v6 = false
                 Routing.Routes = [
                   {
                     "destination" => "default",
                     "gateway"     => def_gw,
                     "netmask"     => "-",
                     "device"      => "-"
                   }
                 ]
                 #Configure internal interface
                 if NetworkInterfaces.Check(intdev)
                     NetworkInterfaces.Edit(intdev)
                 else
                     NetworkInterfaces.Add
                     NetworkInterfaces.Name = intdev
                 end
                 NetworkInterfaces.Current = {
                     "BOOTPROTO" => "static",
                     "NAME"      => intdev,
                     "STARTMODE" => "onboot",
                     "IPADDR"    => ip,
                     "NETMASK"   => Netmask.FromBits(Builtins.tointeger(nm)),
                     "_aliases"  => {
                         "mail"  => {
                             "IPADDR"  => mail,
                             "NETMASK" => Netmask.FromBits(Builtins.tointeger(nm)),
                             "LABEL"   => "mail"
                         },
                         "print" => {
                             "IPADDR"  => prin,
                             "NETMASK" => Netmask.FromBits(Builtins.tointeger(nm)),
                             "LABEL"   => "prin"
                         },
                             "proxy" => {
                             "IPADDR"  => prox,
                             "NETMASK" => Netmask.FromBits(Builtins.tointeger(nm)),
                             "LABEL"   => "prox"
                         }
                     }
                 }
                 NetworkInterfaces.Commit
                 # We write the internal device every time as internal device.
                 if is_gate
                     SCR.Write(path(".sysconfig.SuSEfirewall2.FW_ROUTE"), "yes")
                     SCR.Write(path(".sysconfig.SuSEfirewall2.FW_DEV_EXT"), extdev)
                 end
                 SCR.Write(path(".sysconfig.SuSEfirewall2.FW_DEV_INT"), intdev)
                 SCR.Write(path(".sysconfig.SuSEfirewall2", nil)
                 SCR.Write(path(".etc.dhcpd.DHCPD_INTERFACE"), intdev)
                 SCR.Write(path(".etc.dhcpd"), nil)
                 domain = SCR.Read(path(".etc.schoolserver.SCHOOL_DOMAIN"))
                 dns_tmp = DNS.Export
                 serverName = SCR.Read(path(".etc.schoolserver.SCHOOL_NETBIOSNAME")) 
                 Ops.set(dns_tmp, "hostname",    serverName )
                 Ops.set(dns_tmp, "domain",      domain )
                 Ops.set(dns_tmp, "nameservers", [ "127.0.0.1" ] )
                 Ops.set(dns_tmp, "searchlist",  [domain] )
                 DNS.Import(dns_tmp)
                 DNS.modified = true

# It is buggy
#                host_tmp = Host.Export
#                if is_gate
#                  Ops.set(host_tmp, "hosts", {
#                                       ip     => [ serverName + "." + domain + " " + serverName],
#                                       mail   => ["mailserver."  + domain + " mailserver" ],
#                                       prin   => ["printserver." + domain + " printserver" ],
#                                       prox   => ["proxy."       + domain + " proxy" ],
#                                       backup => ["backup."      + domain + " backup" ],
#                                       ext_ip => ["extip"],
#                                        216.239.32.20  => [ "www.google.de","www.google.com","www.google.fr","www.google.it","www.google.hu","www.google.en" ]
#                                  })
#                else
#                  Ops.set(host_tmp, "hosts", {
#                                       ip     => [ serverName + "." + domain + " " + serverName],
#                                       mail   => ["mailserver."  + domain + " mailserver" ],
#                                       prin   => ["printserver." + domain + " printserver" ],
#                                       prox   => ["proxy."       + domain + " proxy" ],
#                                       backup => ["backup."      + domain + " backup" ],
#                                        216.239.32.20  => [ "www.google.de","www.google.com","www.google.fr","www.google.it","www.google.hu","www.google.en" ]
#                                  })
#                Host.Import(host_tmp)
#                 fw_int_dev = Y2Firewall::Firewalld::Interface.new(intdev)
#                 fw_int_dev.zone="trusted"
                 if is_gate
                    #Configure external interface
#                   fw_ext_dev = Y2Firewall::Firewalld::Interface.new(extdev)
#                   fw_ext_dev.zone="external"
                    if NetworkInterfaces.Check(extdev)
                      NetworkInterfaces.Edit(extdev)
                    else
                      Lan.Add
                      NetworkInterfaces.Add
                      NetworkInterfaces.Name = extdev
                    end
                    NetworkInterfaces.Current = {
                      "BOOTPROTO" => "static",
                      "NAME"      => extdev,
                      "STARTMODE" => "onboot",
                      "IPADDR"    => ext_ip,
                      "NETMASK"   => Netmask.FromBits(Builtins.tointeger(ext_nm))
                    }
                    NetworkInterfaces.Commit
                 end #end if is_gate
                 LanItems.SetModified
                 Lan.Write
#
#
host_tmp = "#
# hosts         This file describes a number of hostname-to-address
#               mappings for the TCP/IP subsystem.  It is mostly
#               used at boot time, when no name servers are running.
#               On small systems, this file can be used instead of a
#               \"named\" name server.
# Syntax:
#
# IP-Address  Full-Qualified-Hostname  Short-Hostname
#

127.0.0.1       localhost
"+ ip     + "   "+ serverName + "." + domain + " " + serverName + " 
"+ mail   + "   mailserver."  + domain + " mailserver
"+ prin   + "   printserver." + domain + " printserver
"+ prox   + "   proxy."       + domain + " proxy
"+ backup + "   backup."      + domain + " backup
216.239.32.20  www.google.de www.google.com www.google.fr www.google.it www.google.hu www.google.en
185.3.232.240  repo.cephalix.eu
"
                 if is_gate
                        host_tmp = host_tmp + ext_ip + " extip
"
                 end
                 File.write("/etc/hosts",host_tmp)
                 ret = :write
                 break
              end #end when :next
            end
            
            return ret
        end

        #Basic Settings Dialog
        def BasicSetting
            Builtins.y2milestone("-- OSS-Setup BasicSetting Called --")
            # Dialog help
            help    = _("Some help for basic settings.")
            caption = _("OSS Configuration.")
            instTypes = {
                "work"           => _("work"),
                "global"         => _("Global School"),
                "primary"        => _("Primary School"),
                "gymnasium"      => _("Gymnasium"),
                "secondary"      => _("Secondary School"),
                "real"           => _("real"),
                "special"        => _("Special School"),
                "other"          => _("Other School Type"),
                "administration" => _("Administration"),
                "business"       => _("Company")
            }

            #if OSRelease.ReleaseName == 'CEPHALIX'
            if Package.Installed("patterns-oss-cephalix")
                instTypes =  { "cephalix" => _("CEPHALIX") }
            end

            itemlist = []
            Builtins.foreach(instTypes) do |k, v|
              itemlist = Builtins.add(itemlist, Item(Id(k), v))
            end

            # Dialog contents
            contents = VBox(
                Frame( _("Basic Setting"),
                   HBox(
                     HSpacing(8),
                     VBox(
                        VSpacing(1),
                        Left(InputField(Id(:schoolname), Opt(:hstretch), _("Name of the &Institute"), "NAME")),
                        VSpacing(1),
                        Left(ComboBox(Id(:type),         Opt(:hstretch), _("Selection of the Type of the Institute"), itemlist)),
                        VSpacing(1)
                     ),
                     HSpacing(8),
                     VBox(
                        VSpacing(1),
                        Left(InputField(Id(:regcode),    Opt(:hstretch), _("&Registration Code"),"NOT YET REGISTERED ")),
                        VSpacing(1),
                        Left(InputField(Id(:domain),     Opt(:hstretch), _("&Domain name for the OSS."),"DNSDOMAIN")),
                        VSpacing(1)
                     ),
                     HSpacing(8)
                   )
                ),
                Frame( _("Network Setting"),
                  VBox(
                    VSpacing(1),
                    Left(HBox(
                       HSpacing(8),
                       HWeight( 1, ComboBox(Id(:net0),Opt(:notify),"Internal Network",["172","10","192"])),
                       ReplacePoint( Id(:rep_net1),HWeight( 1,ComboBox(Id(:net1)," ",lnet1("172",16)))),
                       ReplacePoint( Id(:rep_nm),  HWeight( 1,ComboBox(Id(:netm),Opt(:notify),_("Netmask"),lnetmask("172")))),
                       HStretch(10)
                    )),
                    VSpacing(1),
                    HBox(
                       HSpacing(8),
                       Left(CheckBox(Id(:expert_settings),Opt(:notify),  _("Expert Settings"), false)),HStretch()
                    ),
                    Left(HBox(
                       HSpacing(8),
                       HWeight( 1, InputField(Id(:expert_admin),   _("Server IP"),"")),HSpacing(1),
                       HWeight( 1, InputField(Id(:expert_portal),  _("Portal IP"),"")),HSpacing(1),
                       HWeight( 1, InputField(Id(:expert_proxy),   _("Proxy IP"),"")),HSpacing(1),
                       HWeight( 1, InputField(Id(:expert_print),   _("Printserver IP"),"")),HSpacing(1),
                    )),
                    Left(HBox(
                       HSpacing(8),
                       HWeight( 1, InputField(Id(:expert_network), _("Internal Network"),"")),HSpacing(1),
                       HWeight( 1, ComboBox(Id(:expert_netmask),   _("Netmask"),lnetmask("expert"))),HSpacing(1),
                       HWeight( 1, ComboBox(Id(:expert_server_nm), _("Servernet Netmask"),lnetmask("expert"))),
                       HWeight( 1, InputField(Id(:expert_backup),  _("Backup IP"),"")),
                    )),
                    Left(HBox(
                       HSpacing(8),
                       HWeight( 1, InputField(Id(:expert_anon),   _("ANON_DHCP Start IP"),"")),HSpacing(1),
                       HWeight( 1, ComboBox(Id(:expert_anon_nm),  _("ANON_DHCP Netmask"),lnetmask("expert"))),HSpacing(1),
                       HWeight( 1, InputField(Id(:expert_first),  _("First Room IP"),"")),
                       HWeight( 1, Label(""))
                    )),
                    VSpacing(1),
                    HBox(
                       HSpacing(8),
                       Left(CheckBox(Id(:use_dhcp), _("Enable DHCP Server"), true )),
                       HSpacing(8),
                       Left(CheckBox(Id(:is_gate),  _("The OSS is the Gateway"), true )),
                       HSpacing(8)
                    ),
                    VSpacing(1)
                  )
                ),
              HSpacing(8)
            )
            
            # Dialog
            Wizard.SetContentsButtons(
              caption,
              contents,
              help,
              Label.BackButton,
              Label.NextButton
            )
            UI.SetFocus(Id(:schoolname))
            valid_domain_chars = ".0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-"
            UI.ChangeWidget(Id(:domain), :ValidChars, valid_domain_chars)
            UI.ChangeWidget(Id(:expert_network), :Enabled, false)
            UI.ChangeWidget(Id(:expert_netmask), :Enabled, false)
            UI.ChangeWidget(Id(:expert_server_nm), :Enabled, false)
            UI.ChangeWidget(Id(:expert_anon), :Enabled, false)
            UI.ChangeWidget(Id(:expert_anon_nm), :Enabled, false)
            UI.ChangeWidget(Id(:expert_admin), :Enabled, false)
            UI.ChangeWidget(Id(:expert_portal), :Enabled, false)
            UI.ChangeWidget(Id(:expert_proxy), :Enabled, false)
            UI.ChangeWidget(Id(:expert_print), :Enabled, false)
            UI.ChangeWidget(Id(:expert_backup), :Enabled, false)
            UI.ChangeWidget(Id(:expert_first), :Enabled, false)
 
            ret = nil
            while true
              ret = UI.UserInput
              Builtins.y2debug("ret=%1", ret)
              case ret
              when :abort, :cancel
                if Popup.ReallyAbort(true)
                  return :abort
                else
                  next
                end
              when :expert_settings
                if Convert.to_boolean(UI.QueryWidget(Id(:expert_settings),   :Value))
                   Popup.Warning(_("Selecting the expert settings, there is no guaranty that the installation will success."))
                   UI.ChangeWidget(Id(:net0), :Enabled, false)
                   UI.ChangeWidget(Id(:net1), :Enabled, false)
                   UI.ChangeWidget(Id(:netm), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_network), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_netmask), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_server_nm), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_anon), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_anon_nm), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_admin), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_portal), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_proxy), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_print), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_backup), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_first), :Enabled, true)
                else
                   UI.ChangeWidget(Id(:net0), :Enabled, true)
                   UI.ChangeWidget(Id(:net1), :Enabled, true)
                   UI.ChangeWidget(Id(:netm), :Enabled, true)
                   UI.ChangeWidget(Id(:expert_network), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_netmask), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_server_nm), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_anon), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_anon_nm), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_admin), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_portal), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_proxy), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_print), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_backup), :Enabled, false)
                   UI.ChangeWidget(Id(:expert_first), :Enabled, false)
                end
              when :net0
                 net = Convert.to_string(UI.QueryWidget(Id(:net0),    :Value))
                 nm  = Convert.to_integer(UI.QueryWidget(Id(:netm),   :Value))
                 UI.ReplaceWidget(Id(:rep_net1),ComboBox(Id(:net1)," ", lnet1(net,nm) ))
                 UI.ReplaceWidget(Id(:rep_nm),  ComboBox(Id(:netm),Opt(:notify),_("Netmask"),lnetmask(net)))
                 next
              when :netm
                 net = Convert.to_string(UI.QueryWidget(Id(:net0),   :Value))
                 nm  = Convert.to_integer(UI.QueryWidget(Id(:netm),  :Value))
                 UI.ReplaceWidget(Id(:rep_net1),ComboBox(Id(:net1)," ", lnet1(net,nm) ))
                 next
             when :next
                 if Convert.to_boolean(UI.QueryWidget(Id(:expert_settings),   :Value))
                   netm  = Convert.to_string(UI.QueryWidget(Id(:expert_netmask),   :Value))
                   nets  = Convert.to_string(UI.QueryWidget(Id(:expert_network),   :Value))
                   admin = Convert.to_string(UI.QueryWidget(Id(:expert_admin),    :Value))
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETMASK"),      netm )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETMASK_STRING"), Netmask.FromBits(netm.to_i) )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETWORK"),      nets )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER"),       admin )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_MAILSERVER"),   Convert.to_string(UI.QueryWidget(Id(:expert_portal),   :Value)) )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_PRINTSERVER"),  Convert.to_string(UI.QueryWidget(Id(:expert_print),    :Value)) )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_PROXY"),        Convert.to_string(UI.QueryWidget(Id(:expert_proxy),    :Value)) )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_BACKUP_SERVER"),Convert.to_string(UI.QueryWidget(Id(:expert_backup),   :Value)) )
                   anon_start = Convert.to_string(UI.QueryWidget(Id(:expert_anon),    :Value))
                   anon_nm    = Convert.to_string(UI.QueryWidget(Id(:expert_anon_nm), :Value))
                   anon_end   = IP.ComputeBroadcast(anon_start,Netmask.FromBits(anon_nm.to_i))
                   anon_start = IP.ComputeNetwork(anon_start,  Netmask.FromBits(anon_nm.to_i))
                   SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_RANGE"), anon_start + " " + anon_end)
                   SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_NET"),   anon_start + "/" + anon_nm )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_FIRST_ROOM_NET"), Convert.to_string(UI.QueryWidget(Id(:expert_first),   :Value)) )
                   server_nm    = Convert.to_string(UI.QueryWidget(Id(:expert_server_nm), :Value))
                   server_start = IP.ComputeNetwork(admin,  Netmask.FromBits(server_nm.to_i))
                   SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_NET"), server_start + "/" + server_nm )
                 else
                   net0 = Convert.to_string(UI.QueryWidget(Id(:net0),   :Value))
                   net1 = Convert.to_string(UI.QueryWidget(Id(:net1),   :Value))
                   netm = Convert.to_string(UI.QueryWidget(Id(:netm),   :Value))
                   nets = net0 + "." + net1
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETMASK"),      netm )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETMASK_STRING"), Netmask.FromBits(netm.to_i) )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_NETWORK"),      nets )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER"),       nets.chomp("0") + "2" )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_MAILSERVER"),   nets.chomp("0") + "3" )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_PRINTSERVER"),  nets.chomp("0") + "4" )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_PROXY"),        nets.chomp("0") + "5" )
                   SCR.Write(path(".etc.schoolserver.SCHOOL_BACKUP_SERVER"),nets.chomp("0") + "6" )
                   case netm
                   when "24","23","22"
                        SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_RANGE"), nets.chomp("0") + "32 " + nets.chomp("0") + "63" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_NET"),   nets.chomp("0") + "32/27" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_FIRST_ROOM_NET"),  nets.chomp("0") + "64" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_NET"),      nets.chomp("0") + "0/27" )
                   else
                        SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_RANGE"), nets.chomp("0.0") + "1.0 " + nets.chomp("0.0") + "1.255" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_ANON_DHCP_NET"),   nets.chomp("0.0") + "1.0/24" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_FIRST_ROOM_NET"),  nets.chomp("0.0") + "2.0" )
                        SCR.Write(path(".etc.schoolserver.SCHOOL_SERVER_NET"),      nets.chomp("0")   + "0/24" )
                   end
                 end
                 domain = Convert.to_string(UI.QueryWidget(Id(:domain),:Value))
                 if domain.split(".").size < 2
                    msg = Builtins.sformat(_("'%1' is an invalid Domain Name. Use something like school.edu."), domain)
                    Popup.Error(msg)
                    UI.SetFocus(Id(:domain))
                    next
                 end
                 if domain.match('\.local$') 
                    msg = Builtins.sformat(_("'%1' is an invalid Domain Name. Use something like school.edu."), domain)
                    Popup.Error(msg)
                    UI.SetFocus(Id(:domain))
                    next
                 end
                 #Evaluate workgroup. This must not be longer then 15 Char
                 workgroup=domain.split(".")[0].upcase
                 if workgroup.size > 15
                    workgroup=GetWorkgroup()
                 end
                 SCR.Write(path(".etc.schoolserver.SCHOOL_NAME"),         Convert.to_string(UI.QueryWidget(Id(:schoolname),:Value)))
                 SCR.Write(path(".etc.schoolserver.SCHOOL_DOMAIN"),       domain )
                 SCR.Write(path(".etc.schoolserver.SCHOOL_WORKGROUP"),    workgroup )
                 SCR.Write(path(".etc.schoolserver.SCHOOL_REG_CODE"),     Convert.to_string(UI.QueryWidget(Id(:regcode),:Value)))
                 SCR.Write(path(".etc.schoolserver.SCHOOL_TYPE"),         Convert.to_string(UI.QueryWidget(Id(:type),:Value)))
                 SCR.Write(path(".etc.schoolserver.SCHOOL_ISGATE"),       Convert.to_boolean(UI.QueryWidget(Id(:is_gate),:Value)) ? "yes" : "no" )
                 SCR.Write(path(".etc.schoolserver.SCHOOL_USE_DHCP"),     Convert.to_boolean(UI.QueryWidget(Id(:use_dhcp),:Value)) ? "yes" : "no" )
                 SCR.Write(path(".etc.schoolserver"),nil)
                 ret = :network
                 break
              end
            end
            return ret
        end

        def OssSetup

            Builtins.y2milestone("-- OSS-Setup dialogs.OssSetup Called --")
            Progress.New(
                _("Saving the OSS configuration"),
                " ",
                3,
                [
                    # progress stage 1/10
                    _("Calculate settings"),
                    _("Configure the AD Server"),
                    _("Creating the base Users and Groups"),
                ],
                [
                    # progress step 1/10
                    _("Calculate settings ..."),
                    _("Configure the active directory server ..."),
                    _("Creating the base Users and Groups ..."),
                    # progress finished
                    _("Finished")
                ],
                ""
            )

            # get varible value
            Progress.set(true)
            Progress.NextStage
            Progress.off
            DialogsInst.GetPasswd()

            # configure samba as AD DC
            Progress.set(true)
            Progress.NextStage
            Progress.off
            SCR.Execute(path(".target.bash"), "/usr/share/oss/setup/scripts/oss-setup.sh --passwdf=/tmp/passwd --samba" )

            Progress.set(true)
            Progress.NextStage
            Progress.off
            if SCR.Read(path(".etc.schoolserver.SCHOOL_USE_DHCP")) == "yes"
               SCR.Execute(path(".target.bash"), "/usr/share/oss/setup/scripts/oss-setup.sh --passwdf=/tmp/passwd --accounts --dhcp --postsetup" )
            else
               SCR.Execute(path(".target.bash"), "/usr/share/oss/setup/scripts/oss-setup.sh --passwdf=/tmp/passwd --accounts --postsetup" )
            end
            SCR.Execute(path(".target.bash"), "rm /tmp/passwd")
        end

        def GetPasswd
            if File.exist?("/tmp/may_q_masterpass")
                SCR.Execute(path(".target.bash"), "mv /tmp/may_q_masterpass /tmp/passwd")
                SCR.Execute(path(".target.bash"), "chmod 600 /tmp/passwd")
                return
            end
            UI.OpenDialog(
                Opt(:decorated),
                VBox(
                     Left(Password(Id(:password), _("Administrator Password"), "") ),
                     Left(Password(Id(:password1),   "                     ", "") ),
                     HBox(
                        PushButton(Id(:cancel), _("Cancel")),
                        PushButton(Id(:ok), _("OK"))
                     )
                )
            )
            ret = nil
            while true
                event = UI.WaitForEvent
                ret = Ops.get(event, "ID")
                if ret == :cancel
                    return nil
                end
                if ret == :ok
                    pass = Convert.to_string( UI.QueryWidget(Id(:password), :Value) )
                    pass1 = Convert.to_string( UI.QueryWidget(Id(:password1), :Value) )
                    if( pass != pass1 )
                        Popup.Error(_("The passwords do not match."))
                        next
                    end
                    if( pass.size < 8)
                        Popup.Error(_("The passsword must contains minimum 8 character."))
                        next
                    end
                    if( pass.size > 14)
                        Popup.Error(_("The passsword must not contains more then 14 character."))
                        next
                    end
                    o,s = Open3.capture2("/usr/share/oss/tools/check_password_complexity.sh", :stdin_data => pass)
                    if( o.size > 0 )
                        Popup.Error(_(o))
                        next
                    end
                    UI.CloseDialog
                        SCR.Write(path(".target.string"), "/tmp/passwd", pass)
                    break
                end
            end
            SCR.Execute(path(".target.bash"), "chmod 600 /tmp/passwd")
            #UI.CloseDialog
        end

        def GetWorkgroup
            workgroup = ""
            UI.OpenDialog(
                Opt(:decorated),
                VBox(
                     Left(
                        RichText(
                                Opt(:hstretch),
                               _("The workgroup name calculated from domain name is invalid.<br>") +
                               _("Please provide a valid one. This must not be longer then 15.")
                     )),
                     Left(InputField(Id(:workgroup), Opt(:hstretch), _("Workgroup"), "")),
                     HBox(
                        PushButton(Id(:ok), _("OK"))
                     )
                )
            )
            while true
                event = UI.WaitForEvent
                ret = Ops.get(event, "ID")
                if ret == :ok
                    workgroup = Convert.to_string( UI.QueryWidget(Id(:workgroup), :Value) )
                    if workgroup.size > 15
                        Popup.Error(_("The workgroup name must not be longer then 15."))
                        next
                    end
                    if workgroup.size < 3
                        Popup.Error(_("The workgroup name must not be shorter then 3."))
                        next
                    end
                    if workgroup[0] == '*'
                        Popup.Error(_("The workgroup name must not start with '*'"))
                        next
                    end
                    break
                end
            end
            UI.CloseDialog
            return workgroup.upcase
        end

        #Some internal use only functions
        :privat
        def read_net_cards(device)
            Builtins.y2milestone("-- OSS-Setup read_net_cards Called --")
            LanItems.Read()
            cards = []
            Builtins.foreach(
              Convert.convert(
                Map.Keys(LanItems.Items),
                :from => "list",
                :to   => "list <integer>"
              )
            ) do |key|
              name  = Ops.get_string(LanItems.Items, [key, "hwinfo", "name"], "")
              dev   = Ops.get_string(LanItems.Items, [key, "hwinfo", "dev_name"], "")
              mac   = Ops.get_string(LanItems.Items, [key, "hwinfo", "mac"], "")
              link  = Ops.get_boolean(LanItems.Items, [key, "hwinfo", "link"], false ) ? _("Connected") : _("Not Connected")

              next if dev == device
              name  = dev + " : " + mac + " : " + name + " : " + link
              cards << Item(Id(dev), name)
            end
            return cards
        end

        def lnetmask(net)
            from = 16
            to   = 24
            if net == "10"
               from = 8
            end
            if net == "expert"
               from = 8
               to   = 30
            end
            ret = []
            from.upto to do |i|
               ret << i.to_s
            end
            ret
        end

        def lnet1(net,netmask)
            from  = 16
            to    = 31
            from2 = 0
            to2   = 0
            if net == "10"
                from = 0
                to   = 255
            end
            if net == "192"
                from = 168
                to   = 168
            end
            ret = []
            from.upto to do |i|
               from2.upto to2 do |j|
                 ret << i.to_s + "." + j.to_s + ".0"
               end
            end
            ret
        end

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

        def IsInNetwork(tmpnet, tmpnetmask, tmpip)
          net_net = IP.ComputeNetwork(tmpnet, tmpnetmask)
          ip_net  = IP.ComputeNetwork(tmpip, tmpnetmask)
          net_net == ip_net
        end

    end

    DialogsInst = Dialogs.new
end
