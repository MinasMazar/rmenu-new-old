require "rmenu/dmenu_wrapper"
require "rmenu/menu/base"
require "yaml"

module RMenu
  class Base

    attr_accessor :config
    attr_accessor :root_menu
    attr_accessor :current_menu

    def initialize(config)
      yml_config = {}
      if config[:config_file]
        yml_config = YAML.load_file config[:config_file]
      end
      self.config = yml_config.merge config
      build_menu
    end

    def build_menu(force_reset = false)
      self.config[:menu] ||= {}
      self.config[:menu][:main] = Set.new(RMenu::Menu::MAIN) if force_reset
      self.current_menu = self.config[:menu][:main]
      self.root_menu = current_menu
    end

    def build_menu!
      build_menu true
    end

    def start
      pick "rmenu => ", current_menu
    end

    def pick(prompt, items, other_params = {})
      _dmenu = dmenu
      _dmenu.set_params other_params
      _dmenu.prompt = prompt
      _dmenu.items = items.to_a
      _dmenu.items = _dmenu.items.map { |i| i.merge label: ( i[:marked] == true ? "*#{i[:label]}*" : i[:label] ) }
      _dmenu.items = _dmenu.items.sort_by { |i| i[:order] || 50 }
      _item = _dmenu.get_item
      _item = items.find { |i| i[:key] == _item[:key] } || _item
    end

    def proc(item)
      raise ArgumentError.new "No valid item passed as argument (must be a Hash)" unless item.is_a? Hash
      LOGGER.debug "Picked item #{item.inspect}"
      if item[:key].is_a? Symbol
        send item[:key]
      elsif item[:key].is_a? Proc
        catch_and_notify_exception do
          instance_eval(&item[:key])
        end
      elsif item[:key].is_a? Array
        item[:key] = Set.new item[:key]
        proc item
      elsif item[:key].is_a? Set
        last_menu = current_menu
        self.current_menu = item[:key]
        proc(pick(item[:label], current_menu))
        self.current_menu = last_menu
      elsif item[:key].is_a?(String) && item[:key].strip != ""
        str = replace_tokens item[:key]
        str = replace_blocks str
        if md = str.match(/^:\s*(.+)/)
          string_eval md[1]
        elsif md = str.match(/^(http(s?):\/\/.+)/)
          open_url md[1]
        elsif md = str.match(/^!\s*(.+)/)
          system_exec md[1]
        elsif config[:exec_str]
          system_exec str
        end
      end
    end

    def replace_tokens(cmd)
      replaced_cmd = cmd.clone
      while md = replaced_cmd.match(/(__(.+?)__)/)
        break unless md[1] || md[2]
        input = get_string(md[2])
        return "" if input == ""
        replaced_cmd.sub!(md[0], input)
      end
      LOGGER.debug "Command interpolated with input tokens: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def replace_blocks(cmd)
      replaced_cmd = cmd.clone
      catch_and_notify_exception do
        while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
          break unless md[1] || md[2]
          evaluated_string = self.instance_eval(md[2]).to_s # TODO: better to eval in a useful sandbox
          return if evaluated_string == nil
          replaced_cmd.sub!(md[0], evaluated_string)
        end
        replaced_cmd
      end
      LOGGER.debug "Command interpolated with eval blocks: #{replaced_cmd}" if replaced_cmd != cmd
      replaced_cmd
    end

    def get_string(prompt, items = [], other_params = {})
      pick(prompt, items, other_params)[:key]
    end

    def notify(msg)
      pick msg, []
    end

    def pick_item_interactive(prompt, menu = current_menu, deeply)
      item = pick prompt, menu, selected_background: "#FF2244"
      item, menu = pick_item_interactive prompt, item[:key], deeply if deeply && item[:key].is_a?(Set)
      [ item, menu ]
    end

    def create_item_interactive
      label, key = get_string("label"), get_string("exec")
      other_params = string_eval get_string("other params (EVAL)")
      item = { label: label, key: key , user_defined: true, order: 50 }
      item.merge other_params if other_params.is_a? Hash
      item
    end

    def add_item(item = create_item_interactive, menu = current_menu)
      return nil if item[:key] == "" && item[:label] == ""
      menu.add item
      LOGGER.info "Item #{item.inspect} added to menu #{menu}"
      item
    end

    def del_item(menu = root_menu, deeply = false)
      item, menu = pick_item_interactive "del item", menu, deeply
      menu.delete item
      LOGGER.info "Item #{item.inspect} removed from menu #{menu}"
      item
    end

    def mod_item
      item, menu = pick_item_interactive "mod item", root_menu, true
      raise ArgumentError.new "Invalid item (not found in menu)" unless menu.include? item
      item[:label], item[:key] = get_string("label [#{item[:label]}]"), get_string("exec [#{item[:key]}]")
      other_params = string_eval get_string("other_params (EVAL)")
      item.merge! other_params if other_params.is_a? Hash
      LOGGER.info "Item updated #{item.inspect}"
      item
    end

    def save_config
      File.write config[:config_file], YAML.dump(config)
      LOGGER.info "Configuration saved to #{config[:config_file]}"
    end

    def load_config(conf_file = config[:config_file])
      self.config = YAML.load_file conf_file
      LOGGER.info "Configuration loaded from #{config[:config_file]}"
    end

    def open_url(url)
      system_exec config[:web_browser], url
    end

    def edit_file(file)
      system_exec config[:text_editor], file
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
      cmd = cmd.join " "
      LOGGER.debug "RMenu.system_exec: #{cmd}"
      catch_and_notify_exception "RMenu.system_exec error: #{e.inspect}" do
        `#{cmd} &`
      end
    end

    def catch_and_notify_exception(msg = "")
      begin
        yield
      rescue StandardError => e
        LOGGER.debug "Exception catched[#{msg}] #{e.inspect} at #{e.backtrace.join("\n")}"
        notify "Exception catched[#{msg}] #{e.inspect}"
      end
    end

    def dmenu
      DMenuWrapper.new config
    end

  end
end
