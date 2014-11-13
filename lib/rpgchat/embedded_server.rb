require 'eventmachine'
require 'thin/backends/base'
require 'thin/backends/tcp_server'

module RPGChat
  class EmbeddedTcpServer < Thin::Backends::TcpServer
    def initialize(host, port, opts)
      @options = opts
      super(host,port)
    end
    def disconnect
      super
      EventMachine.stop
    end
    def stop!
      super
      EventMachine.stop
    end
  end
end
