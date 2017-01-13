require "rmenu/base"

module RMenu
  class Daemon < Base

    attr_accessor :listening
    attr_accessor :listening_thread

    def start
      self.listening = true
      self.listening_thread = Thread.new do
        while self.listening && (wake_code = File.read(config[:waker_io]).chomp)
          if wake_code == "default"
            item = super
            if item
              proc item
            end
          end
        end
      end
      self
    end

    def stop(skip_save = false)
      self.listening = false
      listening_thread && listening_thread.kill
      save_config if !skip_save && config[:save_on_quit]
    end

    def proc(item)
      super item
    end

  end
end
