require 'em-websocket'
require 'pp'
require 'thread'
require 'rpgchat/dierolls'
require 'singleton'

module RPGChat
  class ChatError < StandardError
    def initialize(message)
      super(message)
    end
  end

  class ConnectionManager
    include Singleton

    def initialize
      @mutex = Mutex.new
      @mutex.synchronize do
        @connections = Hash.new()
        @channels = Hash.new{|h,k| h[k]= EM::Channel.new}
        @by_room = Hash.new{|h,k| h[k] = []}
        @by_cookie = Hash.new{|h,k| h[k] = []}
      end
    end

    def connect(room, cookie_token, connection)
      @mutex.synchronize do
        sub_id = @channels[room].subscribe do |msg|
          connection.channel_callback(msg)
        end
        @channels[room].push({type: 'join', nick:connection.nick}) #TODO: make these messages objects
        @by_room[room] << connection #remove channel logic from here and into Room object?
        @by_cookie[cookie_token] << connection
        @connections[connection] = {room:room, cookie:cookie_token, channel:@channels[room], sub_id:sub_id}
      end
    end

    def disconnect(connection)
      @mutex.synchronize do
        conn_info = @connections.delete(connection)
        return unless conn_info
        @channels[conn_info[:room]].unsubscribe(conn_info[:sub_id])
        conn_info[:channel].push({type: 'leave', nick:connection.nick}) #TODO: make these messages objects
        @by_room[conn_info[:room]].delete(connection)
        @by_cookie[conn_info[:cookie]].delete(connection)
      end
    end

    def nicks(room)
      pp @by_room
      @by_room[room].map{|conn|conn.nick}
    end
  end

  # This class represents one connection between a user and a chat room
  # A token can have multiple connections to a chatroom
  # A token can be logged in as 0 or 1 users
  class WebSocketServer < EventMachine::WebSocket::Connection
    @@anon_counter = 0

    attr :nick

    def initialize(config, session_pool)
      @config = config
      @pool = session_pool
      register_methods
      super(@config.websocket.opts)
    end

    def register_methods
      onopen { |handshake| on_open(handshake) }
      onclose { |msg| on_close msg }
      onerror { |err| on_error(err) }
      onmessage { |msg| on_message(msg) }
      #onbinary { |data| on_binary(data) }
      #onpong { |data| on_pong(data) }
      #onping { |data| on_ping(data) }
    end

    def channel_callback(msg)
      send_text msg.to_json
    end

    ROOM_REGEX = /^\/ws\/rooms\/([^\/[:cntrl:]]+)$/u
    def on_open(handshake)
      p "BEGIN on_open"
      room_matches = ROOM_REGEX.match(handshake.path)
      raise ChatError.new("Invalid room") unless room_matches
      @room = room_matches[1]
      cookie = CGI::Cookie.parse(handshake.headers['Cookie'])
      raise ChatError.new("You must have cookies enabled for this site in order to participate!") unless cookie
      @token = cookie["poop"].first
      raise ChatError.new("Your cookie is in an invalid state! Fix it!") unless @token
      user = @pool[@token]["user"] if @pool[@token]
      @nick =
        if user.nil?
          "anon#{@@anon_counter += 1}"
        else
          user[:name]
        end
      send_json :id, nick:@nick
      pp @conn_info = ConnectionManager.instance.connect(@room, @token, self)
      @channel = @conn_info[:channel]
      p "END on_open"
    end

    def on_close(msg)
      p "BEGIN on_close"
      pp msg
      ConnectionManager.instance.disconnect(self)
      p "END on_close"
    end

    def on_error(err)
      p "BEGIN on_error"
      pp err
      ConnectionManager.instance.disconnect(self)
      p "END on_error"
    end

    def channel_json type, obj
      @channel.push({type: type.to_s}.merge(obj))
    end

    def send_text *args
      pp args
      super *args
    end

    def send_json type, obj
      send_text({type: type.to_s}.merge(obj).to_json)
    end

    def rename(new_nick)
      old_nick = @nick
      @nick = new_nick
      #TODO: check for preexisting nicks in this room
      channel_send :rename, old:@nick, new:@nick
    end

    def on_message(json_msg)
      p "BEGIN onmessage"
      msg = JSON.parse(json_msg)
      # self-commands don't involve any interaction with the room
      # they only query state and are not logged
      case(msg['type'])
      when "userlist" then send_json :userlist, nicks:ConnectionManager.instance.nicks(@room)
      when 'nick' then rename(msg['nick'])
      when 'chat' then channel_json :chat, nick:@nick, message:msg['message']
      when 'emote' then channel_json :emote, nick:@nick, message:msg['message']
      when 'ooc' then channel_json :ooc, nick:@nick, message: msg['message']
      when 'roll' then channel_json :roll, nick:@nick, roll:RPGChat::DieRolls.roll(msg['expr']), expr: msg['expr']
      else raise ChatError.new("Request does not contain a valid message.")
      end
    rescue ChatError => e
      send_json :error, message: e.message
    ensure
      p "END onmessage"
    end
  end
end
