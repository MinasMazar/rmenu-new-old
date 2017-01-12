require "rmenu/dmenu_wrapper"
require "rmenu/menu/base"
require "yaml"

module RMenu
  class Base

    attr_accessor :config
    attr_accessor :menu

    def initialize(config)
      @config = config.clone
      yml_config = {}
      if config[:config_file]
        yml_config = YAML.load_file config[:config_file]
      end
      self.config = yml_config.merge config
      self.config[:menu] ||= { base: RMenu::Menu::BASE }
      @menu = self.config[:menu] && self.config[:menu][:base]
    end

    def start
      pick "rmenu => ", menu
    end

    def pick(prompt, items)
      _dmenu = dmenu
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
        proc(pick(item[:label], item[:key]))
      elsif item[:key].is_a?(String) && item[:key].strip != ""
        str = replace_tokens item[:key]
        str = replace_blocks str
        if md = str.match(/^:(.+)/)
          send md[1].split(" ")[0], *md[1].split(" ")[1..-1]
        elsif md = str.match(/^(http(s?):\/\/.+)/)
          open_url md[1]
        else
          system_exec str
        end
      end
    end

    def replace_tokens(cmd)
      replaced_cmd = cmd.clone
      while md = replaced_cmd.match(/(__(.+?)__)/)
        break unless md[1] || md[2]
        input = get_string(md[2])
        return if input == ""
        replaced_cmd.sub!(md[0], input)
      end
      LOGGER.debug "Command interpolated with input tokens: #{replaced_cmd}"
      replaced_cmd
    end

    def replace_blocks(cmd)
      replaced_cmd = cmd.clone
      catch_and_notify_exception do
        while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
          break unless md[1] || md[2]
          evaluated_string = self.instance_eval(md[2]).to_s
          return if evaluated_string == nil
          replaced_cmd.sub!(md[0], evaluated_string)
        end
        replaced_cmd
      end
      LOGGER.debug "Command interpolated with eval blocks: #{replaced_cmd}"
      replaced_cmd
    end

    def notify(msg)
      pick msg, []
    end

    def get_string(prompt)
      pick(prompt, [])[:key]
    end

    def add_item(item = create_item_interactive)
      self.menu.unshift item
    end

    def create_item_interactive
      label, key = replace_tokens("__LABEL__||__EXEC__").split("||")
      { label: label, key: key }
    end

    def save_config
      File.write config[:config_file], YAML.dump(config)
    end

    def load_config(conf_file = config[:config_file])
      self.config = YAML.load_file conf_file
    end

    def open_url(url)
      system_exec config[:web_browser], url
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
