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
      load_config
      reload_menu
    end

    def reload_menu
      self.config[:menu] = { main: RMenu::Menu::MAIN }.merge self.config[:menu]
      self.current_menu = self.config[:menu][:main]
      current_menu.uniq!
      self.root_menu = current_menu
    end

    def start
      pick "rmenu => ", current_menu
    end

    def pick(prompt, items, other_params = {})
      _dmenu = dmenu
      _dmenu.set_params other_params
      _dmenu.prompt = prompt
      _dmenu.items = items
      _dmenu.get_item
    end

    def proc(item)
      if item[:key].is_a? Symbol
        send item[:key]
      elsif item[:key].is_a? Proc
        catch_and_notify_exception do
          instance_eval(&item[:key])
        end
      elsif item[:key].is_a? Array
        last_menu = current_menu
        self.current_menu = item[:key]
        proc(pick(item[:label], current_menu))
        self.current_menu = last_menu
      elsif item[:key].is_a?(String) && item[:key].strip != ""
        str = replace_tokens item[:key]
        str = replace_blocks str
        if md = str.match(/^:(.+)/)
          string_eval md[1]
        elsif md = str.match(/^(http(s?):\/\/.+)/)
          open_url md[1]
        elsif md = str.match(/^!(.+)/)
          system_exec md[1]
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

    def get_string(prompt)
      pick(prompt, [])[:key].to_s
    end

    def notify(msg)
      pick msg, []
    end

    def add_item(item = create_item_interactive, menu = current_menu)
      item = { label: item, key: (item.split("#")[1] || item ) } if item.is_a? String
      return nil if item[:key] == "" && item[:label] == ""
      menu.unshift item
      LOGGER.info "Item #{item.inspect} added to menu #{menu}"
      item
    end

    def pick_item_interactive(prompt, menu = current_menu, deeply)
      item = pick prompt, menu, selected_background: "#FF2244"
      item, menu = pick_item_interactive prompt, item[:key], deeply if item[:key].is_a? Array
      [ item, menu ]
    end

    def create_item_interactive
      label, key = get_string("label"), get_string("exec")
      { label: label, key: key , user_defined: true }
    end

    def del_item
      item, menu = pick_item_interactive "del item", root_menu, true
      menu.delete item
      LOGGER.info "Item #{item.inspect} removed from menu #{menu}"
      item
    end

    def mod_item
      item, menu = pick_item_interactive "mod item", root_menu, true
      item[:label], item[:key] = get_string("label [#{item[:label]}]"), get_string("exec [#{item[:key]}]")
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

    def string_eval(str)
      catch_and_notify_exception { instance_eval str }
    end

    def system_exec(*cmd)
      cmd << "&"
      cmd = cmd.join " "
      LOGGER.debug "RMenu.system_exec: [#{cmd}]"
      catch_and_notify_exception do
        system "sh -c #{cmd}"
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
