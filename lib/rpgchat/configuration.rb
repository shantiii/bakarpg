require 'yaml'

module RPGChat
  class RedisConfiguration
    attr_accessor :host
    attr_accessor :port
    attr_accessor :password
    attr_accessor :data_db
    attr_accessor :auth_db

    def initialize(hash)
      raise "redis configuration missing" if hash.nil?
      @bind = hash["host"]
      @port = hash["port"]
      @password = hash["password"]
      @data_db = hash["data_db"] || 0
      @auth_db = hash["auth_db"] || 1
    end

    def to_opts(conn = :data)
      if conn == :data
        {host:@host,port:@port,password:@password,db:@data_db}
      elsif conn == :auth
        {host:@host,port:@port,password:@password,db:@auth_db} 
      else
        nil
      end
    end
  end

  class WebSocketServerConfiguration
    attr_accessor :bind
    attr_accessor :port
    attr_accessor :uri
    def initialize(hash)
      raise "websocket server configuration missing" if hash.nil?
      @bind = hash["listen_host"]
      @port = hash["listen_port"]
      @uri = hash["service_uri"]
    end
    def opts
      {}
    end
  end

  class HttpServerConfiguration
    attr_accessor :bind
    attr_accessor :port
    def initialize(hash)
      raise "http server configuration missing" if hash.nil?
      @bind = hash["listen_host"]
      @port = hash["listen_port"]
    end
    def opts
      {bind:@bind, port:@port}
    end
  end

  class AppConfiguration
    attr :http
    attr :websocket
    attr :redis
    def self.load(filename)
      AppConfiguration.new(YAML.load_file(filename))
    end
    def initialize(hash = {})
      raise "configuration missing" if hash.nil?
      @raw = hash
      @http = HttpServerConfiguration.new(hash["http"])
      @websocket = WebSocketServerConfiguration.new(hash["websocket"])
      @redis = HttpServerConfiguration.new(hash["redis"])
    end
  end
end
