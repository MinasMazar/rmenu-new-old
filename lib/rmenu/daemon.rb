require "rmenu/base"

module RMenu
  class Daemon < Base

    attr_accessor :listening
    attr_accessor :listening_thread

    def start
      self.listening = true
      self.listening_thread = Thread.new do
        LOGGER.info "Created listening thread.. wait for wake code at #{conf[:waker_io]}.."
        while self.listening && (wake_code = File.read(conf[:waker_io]).chomp)
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

    def stop(options = { skip_save: false})
      self.listening = false
      listening_thread && listening_thread.kill
      LOGGER.info "Stopped listening thread"
      save_conf if !options[:skip_save] && conf[:save_on_quit]
    end

    def proc(item)
      super item
    end

  end
end
