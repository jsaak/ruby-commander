#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'
require 'fileutils'
require 'open4'

require Config::LibDir+'mplayer'
require Config::LibDir+'local'
require Config::LibDir+'bookmark'

config_dir = ENV['HOME'] + '/.ruby-commander'
unless File.exists?(config_dir)
   Dir.mkdir(config_dir)
end
unless File.exists?(config_dir+'/preferences.rb')
   FileUtils.cp(Config::ShareDir+'preferences.rb',config_dir)
end
require config_dir+'/preferences.rb'

class Scheduler
   include Singleton

   def initialize
      @ios = Hash.new
      @sec = Hash.new
      @sec_id = 0
   end

   def add_seconds(mod = 10,&block)
      @sec_id += 1
      @sec[@sec_id] = [mod,block]
      return @sec_id
   end

   def remove_seconds(id)
      @sec.delete(id)
   end

   def add_io(x,&block)
      @ios[x] = block
   end

   #def remove_io(x)
      #p 'delete_io'
      #@ios.delete(x)
   #end

   def another_main_loop
      t = Thread.new do
         counter = 0
         while true
            a = @ios.keys
            ret = select(a,[],a,0.1)

            counter += 1
            if counter > 65000
               counter = 1
            end

            if ret.nil?
               @sec.each do |k,v|
                  mod, block = v
                  if counter % mod == 0
                     block.call
                  end
               end
            else
               r,w,e = ret

               remove_queue = Array.new

               r.each do |x|
                  ret = @ios[x].call(x)
                  if ret == false
                     remove_queue.push(x)
                  end
               end

               remove_queue.each do |x|
                  #puts 'removing ' + x.to_s
                  @ios.delete(x)
               end
                  
               e.each do |x|
                  #puts 'error: ' + x.to_s
                  raise
               end
            end
         end
      end
      return t
   end
end

class Global
   include Singleton
   attr_reader :colors
   attr_reader :icons

   def initialize
      fill_colors
      fill_icons
   end

   def fill_colors
      # COLORS
      # get the used style
      w = Gtk::Window.new
      w.realize
      style = w.style

      @colors = Hash.new
      @colors['default'] = style.text(Gtk::STATE_NORMAL)
      @colors['selected'] = Gdk::Color.new(Preferences::SelectedColor[0],
                                           Preferences::SelectedColor[1],
                                           Preferences::SelectedColor[2])
   end

   def fill_icons
      @icons = Hash.new
      icon_theme = Gtk::IconTheme.default
      Preferences::Icons.each do |name,file|
         if file =~ /\//
            @icons[name] = Gdk::Pixbuf.new(file)
         elsif file =~ /^theme:/
            @icons[name] = icon_theme.load_icon(file[6..-1],16,0).scale(16,16)
         else
            @icons[name] = Gdk::Pixbuf.new(Config::ShareDir + 'icon/' + file)
         end
      end
   end
end

=begin
   #icon_theme = Gtk::IconTheme.default
   #icon_theme.icons
   icon_size = 16
   #@icons['directory'] = icon_theme.load_icon('gtk-directory',icon_size,0)
   @icons['directory'] = Gdk::Pixbuf.new('icon/directory.png')

   # @icons['file'] = icon_theme.load_icon('gtk-file',icon_size,0)
   @icons['file'] = Gdk::Pixbuf.new('icon/file4.png')

   # @icons['undo'] = icon_theme.load_icon('gtk-undo-ltr',icon_size,Gtk::IconTheme::LOOKUP_USE_BUILTIN)
   @icons['undo'] = icon_theme.load_icon('gtk-undo-ltr',icon_size,0)

   # @icons['package'] = icon_theme.load_icon('gnome-package',icon_size,0)
   # @icons['package'] = @icons['file']
   @icons['package'] = Gdk::Pixbuf.new('icon/package.png')

   #@icons['video'] = icon_theme.load_icon('gnome-mime-video',icon_size,0)
   #@icons['video'] = @icons['file']
   @icons['video'] = Gdk::Pixbuf.new('icon/movie.png')

   # @icons['audio'] = icon_theme.load_icon('gnome-mime-audio',icon_size,0)
   @icons['audio'] = Gdk::Pixbuf.new('icon/wave.png')

   #@icons['picture'] = icon_theme.load_icon('gnome-mime-image',icon_size,0)
   #@icons['picture'] = @icons['file']
   @icons['picture'] = Gdk::Pixbuf.new('icon/picture.png')
