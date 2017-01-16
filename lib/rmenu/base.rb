require "rmenu/dmenu_wrapper"
require "rmenu/monkey_patch"
require "rmenu/menu/built_in"
require "rmenu/menu/fallback"
require "yaml"

module RMenu
  class Base

    attr_accessor :conf
    attr_accessor :profiles
    attr_accessor :current_profile
    attr_accessor :current_menu
    attr_accessor :last_menu

    def initialize(conf)
      @conf = conf
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
      current_profile[:items]
    end

    def switch_profile!(profile = :main)
      if profiles[profile]
        self.current_profile = profiles[profile]
        self.current_profile[:name] ||= profile
      else
        LOGGER.debug "Profile [#{profile}] not found.. going fallback to #{Menu::FALLBACK[:name]}"
        self.current_profile = Menu::FALLBACK
      end
      self.current_menu = root_menu
      LOGGER.debug "Profile activated [#{current_profile[:name]}]"
      current_profile
    end

    def reset_profile!
      switch_profile!
    end

    def start
      proc pick "rmenu => ", current_menu
    end

    def pick(prompt, items, other_params = {})
      dmenu = dmenu_instance
      dmenu.set_params other_params
      dmenu.prompt = prompt
      items.map! do |i|
        i.to_item if i.respond_to? :to_item
      end.each do |i|
        i[:label] = replace_inline_blocks i[:label]
      end.compact!
      items && items.map! do |i|
        i.merge label: ( i[:marked] == true ? "*#{i[:label]}*" : i[:label] )
      end.sort_by! do |i|
        i[:order] || 50
      end
      dmenu.items = items
      item = dmenu.get_item
      LOGGER.debug "Picked item #{item.inspect}"
      yield item, self if block_given?
      item
    end

    def proc(item)
      raise ArgumentError.new "No valid item passed as argument (must be a Hash)" unless item.is_a? Hash
      if item[:key].is_a? Symbol
        send item[:key]
      elsif item[:key].is_a? Proc
        catch_and_notify_exception do
          instance_eval(&item[:key])
        end
      elsif item[:key].is_a? Array
        self.last_menu = current_menu
        self.current_menu = item[:key]
        proc(pick(item[:label], current_menu, item))
        self.current_menu = last_menu if item[:goback]
      elsif item[:key].is_a?(String) && item[:key].strip != ""
        if md = item[:key].match(/^:\s*(.+)/)
          string_eval md[1]
        else
          str = replace_tokens item[:key]
          str = replace_blocks str
          if md = str.match(/^\s*(http(s?):\/\/.+)/)
            open_url md[1]
          elsif md = str.match(/\s*!(.+)/)
            term_exec = str.match(/;\s*$/)
            cmd = [ ]
            cmd << conf[:terminal_exec] if term_exec
            cmd << md[1]
            system_exec cmd
          elsif str != ""
            proc key: "!#{str}" if conf[:force_exec]
          end
        end
      end
    end

    def replace_tokens(cmd)
      replaced_cmd = cmd
      while md = replaced_cmd.match(/(__(.+?)__)/)
        break unless md[1] || md[2]
        input = pick_string(md[2])
        return "" if input == ""
        replaced_cmd = replaced_cmd.sub(md[0], input)
      end
      LOGGER.debug "Command interpolated with input tokens: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def replace_blocks(cmd)
      replaced_cmd = cmd
      catch_and_notify_exception do
        while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
          break unless md[1] || md[2]
          evaluated_string = self.instance_eval(md[2]).to_s # TODO: better to eval in a useful sandbox
          return if evaluated_string == nil
          replaced_cmd = replaced_cmd.sub(md[0], evaluated_string)
        end
        replaced_cmd
      end
      LOGGER.debug "Command interpolated with eval blocks: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def replace_inline_blocks(cmd)
      replaced_cmd = cmd
      catch_and_notify_exception do
        while md = replaced_cmd.match(/(\{\{([^\{\}]+?)\}\})/)
          break unless md[1] || md[2]
          evaluated_string = self.instance_eval(md[2]).to_s # TODO: better to eval in a useful sandbox
          return if evaluated_string == nil
          replaced_cmd = replaced_cmd.sub(md[0], evaluated_string)
        end
        replaced_cmd
      end
      LOGGER.debug "Command interpolated with inline eval blocks: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def pick_string(prompt, items = [], other_params = {})
      replace_inline_blocks pick(prompt, items, other_params)[:key].to_s
    end

    def notify(msg)
      pick msg, []
    end

    def pick_item_interactive(prompt, menu = current_menu, deeply)
      item = pick prompt, menu, selected_background: "#FF2244"
      item, menu = pick_item_interactive prompt, item[:key], deeply if deeply && item[:key].is_a?(Array)
      [ item, menu ]
    end

    def create_item_interactive
      populate_item = {label: "Populate!", key: Proc.new { add_item nil, current_menu }, order: 1, implode: true }
      fix_item = {label: "Fix!", key: Proc.new { current_menu.reject! { |i| i[:implode] } }, order: 1, implode: true }
      separator = Menu::BuiltIn::SEPARATOR.merge implode: true
      label, key = pick_string("label"), pick_string("exec")
      if key == "[]" || key == []
        key = [ populate_item, fix_item, separator ]
      end
      other_params = string_eval pick_string("other params (EVAL)")
      item = { label: label, key: key , user_defined: true, order: 50 }
      item.merge other_params if other_params.is_a? Hash
      item
    end

    def add_item(item, menu = current_menu)
      item = item.to_item if item.is_a? String
      item ||= create_item_interactive
      return nil if item[:key] == "" && item[:label] == ""
      menu << item
      LOGGER.info "Item #{item.inspect} added to menu #{menu}"
      item
    end

    def del_item(menu = current_menu, deeply = true)
      item, menu = pick_item_interactive "del item", menu, deeply
      if menu.include? item
        menu.delete item
        LOGGER.info "Item #{item.inspect} removed from menu #{menu}"
        item
      end
    end

    def mod_item(menu = current_menu, deeply = true)
      item, menu = pick_item_interactive "mod item", menu, deeply
      return if item[:key] == ""
      raise ArgumentError.new "Invalid item (not found in menu)" unless menu.include? item
      item[:label] = pick_string "label [#{item[:label]}]", [ item[:label] ]
      item[:key] = pick_string "exec", [ item[:key] ]
      other_params = string_eval pick_string("other_params (EVAL)")
      item.merge! other_params if other_params.is_a? Hash
      LOGGER.info "Item updated #{item.inspect}"
      item
    end

    alias :add :add_item
    alias :mod :mod_item
    alias :del :del_item

    def mod_conf(key = nil)
      if key
        key = key.to_sym
        conf[key] = string_eval(pick_string "edit conf[#{key}]", [ { label: conf[key], key: conf[key] } ])
      else
        pick "edit key", conf.keys.map { |c| { label: c.to_s, key: c } } do |item|
          mod_conf item[:key]
        end
      end
    end

    def save_conf
      File.write conf[:conf_file], YAML.dump(conf)
      LOGGER.info "Confuration saved to #{conf[:conf_file]}"
    end

    def load_conf(conf_file = conf[:conf_file])
      self.conf = YAML.load_file conf_file
      reset_menu!
      LOGGER.info "Confuration loaded from #{conf[:conf_file]}"
    end

    def open_url(url)
      system_exec conf[:web_browser], url
    end

    def edit_file(file)
      system_exec conf[:text_editor], file
    end

    def string_eval(str)
      catch_and_notify_exception { instance_eval str }
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
      catch_and_notify_exception "RMenu.system_exec error: #{e.inspect}" do
        `#{cmd}`
      end
    end

    def catch_and_notify_exception(msg = nil)
      begin
        yield
      rescue StandardError => e
        LOGGER.debug "Exception catched[#{msg || e.message}] #{e.inspect} at #{e.backtrace.join("\n")}"
        notify "Exception catched: #{msg || e.message}"
      rescue SyntaxError => se
        LOGGER.debug "Exception catched[#{msg || se.message}] #{se.inspect} at #{se.backtrace.join("\n")}"
        notify "Exception catched: #{msg || e.message}"
      end
    end

    def dmenu_instance
      DMenuWrapper.new current_profile
    end

  end
end
