require 'pp'
require 'sinatra/base'
require 'em-websocket'
require 'json'
require 'thin'
require 'yaml'
require 'cgi' #escaping HTML
require 'redis'
require 'set'

config_file = ARGV[0] || File.join(File.dirname(__FILE__), "configuration.yml")
config = YAML.load_file(config_file)

class ApplicationError < StandardError
  def initialize(message)
    super(message)
  end
end

def log(msg)
  puts msg
end

def error_rsp(msg)
  { type:"error", message:msg }
end

def chat(nick, msg)
  { type:"chat", nick:nick, message:msg }
end

def ooc(nick, msg)
  { type:"ooc", nick:nick, message:msg }
end

def emote(nick, msg)
  { type:"emote", nick:nick, message:msg }
end

def renamed(old_nick, new_nick)
  { type:"rename", old:old_nick, new:new_nick }
end

def id(granted_nick)
  { type:"id", nick:granted_nick }
end

def joined(joined_nick)
  { type:"join", nick:joined_nick }
end

def leave(left_nick)
  { type:"leave", nick:left_nick }
end

def userlist(nicks)
  {type:"userlist", nicks:nicks}
end

class EmbeddedTcpServer < Thin::Backends::TcpServer
  def initialize(host, port, options)
    @options = options
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

EventMachine.run do
  @channel = EventMachine::Channel.new
  @names = {}
  @redis = Redis.new
  @sockets = Set.new

  EventMachine.add_periodic_timer(10) do
    @sockets.each do |socket|
      socket.ping if socket.pingable?
    end
  end

  def push_msg(msg_obj)
    msg_obj[:msgid] = @redis.rpush("campaign:test.log", msg_obj)
    @channel.push(msg_obj.to_json)
  end

  EventMachine::WebSocket.start(host: '0.0.0.0', port: config['websocket_port'], debug: true) do |socket|
    socket.onopen do |handshake|
      @sockets.add socket
      pp handshake
      sid = @channel.subscribe do |msg|
        socket.send msg
      end
      @names[sid] = "user#{sid}"
      socket.send id(@names[sid]).to_json
      socket.send userlist(@names.values).to_json
      push_msg joined(@names[sid])

      socket.onmessage do |jsonmsg|
        begin
          msg = JSON.parse(jsonmsg)
          socket.send_text error_rsp("Not a valid request.").to_json if msg.nil?
          msg['message'] = CGI.escapeHTML(msg['message']) unless msg['message'].nil?
          if (msg['type'] == 'userlist')
            socket.send userlist(@names.values).to_json
            next
          end
          response = case(msg['type'])
                     when 'nick'
                       potential_nick = CGI.escapeHTML(msg['nick'])
                       raise ApplicationError.new("Nick '#{potential_nick}' is already taken.") if @names.values.include? potential_nick
                       oldname = @names[sid]
                       @names[sid] = potential_nick
                       renamed(oldname, @names[sid])
                     when 'chat' then chat(@names[sid], msg['message'])
                     when 'emote' then emote(@names[sid], msg['message'])
                     when 'ooc' then ooc(@names[sid], msg['message'])
                     else raise ApplicationError.new("Request does not contain a valid message.")
                     end
          push_msg(response)
        rescue ApplicationError => e
          socket.send_text error_rsp(e.message).to_json;
        rescue JSON::ParserError
          socket.send_text error_rsp("Request does not contain valid JSON.").to_json
        end
      end

      socket.onclose do
        @channel.unsubscribe(sid)
        push_msg leave(@names[sid])
        @names.delete sid
        @sockets.delete socket
      end

      socket.onerror do |error|
        @channel.unsubscribe(sid)
        push_msg leave(@names[sid])
        @names.delete sid
        @sockets.delete socket
        if (error.kind_of?(EventMachine::WebSocket::WebSocketError))
          log(error)
        end
      end
    end
  end

  class WebApp < Sinatra::Base
    get '/files' do
    end
    get '/files/:category' do
    end
    get '/files/:category/:file' do
    end
  end

  Thin::Logging.silent = true
  Thin::Server.start(@host, @port, WebApp, backend: EmbeddedTcpServer)
end

# option to hide OOC chat
# suboption for even-your-own

class Campaign
end

class CampaignSession
end