=end

class Operation
   def initialize
      glade = GladeXML.new(Config::ShareDir+'gui.glade','dialog_operation') {|handler| method(handler)}
      @dialog = glade.get_widget("dialog_operation")
      @label_title = glade.get_widget("label_title")
      @label_description = glade.get_widget("label_description")
      @progressbar = glade.get_widget("progressbar")
      @button_cancel = glade.get_widget("button_cancel")
   end

   def escape(x)
      if x.is_a?(Array)
         return x.map{|f| '"' + f.gsub('"','\"') + '"'}.join(' ')
      else
         return '"' + x.gsub('"','\"') + '"'
      end
   end

   def show(title, description,cmd)
      @dialog.title = title
      @label_title.label = '<big>' + title + '</big>'
      @label_description.text = description
      @pulse = Scheduler.instance.add_seconds(1) do
         @progressbar.pulse
      end
      @button_cancel.grab_focus
      #GLib::Timeout.add(2000) do
         #@dialog.response(3)
      #end

      begin
         pid, stdin, stdout, stderr = Open4::popen4(cmd)
      rescue Errno::ENOENT => e
         p 'command not found'
         return false
      end

      GLib::ChildWatch.add(pid) do |pid,status|
         if status == 0
            @dialog.response(3)
         else
            @dialog.response(4)
         end
      end

      Scheduler.instance.add_io(stderr) { |io|
         p "stderr #{io}"

         keep_watching = true
         begin
            buffer = io.read_nonblock(40960)
            p 1
            p buffer
            p 1
         rescue Errno::EAGAIN
            puts 'eagain'
         rescue EOFError
            puts 'eof'
            keep_watching = false
         end

         keep_watching
      }

=begin
      @thread_flag = false
      Thread.new do
         p 'waitpid start'
         ignored, status = Process.waitpid2(pid)
         puts "status.exitstatus: " + status.exitstatus.inspect
         if status.exitstatus.nil?
            p 'killed'
         elsif status.exitstatus == 0
            @thread_flag = true
            #@dialog.response(3)
            #GLib::Timeout.add(0) do
               #@dialog.response(3)
            #end
         else
            p 'else'
         end
      end
=end

      resp = @dialog.run

      ret = false
      case resp
      when Gtk::Dialog::RESPONSE_DELETE_EVENT, 1
         Process.kill('HUP',pid)
         p 'cancel'
      when 2
         p 'background'
      when 3
         p 'process returns with success'
         ret = true
      when 4
         p 'process returns with an error'
      end

      Scheduler.instance.remove_seconds(@pulse)
      @dialog.hide
      return ret
   end
end

