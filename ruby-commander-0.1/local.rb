#!/usr/bin/ruby

require 'libglade2'
require 'glib2'

class LocalPane
   attr_accessor :current_dir
   attr_reader :container_widget
   attr_reader :focus_widget

   def initialize(path = '/')
      glade = GladeXML.new(Config::GladeDir+'local.glade','vbox3') {|handler| method(handler)}
      @tv_dir = glade['treeview_dir']
      @container_widget = glade['vbox3']
      @cb_hidden = glade['cb_hidden']
      @cb_hidden.can_focus = false

      @focus_widget = @tv_dir

      @ls_dir = Gtk::ListStore.new(String,String,String,String)
      @current_dir = path

      #renderer = Gtk::CellRendererText.new
      #col = Gtk::TreeViewColumn.new('name', renderer, :text => 1)
      #@tv_dir.append_column(col)

      r_icon = Gtk::CellRendererPixbuf.new
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'name'
      col.pack_start(r_icon,false)
      col.add_attribute(r_icon,'stock_id',0)
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',1)
      col.sizing = Gtk::TreeViewColumn::FIXED 
      col.sort_indicator = true
      col.min_width = 30
      col.fixed_width = 257
      col.resizable = true
      @tv_dir.append_column(col)

      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new('size', renderer, :text => 2)
      @tv_dir.append_column(col)

      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new('mdate', renderer, :text => 3)
      @tv_dir.append_column(col)

      @tv_dir.selection.mode = Gtk::SELECTION_MULTIPLE
      @tv_dir.search_column = 1

      #TODO
      #@tv_dir.fixed_height_mode = true
      @tv_dir.model=@ls_dir
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.stock = 'gtk-directory'
      @cbe.text = @current_dir
      refresh()
   end

   def refresh(item = nil)
      @cbe.text = @current_dir

      @ls_dir.clear
      2.times do |run|
         Dir.entries(@current_dir).sort.each do |fn|
            next if fn == '.'
            unless @cb_hidden.active?
               next if fn[0..0] == '.' and fn != '..'
            end
            if run == 0
               if File.stat(@current_dir+fn).directory? 
                  iter = @ls_dir.append
                  if fn == '..'
                     iter[0] = Gtk::Stock::UNDO
                  else
                     iter[0] = Gtk::Stock::DIRECTORY
                  end
                  # iter[1] = '['+fn+']'
                  iter[1] = fn
                  iter[2] = '<DIR>'
                  mtime = File.stat(@current_dir+fn).mtime.strftime('%Y.%m.%d %H:%M')
                  iter[3] = mtime
               end
            else
               unless File.stat(@current_dir+fn).directory? 
                  iter = @ls_dir.append
                  iter[0] = 'gtk-file'
                  iter[1] = fn
                  #size = (File.stat(@current_dir+fn).size / 1024.0).round.to_s
                  size = File.stat(@current_dir+fn).size.to_s
                  iter[2] = size
                  mtime = File.stat(@current_dir+fn).mtime.strftime('%Y.%m.%d %H:%M')
                  iter[3] = mtime
               end
            end
         end
      end

      if item.nil?
         @tv_dir.model.each do |store, path, iter|
            @tv_dir.set_cursor(path,nil,false)
            return
         end
      else
         @tv_dir.model.each do |store, path, iter|
            if iter[1] == item
               @tv_dir.set_cursor(path,nil,false)
               return
            end
         end
      end
   end

   def on_quit
   end

   def on_dir_row_activated(tv,tp,tvc)
      x = @ls_dir.get_iter(tp)
      if x[2] == '<DIR>'
         if x[1] == '..'
            x = @current_dir.split('/')
            @current_dir = x[0..-2].join('/')+'/'
            refresh(x[-1])
         else
            @current_dir += x[1] + '/'
            refresh()
         end
      end
   end

   def on_cb_hidden_toggled
      #refresh
      50.times do
         refresh
      end
   end

   def source
      a = Array.new
      @tv_dir.selection.selected_each do |mod, path, iter|
         a.push(@current_dir+iter[1])
      end
      return a
   end

   def unregister
   end
end

