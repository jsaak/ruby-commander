#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'
require 'base-pane'

module MPlayerConst
   PL_NAME = 0
   PL_URL = 1
   PL_ICON = 2
   PL_SELECTED = 3

   ExtPlaylist = ['m3u']
   ExtPlayable = ['mp3','wma','ogg','avi','mkv']
end

class MPlayerPane
   include MPlayerConst
   include Selectable
   attr_reader :container_widget
   attr_reader :focus_widget

   def initialize()
      glade = GladeXML.new(Config::ShareDir+'mplayer.glade','vbox2') {|handler| method(handler)}
      @container_widget = glade['vbox2']

      @tv_playlist = glade['treeview_playlist']
      @focus_widget = @tv_playlist

      renderer = Gtk::CellRendererPixbuf.new
      col = Gtk::TreeViewColumn.new('st.', renderer, :stock_id => PL_ICON)
      @tv_playlist.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'name'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',PL_NAME)
      col.add_attribute(r_text,'foreground_gdk',PL_SELECTED)
      @tv_playlist.append_column(col)

      r_text = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new
      col.title = 'url'
      col.pack_start(r_text,true)
      col.add_attribute(r_text,'text',PL_URL)
      col.add_attribute(r_text,'foreground_gdk',PL_SELECTED)
      @tv_playlist.append_column(col)

      @tv_playlist.model = MplayerSingleton.instance.playlist
      init_selectable(MplayerSingleton.instance.playlist, PL_SELECTED, @tv_playlist)

      @hp = glade['hscale_progress']
      @label_mode = glade['label_mode']
      @label_info = glade['label_info']
      @label_info.ellipsize = Pango::Layout::ELLIPSIZE_END
      @label_info.can_focus = false
      @label_time = glade['label_time']

      @hp.update_policy = Gtk::UPDATE_DISCONTINUOUS
      @manual_seek = false
      @ignorechange = false

      @name = ''

      # remove can-focus
      glade.get_widget('button1').can_focus = false
      glade.get_widget('button2').can_focus = false
      glade.get_widget('button3').can_focus = false
      glade.get_widget('button4').can_focus = false
      glade.get_widget('button5').can_focus = false
      glade.get_widget('button6').can_focus = false
      glade.get_widget('button7').can_focus = false
      glade.get_widget('hscale_progress').can_focus = false

      @tv_playlist.signal_connect('key-press-event') do |tv,b|
         #p "press: #{b.keyval}, Gdk::Keyval::GDK_#{Gdk::Keyval.to_name(b.keyval)}"
         event_handled = false
         case b.keyval
         when Gdk::Keyval::GDK_Left
            if b.state & Gdk::Window::CONTROL_MASK > 0
               navigate('left')
            else
               MplayerSingleton.instance.jump(-60)
            end
            event_handled = true
         when Gdk::Keyval::GDK_Right
            if b.state & Gdk::Window::CONTROL_MASK > 0
               navigate('right')
            else
               MplayerSingleton.instance.jump(60)
            end
            event_handled = true
         when Gdk::Keyval::GDK_space
            on_pause
            event_handled = true
         end
         event_handled
      end

      #register to singleton
      MplayerSingleton.instance.add_pane(self)
   end

   def navigate(direction)
      unless current_url =~ /:\/\//
         x = current_url.split('/')
         dir = x[0..-2].join('/')
         file = x[-1]
         Commander.instance.navigate(direction,dir,file)
      else
         Commander.instance.message('Can not navigate to ' + current_url)
      end
   end

   def current_url
      MplayerSingleton.instance.get_url(@tv_playlist.cursor[0])
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.stock = 'gtk-media-play'
      @cbe.text = 'mplayer'
   end

   def set_mode(mode,name)
      if mode == :stopped
         @label_mode.label = 'Stopped'
         @label_info.label = ''
      elsif mode == :paused
         @label_mode.label = 'Paused: '
         @label_info.label = name
      elsif mode == :playing
         @label_mode.label = 'Playing: '
         @label_info.label = name
      else
         @label_mode.label = '???'
         #if @type == :stream
            #@label_info.label = 'Streaming: ' + @name
         #else
         #end
      end
   end

   def update_time_label(pos)
      if @length.nil?
         @label_time.label = time_string(pos)
      else
         @label_time.label = time_string(pos) + ' of ' + time_string(@length)
      end
   end

   def set_pos(pos,length)
      unless @manual_seek
         @length = length
         update_time_label(pos)

         @ignorechange = true
         unless length.nil?
            @hp.set_increments(5,10)
            unless length == 0
               @hp.set_range(0,length)
            end
            @hp.value = pos
         end
         @ignorechange = false
      end
   end

   def set_info
   end

   def on_quit
      MplayerSingleton.instance.quit
   end

   def on_play
      MplayerSingleton.instance.play(@tv_playlist.cursor[0])
   end

   def on_stop
      MplayerSingleton.instance.stop
   end

   def on_pause
      MplayerSingleton.instance.pause
   end

   def on_clear
      MplayerSingleton.instance.clear
   end

   def on_info
      Commander.instance.message('not implemented yet...')
   end

   def on_save_as
      Commander.instance.message('not implemented yet...')
   end

   def on_shuffle
      Commander.instance.message('not implemented yet...')
   end

   def on_playlist_row_activated
      on_play
   end

   def on_changed
      unless @ignorechange
         MplayerSingleton.instance.seek(@hp.value)
         @manual_seek = false
      end
   end

   def on_seek(a,b,c)
      #if @status.mode == :playing
         @manual_seek = true
         update_time_label(c)
      #end
      false
   end

   def unregister
      #unregister from singleton
      MplayerSingleton.instance.remove_pane(self)
   end

   def time_string(x)
      x = x.to_i
      str = (x/3600).to_s
      str += ':'
      str += '%02d' % ((x%3600)/60)
      str += ':'
      str += '%02d' % ((x%3600)%60)
   end
