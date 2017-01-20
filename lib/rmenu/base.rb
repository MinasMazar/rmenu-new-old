require "rmenu/dmenu_wrapper"
require "rmenu/monkey_patch"
require "rmenu/label_mangle"
require "rmenu/menu/built_in"
require "rmenu/menu/fallback"
require "yaml"

module RMenu
  class Base

    include LabelMangle
    include Menu::BuiltIn

    attr_accessor :conf
    attr_accessor :profiles
    attr_accessor :current_profile
    attr_accessor :root_menu
    attr_accessor :current_menu
    attr_accessor :last_menu

    def initialize(conf)
      @conf = conf
      @last_menu = []
      reset_profile!
    end

    def profiles
      if conf[:profiles]&.any?
        @profiles = conf[:profiles]
      else
        LOGGER.debug "No suitable profile found! Going fallback.."
        @profiles = { main: Menu::FALLBACK }
      end
    end

    def root_menu
      @root_menu || []
    end

    def current_menu
      @current_menu || []
    end

    def switch_profile!(profile = :main, options = {})
      profile = profile.to_sym
      if profiles[profile]
        if current_profile != profiles[profile]
          self.current_profile = profiles[profile]
          self.root_menu = ( options[:lock_menu] && root_menu ) || current_profile[:items]
          self.current_menu = ( options[:lock_menu] && current_menu ) || root_menu.any? && root_menu || current_menu
          LOGGER.debug "Profile activated [#{current_profile[:name]}]"
          self.current_profile[:name] ||= profile
        end
      else
        LOGGER.debug "Profile [#{profile}] not found.. going fallback to #{Menu::FALLBACK[:name]}"
        self.current_profile = Menu::FALLBACK
        self.current_menu = root_menu
      end
      current_profile
    end

    def reset_profile!
      switch_profile!
    end

    def start
      proc pick current_profile[:name] || "rmenu =>", current_menu
    end

    def pick(prompt, items, replace_labels = true, other_params = {})
      dmenu = dmenu_instance
      dmenu.set_params other_params
      dmenu.prompt = prompt
      items.map! { |i| i.to_item if i.respond_to? :to_item }.compact!
      items ||= []
      items.each { |i| i[:label] = replace_inline_blocks i[:label] }
      dmenu.items = process_labels items
      binding.pry if conf[:pry]
      dmenu.lines = items.size if conf[:auto_size]
      item = dmenu.get_item
      current_menu_item = items.find { |i| i[:key] == item[:key] }
      if current_menu_item
        LOGGER.debug "Picked item #{current_menu_item.inspect} form menu"
        item = current_menu_item
      else
        LOGGER.debug "Picked undef item #{item.inspect}"
      end
      yield item, self if block_given?
      item
    end

    def proc(item)
      raise ArgumentError.new "No valid item passed as argument (must be a Hash)" unless item.is_a? Hash

      self.keep_open = item[:keep_open]

      if item[:key].is_a? Symbol
        send item[:key]
      elsif item[:key].is_a? Proc
        catch_and_notify_exception do
          instance_eval(&item[:key])
        end
      elsif item[:key].is_a? Array
        last_menu << current_menu
        self.current_menu = item[:key]
        proc(pick(item[:label], current_menu, item))
        back if item[:goback]
      elsif item[:key].is_a?(String) && item[:key].strip != ""
        if md = item[:key].match(/^\s*:\s*(.+)/)
          string_eval md[1]
        else
          str = replace_tokens item[:key]
          str = replace_blocks str
          if md = str.match(/^\s*(http(s?):\/\/.+)/)
            open_url md[1]
          elsif md = str.match(/^\s*(!{1,2}|;)\s*(.+)$/)
            cmd = [ ]
            if md[1] == ";"
              cmd << conf[:terminal_exec] if md[1] == ";"
              cmd << "\"#{ md[2] }\""
            else
              cmd << md[2]
            end
            if md[1] == "!!"
              notify system_exec_and_get_output cmd
            elsif md[1] == "!" || md[1] == ";"
              system_exec cmd
            end
          elsif str != ""
            proc key: "!#{str}" if conf[:force_exec]
          end
        end
      end
    end

    def replace_tokens(cmd)
      return cmd if conf[:suppress_eval]
      replaced_cmd = cmd.to_s
      while md = replaced_cmd.match(/(\$\$(.+?)\$\$)/)
        break unless md[1] || md[2]
        input = pick_string(md[2])
        return "" if input == ""
        replaced_cmd = replaced_cmd.sub(md[0], input)
      end
      LOGGER.debug "Command interpolated with input tokens: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def replace_blocks(cmd)
      return cmd if conf[:suppress_eval]
      replaced_cmd = cmd.to_s
      while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
        break unless md[1] || md[2]
        evaluated_string = string_eval(md[2]).to_s # TODO: better to eval in a useful sandbox
        return if evaluated_string == nil
        replaced_cmd = replaced_cmd.sub(md[0], evaluated_string)
      end
      LOGGER.debug "Command interpolated with eval blocks: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def replace_inline_blocks(cmd)
      return cmd if conf[:suppress_eval]
      replaced_cmd = cmd.to_s
      while md = replaced_cmd.match(/(@@(.+?)@@)/)
        break unless md[1] || md[2]
        evaluated_string = string_eval(md[2]).to_s # TODO: better to eval in a useful sandbox
        return if evaluated_string == nil
        replaced_cmd = replaced_cmd.sub(md[0], evaluated_string)
      end
      LOGGER.debug "Command interpolated with inline eval blocks: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def pick_string(prompt, items = [], other_params = {})
      replace_inline_blocks pick(prompt, items, other_params)[:key].to_s
    end

    def notify(msg)
      pick msg, [], false
      #DMenuWrapper.new(conf)
      #dmenu_inst.prompt = msg
      #dmenu_inst.items = []
      #dmenu_inst.get_item
    end

    def back
      self.current_menu = last_menu.pop || root_menu
    end

    def pick_item_interactive(prompt, menu = current_menu, deeply)
      item = pick prompt, menu, selected_background: "#FF2244"
      item, menu = pick_item_interactive prompt, item[:key], deeply if deeply && item[:key].is_a?(Array)
      [ item, menu ]
    end

    def mod_item_interactive! item
      label = pick_string("label", [ item[:label] ], false)
      key = pick_string("exec", [ item[:key] ], false)
      other_params = string_eval pick_string("other params (EVAL)", [], false)
      other_params = {} unless other_params.is_a? Hash
      if key == "[]" || key == []
        item = create_submenu label
      end
      item[:label], item[:key] = label.strip, key.strip
      item.merge! other_params if other_params.is_a? Hash
      item
    end

    def add_item(menu = current_menu)
      item = mod_item_interactive! label: "", key: ""
      return nil if item[:key] == "" && item[:label] == ""
      menu << item
      LOGGER.info "Item #{item.inspect} added to menu #{menu}"
      item
    end

    def del_item(menu = current_menu, deeply = true)
      switch_profile! :delete_item, lock_items: true
      item, menu = pick_item_interactive "del item", menu, deeply
      if menu.include? item
        menu.delete item
        LOGGER.info "Item #{item.inspect} removed from menu #{menu}"
        switch_profile!
        item
      end
    end

    def mod_item(menu = current_menu, deeply = true)
      switch_profile! :delete_item, lock_items: true
      item, menu = pick_item_interactive "mod item", menu, deeply
      if menu.include? item
        mod_item_interactive! item
        LOGGER.info "Item updated #{item.inspect}"
        item
      end
    end

    alias :add :add_item
    alias :mod :mod_item
    alias :del :del_item

    def mod_conf(key = nil)
      if key && key.is_a?(Symbol)
        conf[key] = string_eval(pick_string "edit conf[#{key}]", [ { label: conf[key], key: conf[key] } ])
      else
        pick "mod conf", conf.keys.map { |c| { label: c.to_s, key: c } } do |item|
          break if item[:key].to_s.strip.empty?
          mod_conf item[:key].to_s.sub(/^:/,'').to_sym
        end
      end
    end

    def save_conf
      File.write conf[:conf_file], YAML.dump(conf)
      LOGGER.info "Confuration saved to #{conf[:conf_file]}"
    end

    def load_conf(conf_file = conf[:conf_file])
      self.conf = YAML.load_file conf_file
      reset_profile!
      LOGGER.info "Confuration loaded from #{conf[:conf_file]}"
    end

    def open_url(url)
      system_exec conf[:web_browser], url
    end

    def edit_file(file)
      system_exec conf[:text_editor], file
    end

    def string_eval(str)
      LOGGER.debug "Evaluating string [#{str}]"
      catch_and_notify_exception { instance_eval str }
    end

    def suppress_eval
      conf[:suppress_eval] = true
      if block_given?
        yield
        conf[:suppress_eval] = false
      end
    end

    def system_exec(*cmd)
      cmd << "&"
      cmd = cmd.join " "
      LOGGER.debug "RMenu.system_exec: [#{cmd}]"
      catch_and_notify_exception do
        system cmd
      end
    end

    def system_exec_and_get_output(*cmd)
      cmd << "&"
      cmd = cmd.join " "
      LOGGER.debug "RMenu.system_exec: #{cmd}"
      catch_and_notify_exception do
        `#{cmd}`
      end
    end

    def catch_and_notify_exception(msg = nil)
      begin
        yield
      rescue StandardError => e
        LOGGER.debug "Exception catched[#{msg || e.message}] #{e.inspect} at #{e.backtrace.join("\n")}"
        suppress_eval { notify "Exception catched: #{msg || e.message}" }
      rescue SyntaxError => se
        LOGGER.debug "Exception catched[#{msg || se.message}] #{se.inspect} at #{se.backtrace.join("\n")}"
        suppress_eval { notify "Exception catched: #{msg || se.message}" }
      end
    end

    def dmenu_instance
      DMenuWrapper.new current_profile
    end

  end
end
