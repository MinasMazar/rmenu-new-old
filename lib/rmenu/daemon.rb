require "rmenu/base"

module RMenu
  class Daemon < Base

    attr_accessor :listening
    attr_accessor :listening_thread
    attr_accessor :keep_open

    def initialize(conf)
      super conf
      self.keep_open = false
    end

    def start
      self.listening = true
      self.listening_thread = Thread.new do
        LOGGER.info "Created listening thread.. wait for wake code at #{conf[:waker_io]}.."
        while self.listening && keep_open? || (wake_code = File.read(conf[:waker_io]).chomp).to_sym
          switch_profile! wake_code
          super
        end
      end
      self
    end

    def stop
      self.listening = false
      LOGGER.info "Stopping listening thread"
      listening_thread && listening_thread.kill
    end

    def proc(item)
      self.keep_open = item[:keep_open]
      super item
    end

    def keep_open?
      @keep_open
    end

  end
end
