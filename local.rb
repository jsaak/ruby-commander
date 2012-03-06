#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'base-pane'
require 'fileutils'

class LocalPane
   include Selectable
   attr_accessor :current_dir
   attr_reader :container_widget
   attr_reader :focus_widget
   attr_reader :current_dir

   LS_Name = 1
   LS_Size = 2
   LS_Mdate = 3
   LS_Selected = 4

   def initialize(path = '/')
      glade = GladeXML.new(Config::ShareDir+'local.glade','vbox3') {|handler| method(handler)}
      @tv_dir = glade['treeview_dir']
      @container_widget = glade['vbox3']

      @focus_widget = @tv_dir

      @ls_dir = Gtk::ListStore.new(Gdk::Pixbuf,String,String,String,Gdk::Color)
      if path[-1..-1] != '/'
         path += '/'
      end
      @current_dir = path

      init_selectable(@ls_dir, LS_Selected, @tv_dir)
      #renderer = Gtk::CellRendererText.new
      #col = Gtk::TreeViewColumn.new('name', renderer, :text => 1)
      #@tv_dir.append_column(col)

      # NAME and icon
      r_icon = Gtk::CellRendererPixbuf.new
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'name'
      col.pack_start(r_icon,false)
      # col.add_attribute(r_icon,'stock_id',0)
      col.add_attribute(r_icon,'pixbuf',0)
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',LS_Name)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      col.sizing = Gtk::TreeViewColumn::FIXED 
      col.sort_indicator = true
      col.min_width = 30
      col.fixed_width = 257
      col.resizable = true
      @tv_dir.append_column(col)

      # SIZE
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'size'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',LS_Size)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      col.sizing = Gtk::TreeViewColumn::FIXED 
      col.resizable = true
      col.min_width = 30
      col.fixed_width = 65
      @tv_dir.append_column(col)

      # MDATE
      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'mdate'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',LS_Mdate)
      col.add_attribute(r_text,'foreground_gdk',LS_Selected)
      col.sizing = Gtk::TreeViewColumn::FIXED 
      col.resizable = true
      col.min_width = 30
      col.fixed_width = 100
      @tv_dir.append_column(col)


      @tv_dir.search_column = LS_Name
      @tv_dir.fixed_height_mode = true
      @tv_dir.model=@ls_dir

      @show_hidden = false

      @tv_dir.signal_connect('key-press-event') do |treeview,b|
         #p "press: #{b.keyval}, Gdk::Keyval::GDK_#{Gdk::Keyval.to_name(b.keyval)}"
         event_handled = false
         case b.keyval
         when Gdk::Keyval::GDK_F3
            view_or_edit('view')
            event_handled = true
         when Gdk::Keyval::GDK_F4
            view_or_edit('edit')
            event_handled = true
         when Gdk::Keyval::GDK_F6
            if b.state & Gdk::Window::SHIFT_MASK > 0
               ret = rename_dialog(current_name)
               unless ret.nil?
                  rename(ret)
               end
               event_handled = true
            end
         when Gdk::Keyval::GDK_F7
            ret = mkdir_dialog
            unless ret.nil?
               mkdir(ret)
               refresh
               focus_item(ret)
            end
            event_handled = true
         when Gdk::Keyval::GDK_F8, Gdk::Keyval::GDK_Delete
            s = selected_files
            if delete_dialog(s)
               delete(s)
               refresh_but_current_disappeared
            end
            event_handled = true
         when Gdk::Keyval::GDK_Left
            if b.state & Gdk::Window::CONTROL_MASK > 0
               navigate('left')
            else
               left
            end
            event_handled = true
         when Gdk::Keyval::GDK_Right
            if b.state & Gdk::Window::CONTROL_MASK > 0
               navigate('right')
            else
               right
            end
            event_handled = true
         when Gdk::Keyval::GDK_r
            if b.state & Gdk::Window::CONTROL_MASK > 0
               refresh_and_preserve_cursor
            end
            event_handled = true
         when Gdk::Keyval::GDK_period
            if b.state & Gdk::Window::CONTROL_MASK > 0
               if @show_hidden
                  @show_hidden = false
               else
                  @show_hidden = true
               end
               refresh_and_preserve_cursor
            end
            event_handled = true
         end
         event_handled
      end

      #@cursor_moved = false
      #@manual_cursor_change = false

      @vadjustment_hash = Hash.new

      #@tv_dir.signal_connect('expose-event') do
      #end

      #@tv_dir.signal_connect('cursor-changed') do
         #p 'cursor_changed ' + @cursor_moved.inspect + ' ' + @manual_cursor_change.inspect
         #@cursor_moved = false
         #if @cursor_moved == false and @manual_cursor_change == false
            #@manual_cursor_change = true
            #p 'setting focus'
            #@tv_dir.set_cursor(@tv_dir.cursor[0],nil,false)
            #@manual_cursor_change = false
         #end
      #end

      #@tv_dir.signal_connect('move-cursor') do
         #@cursor_moved = true
         #p 'move_cursor'
      #end

      #@tv_dir.signal_connect('select-cursor-row') do
         #p 'select_cursor_row'
      #end

      #@tv_dir.signal_connect('focus-out-event') do
         #@tv_dir.selection.unselect_all
      #end

      #@tv_dir.signal_connect('focus-in-event') do
         #path = @tv_dir.cursor[0]
         #if path.nil?
            #focus_first
         #else
            #@tv_dir.set_cursor(@tv_dir.cursor[0],nil,false)
         #end
      #end

      #p @tv_dir.style
      #@tv_dir.style.set_fg(Gtk::STATE_SELECTED,65000,0,0)
      @icons = Global.instance.icons
   end

   def refresh_and_preserve_cursor
      item = current_name
      refresh
      focus_item(item)
   end

   def refresh_but_current_disappeared
      path = current_path
      refresh
      focus_path(path)
   end

   def navigate(direction)
      path = @tv_dir.cursor[0]
      iter = @ls_dir.get_iter(path)
      Commander.instance.navigate(direction,@current_dir,iter[LS_Name])
   end

   def current_path
      return @tv_dir.cursor[0]
   end

   def current_iter
      path = @tv_dir.cursor[0]
      iter = @ls_dir.get_iter(path)
      return iter
   end

   def current_name
      path = @tv_dir.cursor[0]
      iter = @ls_dir.get_iter(path)
      item = iter[LS_Name]
      return item
   end

   def rename_dialog(x)
      dialog = Gtk::Dialog.new("Rename", @window_main,
                               Gtk::Dialog::DESTROY_WITH_PARENT | Gtk::Dialog::MODAL | Gtk::Dialog::NO_SEPARATOR,
                               [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                               [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])

      entry = Gtk::Entry.new
      entry.activates_default = true
      entry.text = x

      dialog.vbox.add(entry)
      dialog.default_response=Gtk::Dialog::RESPONSE_ACCEPT
      dialog.show_all

      resp = dialog.run
      if resp == Gtk::Dialog::RESPONSE_ACCEPT
         ret = entry.text
      else
         ret = nil
      end
      dialog.destroy
      return ret
   end

   def rename(x)
      iter = current_iter
      begin
         FileUtils.mv(@current_dir + iter[LS_Name], @current_dir + x)
         refresh
         focus_item(x)
      rescue Errno::EACCES => e
         Commander.instance.message('Permission denied')
      end
   end

   def mkdir_dialog
      dialog = Gtk::Dialog.new("Make directory", @window_main,
                               Gtk::Dialog::DESTROY_WITH_PARENT | Gtk::Dialog::MODAL | Gtk::Dialog::NO_SEPARATOR,
                               [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                               [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])

      entry = Gtk::Entry.new
      entry.activates_default = true

      dialog.vbox.add(entry)
      dialog.default_response=Gtk::Dialog::RESPONSE_ACCEPT
      dialog.show_all

      resp = dialog.run
      if resp == Gtk::Dialog::RESPONSE_ACCEPT
         ret = entry.text
      else
         ret = nil
      end
      dialog.destroy
      return ret
   end

   def delete_dialog(files)
      text = "Do you really want to delete #{files.size} files?\n"
      secondary = ''
      counter = 0
      files.each do |fn|
         secondary += fn + "\n"
         counter += 1
         if counter == 15
            secondary += '...'
            break
         end
      end

      dialog = Gtk::MessageDialog.new(@window_main,
                                      Gtk::Dialog::DESTROY_WITH_PARENT | Gtk::Dialog::MODAL,
                                      Gtk::MessageDialog::WARNING,
                                      Gtk::MessageDialog::BUTTONS_OK_CANCEL,
                                      text)

      dialog.default_response=Gtk::Dialog::RESPONSE_OK
      dialog.secondary_text = secondary

      resp = dialog.run
      if resp == Gtk::Dialog::RESPONSE_OK
         dialog.destroy
         return true
      else
         dialog.destroy
         return false
      end
   end

   def delete(files)
      files.each do |fn|
         begin
            FileUtils.remove_entry(fn)
         rescue Errno::EACCES => e
            Commander.instance.message('Permission denied')
         end
      end
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.stock = 'gtk-directory'
      @cbe.text = @current_dir
      refresh()
      focus_first
   end

   def refresh
      @cbe.text = @current_dir

      @ls_dir.clear
      2.times do |run|
         Dir.entries(@current_dir).sort.each do |fn|
            #current_dir?
            next if fn == '.'

            #hidden?
            unless @show_hidden
               next if fn[0..0] == '.' and fn != '..'
            end

            #symlink?
            stat = File.lstat(@current_dir+fn)
            if stat.symlink?
               # TODO make a different icon for symlinks
               begin
                  path = @current_dir+fn
                  stat = File.stat(path)
               rescue
                  puts "invalid symlink: #{path}"
                  next
               end
            end
            if run == 0
               if stat.directory? 
                  iter = @ls_dir.append
                  if fn == '..'
                     iter[0] = @icons['undo']
                  else
                     iter[0] = @icons['directory']
                  end
                  # iter[1] = '['+fn+']'
                  iter[LS_Name] = fn
                  iter[LS_Size] = '<DIR>'
                  mtime = stat.mtime.strftime('%Y.%m.%d %H:%M')
                  iter[LS_Mdate] = mtime
                  iter[LS_Selected] = @color_fg_default
               end
            else
               unless stat.directory? 
                  iter = @ls_dir.append
                  ext = fn.split('.')[-1]
                  type = Preferences::Extensions[ext.downcase]
                  if type.nil?
                     iter[0] = @icons['default']
                  else
                     iter[0] = @icons[type]
                  end
                  iter[LS_Name] = fn
                  #size = (File.stat(@current_dir+fn).size / 1024.0).round.to_s
                  size = stat.size.to_s
                  iter[LS_Size] = size
                  mtime = stat.mtime.strftime('%Y.%m.%d %H:%M')
                  iter[LS_Mdate] = mtime
                  iter[LS_Selected] = @color_fg_default
               end
            end
         end
      end
   end

   def focus_item(item)
      @tv_dir.model.each do |store, path, iter|
         if iter[LS_Name] == item
            @tv_dir.set_cursor(path,nil,false)
            return
         end
      end
      focus_first
   end

   #def focus_path(path)
      #unless path.nil?
         #@tv_dir.set_cursor(path,nil,false)
      #end
   #end

   #def focus_first
      #@tv_dir.model.each do |store, path, iter|
         #@tv_dir.set_cursor(path,nil,false)
         #return
      #end
   #end

   def on_quit
   end

   def on_treeview_dir_row_activated(tv,tp,tvc)
      activate_current(tp)
   end

   def right
      path = @tv_dir.cursor[0]
      unless @ls_dir.get_iter(path)[LS_Name] == '..'
         activate_current(@tv_dir.cursor[0])
      end
   end

   def activate_current(path)
      iter = @ls_dir.get_iter(path)
      if iter[LS_Size] == '<DIR>'
         if iter[LS_Name] == '..'
            go_up
         else
            @vadjustment_hash[@current_dir] = @tv_dir.vadjustment.value
            go_to_dir(@current_dir + iter[LS_Name] + '/')
         end
      else
         ext = iter[LS_Name].split('.')[-1]
         x = Preferences::Extensions[ext.downcase]
         unless x.nil?
            if x == 'package'
            elsif x == 'audio'
            else
               view_or_edit('view')
            end
         end
      end
   end

   def go_to_dir(dir,item = nil)
      begin
         Dir.entries(dir)
         @current_dir = dir
         refresh
         focus_item(item)
      rescue Errno::EACCES => e
         Commander.instance.message('Permission denied')
      end
   end

   def view_or_edit(op)
      path = @tv_dir.cursor[0]
      iter = @ls_dir.get_iter(path)
      unless iter[LS_Size] == '<DIR>'
         ext = iter[LS_Name].split('.')[-1]
         x = Preferences::Extensions[ext.downcase]
         if x.nil?
            x = 'default'
         end

         to_view, to_edit = Preferences::Associations[x]
         if to_view.nil? or to_edit.nil?
            Commander.instance.message('Associatons not found')
         else
            escaped_filename = '"' + @current_dir + iter[LS_Name].gsub('"','\"') + '"'
            if op == 'view'
               command = to_view.gsub('%f',escaped_filename)
            else
               command = to_edit.gsub('%f',escaped_filename)
            end
            pid = fork do 
               exec command
            end
         end
      end
   end

   def left
      go_up
   end

   def go_up
      unless @current_dir == '/'
         x = @current_dir.split('/')
         @going_up = true
         updir = x[0..-2].join('/')+'/'
         go_to_dir(updir, x[-1])
         vadj = @vadjustment_hash[updir]
         unless vadj.nil?
            while (Gtk.events_pending?)
               Gtk.main_iteration
            end
            #puts 'setting vadjustment to ' + vadj.to_s
            @tv_dir.vadjustment.value = vadj
         end
      end
   end

   #TODO set the text color when row is selected
      #@tv_dir.selection.style.set_text(Gtk::STATE_SELECTED,65000,0,0)
      #@tv_dir.style.set_text(Gtk::STATE_ACTIVE,65000,0,0)
      #@tv_dir.style.set_base(Gtk::STATE_SELECTED,65000,0,0)
      #@tv_dir.style.set_base(Gtk::STATE_ACTIVE,65000,0,0)
      #@tv_dir.style.set_bg(Gtk::STATE_SELECTED,65000,0,0)
      #@tv_dir.style.set_bg(Gtk::STATE_ACTIVE,65000,0,0)
      #@tv_dir.style.set_fg(Gtk::STATE_SELECTED,65000,0,0)
      #@tv_dir.style.set_fg(Gtk::STATE_ACTIVE,65000,0,0)
   
   def selected_files
      a = Array.new
      selected_iters do |iter|
         a.push(@current_dir+iter[LS_Name])
      end
      return a
   end

   def unregister
   end

   def select_all
      @ls_dir.each do |t,p,iter|
         unless iter[LS_Name] == '..'
            iter[LS_Selected] = @color_fg_selected
         end
      end
   end

   def mkdir(x)
      begin
         FileUtils.mkdir(@current_dir+x)
      rescue Errno::EACCES => e
         Commander.instance.message('Permission denied')
      end
   end
end