class Commander
   include Singleton
   attr_reader :config_dir

   def initialize
      Global.instance

      # there is a bug somwhere in the ruby binding libs
      # probalbly around (xml or glib or cairo)
      # when a GladieXML file gets garbage collected it produces
      # [BUG] object allocation during garbage collection phase
      # so by referencing it we prevent it from gc
      @prevent_gc_array = Array.new

      glade = GladeXML.new(Config::ShareDir+'gui.glade','window_main') {|handler| method(handler)}
      #@select_window = SelectWindow.new(glade)
      @wm = glade.get_widget("window_main")
      @hp = glade.get_widget("hpaned1")
      @vbox_left = glade.get_widget("vbox_left")
      @vbox_right = glade.get_widget("vbox_right")
      @image_left = glade.get_widget("image_left")
      @image_right = glade.get_widget("image_right")
      @label_left = glade.get_widget("label_left")
      @label_right = glade.get_widget("label_right")
      @tv_background = glade.get_widget("treeview_background")
      @statusbar = glade.get_widget("statusbar")
      @label_left.can_focus = false
      @label_right.can_focus = false

      if ARGV.size > 0 and File.directory?(ARGV[0])
         set_pane(:Left, false, LocalPane, ARGV[0])
      else
         set_pane(:Left, false, LocalPane, ENV['PWD'])
      end
      #set_pane(:Left, false, LocalPane, '/home/jsaak')
      # set_pane(:Left, false, MPlayerPane)
      set_pane(:Right, false, MPlayerPane)

      @tv_background.hide

      glade.get_widget('button_left').can_focus = false
      glade.get_widget('button_right').can_focus = false
      glade.get_widget('button_background').can_focus = false

      @wm.show

      #TODO duplicated
      @config_dir = ENV['HOME'] + '/.ruby-commander'

      #@wm.add_accel_group(accelerator_group)
      #@hp.signal_connect('notify') do |hp, param|
         #puts param.inspect + ' ' + param.class.to_s
         #if param.class == GLib::Param::Int
            #p param.to_i
         #end
      #end

      @ls_background = Gtk::ListStore.new(String,String,Integer,String,String)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'from'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',0)
      @tv_background.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'to'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',1)
      @tv_background.append_column(col)

      r_progress = Gtk::CellRendererProgress.new
      col = Gtk::TreeViewColumn.new
      col.title = 'progress'
      col.pack_start(r_progress,true)
      col.add_attribute(r_progress,'value',2)
      col.sizing = Gtk::TreeViewColumn::FIXED
      col.min_width = 30
      col.fixed_width = 100
      @tv_background.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'speed'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',3)
      @tv_background.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'eta'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',4)
      @tv_background.append_column(col)

      @tv_background.model = @ls_background

      iter = @ls_background.append
      iter[0] = 'from'
      iter[1] = 'to'
      iter[2] = 95
      iter[3] = '125 kb/s'
      iter[4] = '1:10'

      @op = Operation.new

   end

   def shelljob(title,description,cmd)
      @op.show(title,description,cmd)
   end

   def on_quit
      @left.on_quit
      @right.on_quit
      Gtk.main_quit
   end

   def on_button_background_clicked
      if @tv_background.visible?
         @tv_background.hide
      else
         @tv_background.show
      end
   end

   def on_button_left_clicked
      set_pane(:Left, true, BookmarkPane)
   end

   def on_button_right_clicked
      set_pane(:Right, true, BookmarkPane)
   end

   def on_hpaned1_button_press_event(hpaned,e)
      if e.event_type == Gdk::Event::BUTTON2_PRESS
         hpaned.position = hpaned.allocation.width/2
         return

         #puts "on_hpaned1_button_press_event(#{hpaned},#{e})"
         GLib::Idle.add do 
            #TODO 0.1 sleep nem eppen a stabilitast elosegito hack
            sleep(0.1)
            hpaned.position = hpaned.allocation.width/2
            false
         end
      end
   end

   def on_key_press(a,b)
      #p "press: #{b.keyval}, Gdk::Keyval::GDK_#{Gdk::Keyval.to_name(b.keyval)}"
      #p "release: #{b.keyval}, Gdk::Keyval::GDK_#{Gdk::Keyval.to_name(b.keyval)}"
      case b.keyval
      when Gdk::Keyval::GDK_F1
         set_pane(:Left, true, BookmarkPane)
         return true
      when Gdk::Keyval::GDK_F2
         set_pane(:Right, true, BookmarkPane)
         return true
      when Gdk::Keyval::GDK_F5
         copy_or_move('copy')
         return true
      when Gdk::Keyval::GDK_F6
         p (b.state & Gdk::Window::SHIFT_MASK)
         if b.state & Gdk::Window::SHIFT_MASK == 0
            copy_or_move('move')
            return true
         end
      when Gdk::Keyval::GDK_F9
      when Gdk::Keyval::GDK_F10
         on_quit
         return true
      when Gdk::Keyval::GDK_F12
         on_quit
         return true
      when Gdk::Keyval::GDK_Insert
         current_pane.pressed_insert
         return true
      when Gdk::Keyval::GDK_KP_Add
         current_pane.pressed_kp_plus
         return true
      when Gdk::Keyval::GDK_KP_Subtract
         current_pane.pressed_kp_minus
         return true
      end
      return false
   end

   def copy_or_move(op)
      # in case of src or dst is remote
      # rsync -r --partial --progress --bwlimit=2000 --append-verify ../remote/woland/home/jsaak/IDE/starcraftmaps.zip ./
      # if move then
      # rm #{file}
      src = current_pane
      if src == @left
         dst = @right
      else
         dst = @left
      end
      if src.class == LocalPane
         if dst.class == LocalPane
            begin
               if op == 'copy'
                  command = "cp -r " + @op.escape(src.selected_files) + ' ' + @op.escape(dst.current_dir)
                  @op.show('Copying','',command)
                  #FileUtils.cp_r(src.selected_files,dst.current_dir,:verbose => true)
               elsif op == 'move'
                  command = "mv " + @op.escape(src.selected_files) + ' ' + @op.escape(dst.current_dir)
                  @op.show('Copying','',command)
                  #FileUtils.mv(src.selected_files,dst.current_dir,:verbose => true)
               end
            rescue Errno::EACCES => e
               Commander.instance.message('Permission denied')
            end
            if op == 'copy'
               src.unselect_all
            elsif op == 'move'
               src.refresh_but_current_disappeared
            end
            dst.refresh
         elsif dst.class == MPlayerPane and op == 'copy'
            count = MplayerSingleton.instance.add_to_playlist(src.selected_files)
            message('Adding ' + count.to_s + ' files to playlist')
            src.unselect_all
         elsif dst.class == BookmarkPane
         else
            message('Unsupported '+op+' Destination')
         end
      else
         message('Unsupported '+op+' Source')
      end
   end

   def navigate(key,dir,file)
      cp = current_pane
      if cp == @left and key == 'right'
         set_pane(:Right, true, LocalPane,dir)
         @right.focus_item(file)
      elsif cp == @right and key == 'left'
         set_pane(:Left, true, LocalPane,dir)
         @left.focus_item(file)
      end
   end

   def message(x)
      @statusbar.push(@statusbar.get_context_id('global'),' ' + x)
      GLib::Timeout.add(2000) do
         @statusbar.push(@statusbar.get_context_id('global'),'')
         false
      end
   end

   def on_key_release(a,b)
   end

   def current_pane
      if @wm.focus == @left.focus_widget
         return @left
      elsif @wm.focus == @right.focus_widget
         return @right
      else
         raise 'Unknown focus: ' + @wm.focus.inspect
      end
   end

   def get_side
      if @wm.focus == @left.focus_widget
         return :Left
      elsif @wm.focus == @right.focus_widget
         return :Right
      else
         raise 'Unknown focus: ' + @wm.focus.inspect
      end
   end

   def set_other_pane(type,param = nil)
      if get_side == :Left
         if param.nil?
            set_pane(:Right, true, type)
         else
            set_pane(:Right, true, type,param)
         end
      else
         if param.nil?
            set_pane(:Left, true, type)
         else
            set_pane(:Left, true, type,param)
         end
      end
   end

   def set_current_pane(type,param = nil)
      if param.nil?
         set_pane(get_side, true, type)
      else
         set_pane(get_side, true, type,param)
      end
   end

   def set_pane(left_or_right,focus,type,param = nil)
      if left_or_right == :Left
         pane = @left
         label = @label_left
         image = @image_left
         vbox = @vbox_left
      elsif left_or_right == :Right
         pane = @right
         label = @label_right
         image = @image_right
         vbox = @vbox_right
      end

      unless pane.nil?
         @prevent_gc_array.push(pane.container_widget)
         pane.unregister
         vbox.remove(pane.container_widget)
      end

      if param.nil?
         pane = type.new()
      else
         pane = type.new(param)
      end

      pane.set_env(label,image)
      vbox.add(pane.container_widget)

      if focus
         pane.focus_widget.grab_focus
      end

      if left_or_right == :Left
         @left = pane
      elsif left_or_right == :Right
         @right = pane
      end
   end
end

class App
   def run
      Thread.abort_on_exception = true
      Commander.instance
      Scheduler.instance.another_main_loop
      Gtk.main
      exit
   end
end
