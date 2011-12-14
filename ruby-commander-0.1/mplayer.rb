#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'

module MPlayerConst
   PL_NAME = 0
   PL_URL = 1
   PL_ICON = 2

   ExtPlaylist = ['.m3u']
   ExtPlayable = ['.mp3','.wma','.ogg','.avi','.mkv']
end

class MPlayerPane
   include MPlayerConst
   attr_reader :container_widget
   attr_reader :focus_widget

   def initialize
      glade = GladeXML.new(Config::GladeDir+'mplayer.glade','vbox2') {|handler| method(handler)}
      @container_widget = glade['vbox2']

      @tv_playlist = glade['treeview_playlist']
      @focus_widget = @tv_playlist

      renderer = Gtk::CellRendererPixbuf.new
      col = Gtk::TreeViewColumn.new('st.', renderer, :stock_id => PL_ICON)
      @tv_playlist.append_column(col)

      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new('name', renderer, :text => PL_NAME)
      @tv_playlist.append_column(col)

      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new('url', renderer, :text => PL_URL)
      @tv_playlist.append_column(col)

      @tv_playlist.model = MplayerSingleton.instance.playlist
      @tv_playlist.selection.mode = Gtk::SELECTION_MULTIPLE

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
      glade.get_widget('hscale_progress').can_focus = false

      #register to singleton
      MplayerSingleton.instance.add_pane(self)
   end

   def set_env(cbe,image)
      @cbe = cbe
      @image = image
      @image.stock = 'gtk-media-play'
      @cbe.text = 'mplayer'
   end

   def source
      []
   end

   def destination(a)
      MplayerSingleton.instance.add_to_playlist(a)
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
      @playlist = Gtk::ListStore.new(String,String,String)

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
      add_to_playlist(ENV['HOME'] + '/.ruby-commander/current.m3u')
   end

   def add_pane(pane)
      @panes.push(pane)
      pane.set_mode(@mode,@current_name)
   end

   def remove_pane(pane)
      @panes.delete(pane)
   end
   
   def end_of_file
      p 'end_of_file'
      remove_timer
      nextone = @currently_playing.path.next!
      p 'nextone: ' + nextone.inspect
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
      puts 'stop'
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
      puts "play: #{path}"
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
      @pipes[@pipe_id] = IO.popen("mplayer -slave -quiet \"#{it[PL_URL]}\"", 'w+')
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
         puts 'buffer: ' + buffer

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
               puts "setting name" + @current_name.inspect
               set_mode(@mode)
            elsif key == "Exiting... (End of file)"
               p 'close'
               io.close
               keep_watching = false 
               end_of_file
            #elsif key.strip == "Failed, exiting."
               #p 'close'
               #io.close
               #keep_watching = false 
               #end_of_file
            elsif key == "Exiting... (Quit)"
               p 'close'
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
      puts "sending '#{x}'"
      begin
         @pipes[@pipe_id].puts x
      rescue Errno::EPIPE
         p 'epipe'
      rescue IOError
         p 'ioerror'
      end
   end

   def add_timer
      @timer = Scheduler.instance.add_seconds do
         get_property('time_pos')
      end
   end

   def remove_timer
      puts 'removing timer'
      Scheduler.instance.remove_seconds(@timer)
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
            ext = fn[-4..-1].downcase
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
      add.each do |name,url|
         iter = @playlist.append
         iter[PL_NAME] = name
         iter[PL_URL] = url
         iter[PL_ICON] = 'gtk-none'
      end
   end

   def recurse_dir(array,path)
      Dir.entries(path).sort.each do |fn|
         next if fn == '.'
         next if fn == '..'
         x = path+'/'+fn
         if File.stat(x).directory?
            recurse_dir(array,x)
         elsif File.stat(x).file?
            ext = fn[-4..-1].downcase
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