end

class MplayerSingleton
   include Singleton
   include MPlayerConst

   attr_reader :playlist

   def initialize()
      #name,url,playing
      @playlist = Gtk::ListStore.new(String,String,String,Gdk::Color)

      playlist = ['http://deepmix.eu/selected/www.deepmix.ru%20-%20Cotton_Izhevski_Pampero_200608.mp3',
                  '/home/jsaak/zene/tilt/Tilt - Children.mp3',
                  'http://yp.tilos.hu/tilos_high.ogg',
                  'http://ilyenaztannemlesz.ogg',
                  '/home/jsaak/film/mannerpension.avi',
                  "/home/jsaak/zene/vhk - a semmi kapuin dörömbölve/vhk - 06 - i'm dreaming.mp3"]
      #playlist.each do |ww|
         #iter = @playlist.append
         #iter[0] = ww.split('/')[-1]
         #iter[1] = ww
         #iter[2] = 'gtk-none'
      #end
      @currently_playing = nil
      @mode = :stopped

      @panes = Array.new

      @pipes = Array.new
      @pipe_id = 1

      #TODO duplicated
      fn = ENV['HOME'] + '/.ruby-commander/current.m3u'
      if File.exists?(fn)
         add_to_playlist(ENV['HOME'] + '/.ruby-commander/current.m3u')
      end
   end

   def add_pane(pane)
      @panes.push(pane)
      pane.set_mode(@mode,@current_name)
   end

   def remove_pane(pane)
      @panes.delete(pane)
   end
   
   def end_of_file
      #p 'end_of_file'
      remove_timer
      nextone = @currently_playing.path.next!
      #p 'nextone: ' + nextone.inspect
      @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-none'
      @currently_playing = nil
      if @playlist.get_iter(nextone).nil?
         stop
      else
         play(nextone)
      end
   end

   def pause
      unless @currently_playing.nil?
         send_command('pause')
         if @mode == :paused
            @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-media-play'
            add_timer
            set_mode(:playing)
         else
            @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-media-pause'
            remove_timer
            set_mode(:paused)
         end
      end
   end

   def set_mode(x)
      @mode = x
      @panes.each do |p|
         p.set_mode(x,@current_name)
      end
   end

   def stop
      #puts 'stop'
      set_mode(:stopped)
      @panes.each do |pa|
         pa.set_pos(0,0)
      end
      unless @currently_playing.nil?
         remove_timer
         send_command('quit')
         @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-none'
         @currently_playing = nil
      end
   end

   def play(path)
      #puts "play: #{path}"
      if path.nil?
         it = @playlist.iter_first
         if it.nil?
            return
         end
         path = it.path
      else
         it = @playlist.get_iter(path)
      end

      unless @currently_playing.nil?
         stop
      end

      @current_name = it[PL_NAME]
      set_mode(:playing)
      add_timer
      @currently_playing = Gtk::TreeRowReference.new(@playlist,path)
      it[PL_ICON] = 'gtk-media-play'

      @pipe_id = 3 - @pipe_id
      @pipes[@pipe_id] = IO.popen("mplayer -slave -quiet \"#{it[PL_URL]}\" 2>/dev/null", 'w+')
      get_property('length')

      if it[PL_URL] =~ /^http:/
         @length = nil
      end

      Scheduler.instance.add_io(@pipes[@pipe_id]) do |io|
         keep_watching = true 
         buffer = ''
         begin
            buffer += io.read_nonblock(40960)
         rescue Errno::EAGAIN
            puts 'eagain'
         rescue EOFError
            puts 'eof'
            #Scheduler.instance.remove_io(@pipe)
            keep_watching = false 
         end
         # puts 'buffer: ' + buffer.inspect
         #puts 'buffer: ' + buffer

         buffer.each_line do |line|
            key,val = line.split(/=/)
            key.strip!
            if key == 'ANS_time_pos'
               @panes.each do |p|
                  p.set_pos(val.to_f.round,@length)
               end
            elsif key == 'ANS_length'
               @length = val.to_f.round
            elsif key == 'ICY Info: StreamTitle'
               @current_name = val.split("'")[1]
               #puts "setting name " + @current_name.inspect
               set_mode(@mode)
            elsif key == "Exiting... (End of file)"
               #p 'close'
               io.close
               keep_watching = false 
               end_of_file
            #elsif key.strip == "Failed, exiting."
               #p 'close'
               #io.close
               #keep_watching = false 
               #end_of_file
            elsif key == "Exiting... (Quit)"
               #p 'close'
               io.close
               keep_watching = false 
            end
         end
         keep_watching
      end
   end

   def get_property(x)
      send_command("get_property #{x}")
   end

   def send_command(x)
      #puts "sending '#{x}'"
      begin
         @pipes[@pipe_id].puts x
      rescue Errno::EPIPE
         #p 'epipe'
      rescue IOError
         #p 'ioerror'
      end
   end

   def add_timer
      @timer = Scheduler.instance.add_seconds do
         get_property('time_pos')
      end
   end

   def remove_timer
      Scheduler.instance.remove_seconds(@timer)
   end

   def jump(offset)
      unless @currently_playing.nil?
         send_command("seek #{offset}")
         if @mode == :paused
            @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-media-play'
            add_timer
            set_mode(:playing)
         end
      end
   end

   def seek(x)
      unless @currently_playing.nil?
         send_command("set_property time_pos #{x}")
         if @mode == :paused
            @playlist.get_iter(@currently_playing.path)[PL_ICON] = 'gtk-media-play'
            add_timer
            set_mode(:playing)
         end
      end
   end

   def quit
      if @mode == :playing or @mode == :paused
         stop
      end

      f = File.new(Commander.instance.config_dir+'/current.m3u','w')
      f.puts'#EXTM3U'
      @playlist.each do |ls,tp,iter|
         f.puts"#EXTINF:1,#{iter[PL_NAME]}"
         f.puts iter[PL_URL]
      end
      f.close
   end

   def add_to_playlist(a)
      add = Array.new
      a.each do |fn|
         if File.stat(fn).directory?
            filenames = Array.new
            recurse_dir(filenames,fn)
            filenames.each do |url|
               add.push([url.split('/')[-1],url])
            end
         elsif File.stat(fn).file?
            ext = fn.split('.')[-1].downcase
            if ExtPlaylist.include?(ext)
               name = ''
               File.new(fn).each_line do |l|
                  if l[0..0] == '#'
                     if l =~ /#EXTINF:/
                        name = l.split(',')[1]
                        name.strip!
                     end
                  else
                     add.push([name,l.strip])
                     name = ''
                  end
               end
            elsif ExtPlayable.include?(ext)
               add.push([fn.split('/')[-1],fn])
            else
               puts 'cannot handle: ' + fn
            end
         end
      end
      counter = 0
      add.each do |name,url|
         counter += 1
         iter = @playlist.append
         iter[PL_NAME] = name
         iter[PL_URL] = url
         iter[PL_ICON] = 'gtk-none'
         iter[PL_SELECTED] = Global.instance.colors['default']
      end
      return counter
   end

   def get_url(path)
      @playlist.get_iter(path)[PL_URL]
   end

   def recurse_dir(array,path)
      Dir.entries(path).sort.each do |fn|
         next if fn == '.'
         next if fn == '..'
         x = path+'/'+fn
         if File.stat(x).directory?
            recurse_dir(array,x)
         elsif File.stat(x).file?
            ext = fn.split('.')[-1].downcase
            if ExtPlayable.include?(ext)
               array.push(x)
            end
         end
      end
   end

   def clear
      stop
      @playlist.clear
   end
end
