#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'

require Config::LibDir+'mplayer'
require Config::LibDir+'local'
require Config::LibDir+'bookmark'

class Scheduler
   include Singleton

   def initialize
      @ios = Hash.new
      @sec = Hash.new
      @sec_id = 0
   end

   def add_seconds(&block)
      @sec_id += 1
      @sec[@sec_id] = block
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
         while true
            a = @ios.keys
            ret = select(a,[],a,1)
            if ret.nil?
               @sec.each do |k,v|
                  v.call
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
                  puts 'removing ' + x.to_s
                  @ios.delete(x)
               end
                  
               e.each do |x|
                  puts 'error: ' + x.to_s
                  raise
               end
            end
         end
      end
      return t
   end
end

class Commander
   include Singleton
   attr_reader :config_dir

   def initialize
      glade = GladeXML.new(Config::GladeDir+'gui.glade','window_main') {|handler| method(handler)}
      @wm = glade.get_widget("window_main")
      @hp = glade.get_widget("hpaned1")
      @vbox_left = glade.get_widget("vbox_left")
      @vbox_right = glade.get_widget("vbox_right")
      @image_left = glade.get_widget("image_left")
      @image_right = glade.get_widget("image_right")
      @label_left = glade.get_widget("label_left")
      @label_right = glade.get_widget("label_right")
      @label_left.can_focus = false
      @label_right.can_focus = false

      # directory view
      #@left = LocalPane.new('/media/KINGSTON/')
      #@left = LocalPane.new('/home/jsaak/zene/_radio/')
      @left = LocalPane.new('/')
      @left.set_env(@label_left,@image_left)
      @vbox_left.add(@left.container_widget)

      # playlist
      @right = MPlayerPane.new
      @right.set_env(@label_right,@image_right)
      @vbox_right.add(@right.container_widget)

      glade.get_widget("button_left").can_focus = false
      glade.get_widget("button_right").can_focus = false
      #@hp.pack1(@left.container_widget,true,false)
      #@hp.pack2(@right.container_widget,true,false)
      @wm.show

      #TODO duplicated
      @config_dir = ENV['HOME'] + '/.ruby-commander'
      unless File.exists?(@config_dir)
         Dir.mkdir(@config_dir)
      end
   end

   def on_quit
      @left.on_quit
      @right.on_quit
      Gtk.main_quit
   end

   def on_button_left_clicked
      set_pane(:Left,BookmarkPane)
   end

   def on_button_right_clicked
      set_pane(:Right,BookmarkPane)
   end

   #TODO
   def on_hpaned1_button_press_event(hpaned,e)
      if e.event_type == Gdk::Event::BUTTON2_PRESS
         puts "on_hpaned1_button_press_event(#{hpaned},#{e})"
         hpaned.cancel_position
         hpaned.position = hpaned.allocation.width/2
      end
   end

   def on_hpaned1_accept_position
      p 'accept'
   end

   def on_hpaned1_cancel_position
      p 'cancel'
      false
   end

   def on_key_press(a,b)
   end

   def on_key_release(a,b)
      if b.keyval == Gdk::Keyval::GDK_F5
         if get_side() == :Left
            @right.destination(@left.source)
         end
      elsif b.keyval == Gdk::Keyval::GDK_F1
         set_pane(:Left,BookmarkPane)
      elsif b.keyval == Gdk::Keyval::GDK_F2
         set_pane(:Right,BookmarkPane)
      elsif b.keyval == Gdk::Keyval::GDK_F3
         if get_side() == :Left
            x = @left.source
         else
            x = @right.source
         end
         pid = fork do 
            exec "gvim '#{x}'"
         end
         Process.detach(pid)
      elsif b.keyval == Gdk::Keyval::GDK_F10
         on_quit
      end
      #p "#{b.keyval}, Gdk::Keyval::GDK_#{Gdk::Keyval.to_name(b.keyval)}"
   end

   def get_side
      if @wm.focus == @left.focus_widget
         return :Left
      elsif @wm.focus == @right.focus_widget
         return :Right
      else
         return :DONTKNOW
      end
   end

   def set_other_pane(type,param = nil)
      if get_side == :Left
         if param.nil?
            set_pane(:Right,type)
         else
            set_pane(:Right,type,param)
         end
      else
         if param.nil?
            set_pane(:Left,type)
         else
            set_pane(:Left,type,param)
         end
      end
   end

   def set_current_pane(type,param = nil)
      if param.nil?
         set_pane(get_side,type)
      else
         set_pane(get_side,type,param)
      end
   end

   def set_pane(left_or_right,type,param = nil)
      if left_or_right == :Left
         @left.unregister
         @vbox_left.remove(@left.container_widget)

         if param.nil?
            @left = type.new
         else
            @left = type.new(param)
         end

         @left.set_env(@label_left,@image_left)
         @vbox_left.add(@left.container_widget)
         @left.focus_widget.grab_focus
      elsif left_or_right == :Right
         @right.unregister
         @vbox_right.remove(@right.container_widget)

         if param.nil?
            @right = type.new
         else
            @right = type.new(param)
         end
         @right.set_env(@label_right,@image_right)
         @vbox_right.add(@right.container_widget)
         @right.focus_widget.grab_focus
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
