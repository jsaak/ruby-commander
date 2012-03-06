module Selectable
   def init_selectable(liststore, selected_index, treeview)
      @ls = liststore
      @tv = treeview
      @selected_index = selected_index
      @color_fg_default = Global.instance.colors['default']
      @color_fg_selected = Global.instance.colors['selected']
      treeview.selection.mode = Gtk::SELECTION_SINGLE

      @tv.signal_connect('focus-out-event') do
         @tv.selection.unselect_all
      end

      @tv.signal_connect('focus-in-event') do
         path = @tv.cursor[0]
         if path.nil?
            focus_first
         else
            @tv.set_cursor(@tv.cursor[0],nil,false)
         end
      end
   end

   def focus_first
      @tv.model.each do |store, path, iter|
         @tv.set_cursor(path,nil,false)
         return
      end
   end

   def focus_path(path)
      unless path.nil?
         @tv.set_cursor(path,nil,false)
      end
   end

   def toggle_select(iter)
      if iter[@selected_index] == @color_fg_default
         iter[@selected_index] = @color_fg_selected
      else
         iter[@selected_index] = @color_fg_default
      end
   end

   def select(iter)
      iter[@selected_index] = @color_fg_selected
   end

   def select_all
      @ls.each do |t,p,iter|
         iter[@selected_index] = @color_fg_selected
      end
   end

   def unselect_all
      @ls.each do |t,p,iter|
         iter[@selected_index] = @color_fg_default
      end
   end

   def selected_iters
      counter = 0
      @ls.each do |t,p,iter|
         if iter[@selected_index] == @color_fg_selected
            yield(iter)
            counter += 1
         end
      end
      if counter == 0
         iter = @ls.get_iter(@tv.cursor[0])
         unless iter.nil?
            yield(iter)
         end
      end
   end

   def pressed_kp_plus
      select_all
      true
   end

   def pressed_kp_minus
      unselect_all
      true
   end

   def pressed_insert
      path = @tv.cursor[0]
      iter = @ls.get_iter(path)
      toggle_select(iter)
      if iter.next!
         path.next!
         @tv.set_cursor(path,nil,false)
      end
      true
   end

   def pressed_f3
   end

   def pressed_f4
   end

   def pressed_shift_f6
   end

   def pressed_f7
   end

   def pressed_f8
   end

   def pressed_del
   end
end
