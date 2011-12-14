#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'

class BookmarkPane
   attr_reader :container_widget
   attr_reader :focus_widget

   def initialize()
      glade = GladeXML.new(Config::GladeDir+'bookmark.glade','vbox3') {|handler| method(handler)}
      @tv_dir = glade['treeview_dir']
      @container_widget = glade['vbox3']

      @focus_widget = @tv_dir

      #col = Gtk::TreeViewColumn.new('icon', renderer, :stock_id => 0)

      r_icon = Gtk::CellRendererPixbuf.new
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'name'
      col.pack_start(r_icon,false)
      col.add_attribute(r_icon,'stock_id',0)
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',1)
      @tv_dir.append_column(col)

      #renderer = Gtk::CellRendererText.new
      #col = Gtk::TreeViewColumn.new('name', renderer, :text => 1)
      #@tv_dir.append_column(col)

      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new('url', renderer, :text => 2)
      @tv_dir.append_column(col)

      #@tv_dir.selection.mode = Gtk::SELECTION_MULTIPLE
      @tv_dir.search_column = 1

      @tv_dir.model=BookmarkSingleton.instance.ls_bookmark
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.stock = 'gtk-home'
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
      x = BookmarkSingleton.instance.ls_bookmark.get_iter(tp)
      if x[3] == 'local'
         Commander.instance.set_current_pane(LocalPane,x[2])
      elsif x[3] == 'mplayer'
         Commander.instance.set_current_pane(MPlayerPane)
      end
   end

   def source
      a = Array.new
      @tv_dir.selection.selected_each do |mod, path, iter|
         a.push(@current_dir+iter[2])
      end
      return a
   end

   def destination(a)
   end

   def unregister
   end
end

class BookmarkSingleton
   include Singleton
   attr_reader :ls_bookmark

   def initialize
      @ls_bookmark = Gtk::ListStore.new(String,String,String,String)
      load_bookmarks
   end

   def load_bookmarks
      @ls_bookmark.clear

      begin
         f = File.new(Commander.instance.config_dir+'/bookmark.cfg','r')
         f.each_line do |l|
            l.strip!
            type, name, url = l.split('|')

            iter = @ls_bookmark.append
            if type == 'local'
               iter[0] = 'gtk-directory'
            elsif type == 'mplayer'
               iter[0] = 'gtk-media-play'
            else
               iter[0] = 'gtk-new'
            end
            iter[1] = name
            iter[2] = url.strip
            iter[3] = type
         end
         f.close
      rescue Errno::ENOENT => e
         iter = @ls_bookmark.append
         iter[0] = 'gtk-directory'
         iter[1] = 'root'
         iter[2] = '/'
         iter[3] = 'local'

         iter = @ls_bookmark.append
         iter[0] = 'gtk-media-play'
         iter[1] = 'mplayer'
         iter[2] = 'mplayer'
         iter[3] = 'mplayer'
         save_bookmarks
      end
   end

   def save_bookmarks
      f = File.new(Commander.instance.config_dir+'/bookmark.cfg','w')
      @ls_bookmark.each do |ls, tp, iter|
         f.puts iter[3] + '|' + iter[1] + '|' + iter[2]
      end
      f.close
   end
end
