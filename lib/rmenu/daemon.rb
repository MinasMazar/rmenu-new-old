require "rmenu/base"

module RMenu
  class Daemon < Base

    attr_accessor :listening
    attr_accessor :listening_thread

    def start
      self.listening = true
      self.listening_thread = Thread.new do
        LOGGER.info "Created listening thread.. wait for wake code at #{conf[:waker_io]}.."
        while self.listening && (wake_code = File.read(conf[:waker_io]).chomp).to_sym
          switch_profile! wake_code
          super
        end
      end
      self
    end

    def stop(options = { skip_save: false})
      self.listening = false
      save_conf if !options[:skip_save] && conf[:save_on_quit]
      LOGGER.info "Stopping listening thread"
      listening_thread && listening_thread.kill
    end

    def proc(item)
      super item
    end

  end
end
