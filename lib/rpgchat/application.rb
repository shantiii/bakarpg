require 'eventmachine'
require 'rpgchat/configuration'
require 'rpgchat/http_server'
require 'rpgchat/websocket_server'
require 'rack/session/pool'
require 'thin'

require 'pp'

module RPGChat
  class Application
    def self.run!(appfile, args = Hash.new({}))
      config =
        case args
        when String then AppConfiguration.load(args)
        when Hash then AppConfiguration.new(args)
        else raise "Invalid configuration provided to application"
        end
      sessioned_server = Rack::Session::Pool.new(HttpServer.new(appfile, config), sidbits:4096, key:"poop")
      EventMachine.run do
        Thin::Server.start(config.http.bind, config.http.port, sessioned_server, backend:EmbeddedTcpServer)
        EventMachine.start_server(config.websocket.bind, config.websocket.port, WebSocketServer, config, sessioned_server.pool)
      end
    end
    def self.stop!
      EventMachine.stop
    end
  end
end
