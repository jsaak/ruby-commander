#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'
require 'base-pane'

module BookmarkConst
   LS_Icon = 0
   LS_Name = 1
   LS_Url = 2
   LS_Type = 3
   LS_Selected = 4
   LS_Mounted = 5
   LS_Cmd_mount = 6
   LS_Cmd_umount = 7
end

class BookmarkPane
   include Selectable
   include BookmarkConst
   attr_reader :container_widget
   attr_reader :focus_widget

   def initialize(commander)
      glade = GladeXML.new(Config::ShareDir+'bookmark.glade','vbox3') {|handler| method(handler)}
      @tv_dir = glade['treeview_dir']
      @container_widget = glade['vbox3']

      @focus_widget = @tv_dir

      r_icon = Gtk::CellRendererPixbuf.new
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'name'
      col.pack_start(r_icon,false)
      col.add_attribute(r_icon,'pixbuf',LS_Icon)
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',LS_Name)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      @tv_dir.append_column(col)

      # r_toggle = Gtk::CellRendererToggle.new
      # col = Gtk::TreeViewColumn.new
      # col.title = 'mnt'
      # r_toggle.activatable = true
      # r_toggle.signal_connect('toggled') do |w, path|
         # p w, path
         # iter = treeview.model.get_iter(path)
         # iter[GItm::BUY_INDEX] = !iter[GItm::BUY_INDEX] if (iter)
      # end
      # col.pack_start(r_toggle,true)
      # col.add_attribute(r_toggle,'active',LS_Mounted)
      # col.add_attribute(r_toggle,'inconsistent',6)
      # @tv_dir.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'mnt'
      col.pack_start(r_text,false)
      col.add_attribute(r_text,'text',LS_Mounted)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      @tv_dir.append_column(col)

      #r_icon = Gtk::CellRendererPixbuf.new
      #col = Gtk::TreeViewColumn.new
      #col.title = 'mount'
      #col.pack_start(r_icon,false)
      #col.add_attribute(r_icon,'pixbuf',LS_Mounted)
      #@tv_dir.append_column(col)


      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'url'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',LS_Url)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      @tv_dir.append_column(col)

      @tv_dir.search_column = LS_Name

      @tv_dir.model=BookmarkSingleton.instance.ls_bookmark
      init_selectable(commander,BookmarkSingleton.instance.ls_bookmark,LS_Selected,@tv_dir)

      glade.get_widget('button_mount').can_focus = false
      glade.get_widget('button_unmount').can_focus = false
   end

   def on_button_mount_clicked
      Commander.instance.message('not implemented yet...')
   end

   def on_button_unmount_clicked
      path =  @tv_dir.cursor[0]
      x = BookmarkSingleton.instance.ls_bookmark.get_iter(path)
      
      c = Commander.instance
      if x[LS_Cmd_umount].nil?
         c.message('Can not unmount this: ' + x[LS_Url])
      else
         ret = c.shelljob('Unmounting ' + x[LS_Name],
                                           x[LS_Cmd_umount],
                                           x[LS_Cmd_umount])
         if ret
            c.set_current_pane(LocalPane,x[LS_Url])
         else
            c.message('Unmount failed: "' + x[LS_Cmd_umount] + '"')
         end
      end
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.pixbuf = Global.instance.icons['bookmark']
      @cbe.text = 'bookmarks'
      refresh()
   end

   def refresh(item = nil)
      @tv_dir.model.each do |store, path, iter|
         @tv_dir.set_cursor(path,nil,false)
         return
      end
   end

   def on_quit
   end

   def on_dir_row_activated(tv,tp,tvc)
      go_to(tp)
   end

   def right
      go_to(@tv_dir.cursor[0])
   end

   def go_to(path)
      x = BookmarkSingleton.instance.ls_bookmark.get_iter(path)
      case x[LS_Type]
      when 'local','usb','remote'
         if File.exist?(x[LS_Url])
            Commander.instance.set_current_pane(LocalPane,x[LS_Url])
         else
            if x[LS_Cmd_mount].nil?
               Commander.instance.message('Directory not found: ' + x[LS_Url])
            else
               ret = Commander.instance.shelljob('Mounting ' + x[LS_Name],
                                                 x[LS_Cmd_mount],
                                                 x[LS_Cmd_mount])
               if ret
                  Commander.instance.set_current_pane(LocalPane,x[LS_Url])
               else
                  Commander.instance.message('Mount failed: "' + x[LS_Cmd_mount] + '"')
               end
            end
         end
      when 'mplayer'
         Commander.instance.set_current_pane(MPlayerPane)
      else
         Commander.instance.message('Invalid type : ' + x[LS_Type])
      end
   end

   def source
      a = Array.new
      @tv_dir.selection.selected_each do |mod, path, iter|
         a.push(@current_dir+iter[LS_Url])
      end
      return a
   end

   def destination(a)
   end

   def unregister
   end

   def left
   end
end

class BookmarkSingleton
   include Singleton
   include BookmarkConst
   attr_reader :ls_bookmark

   def initialize
      # @ls_bookmark = Gtk::ListStore.new(Gdk::Pixbuf,String,String,String,Gdk::Color,Gdk::Pixbuf)
      @ls_bookmark = Gtk::ListStore.new(Gdk::Pixbuf,String,String,String,Gdk::Color,String,String,String)
      load_bookmarks
   end

   def load_bookmarks
      @ls_bookmark.clear
      Preferences::Bookmarks.each do |type,name,url,mnt,umnt|
         iter = @ls_bookmark.append
         case type
         when 'local'
            iter[LS_Icon] = Global.instance.icons['directory']
         when 'mplayer'
            iter[LS_Icon] = Global.instance.icons['play']
         when 'remote'
            iter[LS_Icon] = Global.instance.icons['network']
         when 'usb'
            iter[LS_Icon] = Global.instance.icons['usb']
         else
            iter[LS_Icon] = Global.instance.icons['error']
         end
         iter[LS_Name] = name
         iter[LS_Url] = url.strip
         iter[LS_Type] = type
         iter[LS_Selected] = Global.instance.colors['default']
         if type == 'mplayer'
            iter[LS_Mounted] = ''
         elsif File.exist?(iter[LS_Url])
            iter[LS_Mounted] = 'yes'
         else
            iter[LS_Mounted] = 'no'
         end
         iter[LS_Cmd_mount] = mnt
         iter[LS_Cmd_umount] = umnt
      end
   end

   def save_bookmarks
   end
end
