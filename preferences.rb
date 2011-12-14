module Preferences
   # type = one of 'local', 'remote', 'mplayer', 'usb'
   #    mplayer is not a filesystem, but a shortcut is nice here
   # name = name of the shortcut
   # url = must be a local path now
   # command to mount or nil
   # command to umount or nil
   #
   # do not forget to remove the last comma from the list
=begin
   Bookmarks = [
      ['local','root','/'],
      ['mplayer','mplayer','mplayer']
   ]
=end

   SelectedColor = [65535,65535,30000]

   Bookmarks = [
      ['local','home','/home/jsaak',nil,nil],
      ['local','zene','/home/jsaak/zene',nil,nil],
      ['local','film','/home/jsaak/film',nil,nil],
      ['local','download','/home/jsaak/download',nil,nil],
      ['remote','napalm', '/home/jsaak/remote/napalm.hu/data/kozos',
            'sshfs napalm.hu:/ /home/jsaak/remote/napalm.hu',
            'umount /home/jsaak/remote/napalm.hu'],
      ['remote','woland', '/home/jsaak/remote/woland/home/jsaak',
            'sshfs woland:/ /home/jsaak/remote/woland',
            'umount /home/jsaak/remote/woland'],
      ['usb','kingston','/media/KINGSTON',nil,'umount /media/KINGSTON'],
      ['usb','muvo','/media/disk',nil,'umount /media/disk'],
      ['mplayer','mplayer','mplayer',nil,nil]
   ]


   # what to do with the files
   # first is view (F3), second is edit (F4)
   # %f is the path and filename escaped with "
   Associations = {
      'default' => ['gvim %f', 'gvim %f'],
      'picture' => ['geeqie -t %f', 'gimp %f'],
      'video' => ['mplayer %f', 'mplayer %f']
   }

   # there are 3 ways to get an icon
   # 1. load a default one from /usr/share/ruby-commander/icon/  => 'directory.png'
   # 2. load a theme icon => 'theme:gtk_directory'
   # 3. load a customized icon => '/path/to/my/icon/directory.png'
   #
   # use 16*16 icons
=begin
   Icons = {
      'default' => 'file4.png',
      'directory' => 'directory.png',
      'undo' => 'undo.png',
      'package' => 'package.png',
      'video' => 'movie.png',
      'audio' => 'wave.png',
      'picture' => 'picture.png'
   }
=end

   Icons = {
      'default' => 'theme:gtk-file',
      'directory' => 'theme:gtk-directory',
      'undo' => 'theme:gtk-undo-ltr',
      'usb' => 'usb.png',
      'bookmark' => 'bookmark.png',
      #'home' => 'theme:gtk-home',
      'network' => 'theme:gtk-network',
      'play' => 'theme:gtk-media-play-ltr',
      'error' => 'theme:gtk-dialog-error',
      #'yes' => 'theme:gtk-yes',
      #'no' => 'theme:gtk-no',
      'package' => 'theme:gnome-package',
      'video' => 'theme:gnome-mime-video',
      'audio' => 'theme:gnome-mime-audio',
      'picture' => 'theme:gnome-mime-image'
   }

   Extensions = {
      'avi' => 'video',
      'mpg' => 'video',
      'mpeg' => 'video',
      'mpeg4' => 'video',
      'mov' => 'video',
      'mp4' => 'video',
      'divx' => 'video',
      'ogm' => 'video',
      'wmv' => 'video',
      'flv' => 'video',

      'mp3' => 'audio',
      'wav' => 'audio',
      'wma' => 'audio',
      'ogg' => 'audio',

      'png' => 'picture',
      'jpg' => 'picture',
      'bmp' => 'picture',
      'svg' => 'picture',
      'svgz' => 'picture',
      'tiff' => 'picture',

      'deb' => 'package',
      'rpm' => 'package',
      'zip' => 'package',
      'arj' => 'package',
      'rar' => 'package',
      '7z' => 'package',
      'gz' => 'package',
      'tar' => 'package',
      'tgz' => 'package',
      'ace' => 'package'
   }
end

