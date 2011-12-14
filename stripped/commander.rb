#!/usr/bin/ruby

require 'libglade2'
require 'glib2'
require 'singleton'

class LocalPane
   attr_reader :container_widget

   def initialize(a=nil)
      #vbox = Gtk::VBox.new(1)
      #label = Gtk::Label.new('adf')
      #vbox.add label
      #@container_widget = vbox
      
      # glade = GladeXML.new(Config::GladeDir+'local.glade','vbox3') {|handler| method(handler)}
      glade = GladeXML.new(Config::GladeDir+'local.glade','vbox3')
      @container_widget = glade['vbox3']
   end
end

class Commander
   include Singleton
   attr_reader :config_dir

   def initialize
      glade = GladeXML.new(Config::GladeDir+'gui.glade','window_main') {|handler| method(handler)}
      #@select_window = SelectWindow.new(glade)
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
      @left = LocalPane.new(ENV['PWD'])
      @vbox_left.add(@left.container_widget)

      # playlist
      @right = LocalPane.new(ENV['PWD'])
      @vbox_right.add(@right.container_widget)

      glade.get_widget("button_left").can_focus = false
      glade.get_widget("button_right").can_focus = false
      @hp.can_focus = false
      #@hp.pack1(@left.container_widget,true,false)
      #@hp.pack2(@right.container_widget,true,false)
      @wm.show

      #TODO duplicated
      @config_dir = ENV['HOME'] + '/.ruby-commander'
      unless File.exists?(@config_dir)
         Dir.mkdir(@config_dir)
      end

      #@hp.signal_connect('notify') do |hp, param|
         #puts param.inspect + ' ' + param.class.to_s
         #if param.class == GLib::Param::Int
            #p param.to_i
         #end
      #end

      @prevent_gc_array = []
   end

   def on_quit
      @left.on_quit
      @right.on_quit
      Gtk.main_quit
   end

   def on_button_left_clicked
   end

   def on_button_right_clicked
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
      case b.keyval
      when Gdk::Keyval::GDK_F1
         set_pane(:Left,LocalPane)
         #@vbox_left.remove(@left.container_widget)

         #@left = LocalPane.new

         #@vbox_left.add(@left.container_widget)
         p 'gc.start'
         GC.start
         return true
      end
      return false
   end

   def on_key_release(a,b)
   end


   def set_pane(left_or_right,type,param = nil)
      if left_or_right == :Left
         #@prevent_gc_array.push(@left.container_widget)
         @vbox_left.remove(@left.container_widget)

         if param.nil?
            @left = type.new
         else
            @left = type.new(param)
         end

         @vbox_left.add(@left.container_widget)
      elsif left_or_right == :Right
         #@prevent_gc_array.push(@right.container_widget)
         @vbox_right.remove(@right.container_widget)

         if param.nil?
            @right = type.new
         else
            @right = type.new(param)
         end
         @vbox_right.add(@right.container_widget)
      end
   end

end

class App
   def run
      Thread.abort_on_exception = true
      Commander.instance
      Gtk.main
      exit
   end
end
