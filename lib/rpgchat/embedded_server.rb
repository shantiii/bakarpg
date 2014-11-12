require 'eventmachine'
require 'thin/backends/tcp_server'

module RPGChat
  class EmbeddedTcpServer < Thin::Backends::TcpServer
    def initialize(host, port, linked_server)
      @linked_server = linked_server
      super(host,port)
    end
    def disconnect
      super
      EventMachine.stop_server(@linked_server)
    end
    def stop!
      super
      EventMachine.stop_server(@linked_server)
    end
  end
end
