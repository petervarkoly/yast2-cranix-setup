# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2017 Dipl. Ing. Peter Varkoly, Nuernberg, Germany.
Yast.import 'Popup'
module Yast
  class InstOssCheckUpdate < Client
    def main
	if !File.exist?("/mnt/home/archive/migrate-to-4-0/SAMBA/passdb.tdb")
		Popup.Error(_("The update prepare script was not executed succesfully."))
		return :abort
	end
        :next
    end
  end
end

Yast::InstOssCheckUpdate.new.main

