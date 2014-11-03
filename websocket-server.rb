require 'pp'
require 'sinatra/base'
require 'em-websocket'
require 'json'
require 'thin'
require 'cgi' #escaping HTML

class ApplicationError < StandardError
  def initialize(message)
    super(message)
  end
end

def log(msg)
  puts msg
end

def error_rsp(msg)
  { type:"error", message:msg }.to_json
end

def chat(nick, msg)
  { type:"chat", nick:nick, message:msg }.to_json
end

def ooc(nick, msg)
  { type:"ooc", nick:nick, message:msg }.to_json
end

def emote(nick, msg)
  { type:"emote", nick:nick, message:msg }.to_json
end

def renamed(old_nick, new_nick)
  { type:"rename", old:old_nick, new:new_nick }.to_json
end

def id(granted_nick)
  { type:"id", nick:granted_nick }.to_json
end

def joined(joined_nick)
  { type:"join", nick:joined_nick }.to_json
end

def leave(left_nick)
  { type:"leave", nick:left_nick }.to_json
end

def userlist(nicks)
  {type:"userlist", nicks:nicks}.to_json
end

EventMachine.run do
  @channel = EventMachine::Channel.new
  @names = {}

  EventMachine::WebSocket.start(host: '0.0.0.0', port: 8080, debug: true) do |socket|
    socket.onopen do |handshake|
      pp handshake
      sid = @channel.subscribe do |msg|
        socket.send msg
      end
      @names[sid] = "user#{sid}"
      socket.send id(@names[sid])
      socket.send userlist(@names.values)
      @channel.push joined(@names[sid])
      socket.onmessage do |jsonmsg|
        begin
          msg = JSON.parse(jsonmsg)
        socket.send_text error_rsp("Not a valid request.") if msg.nil?
        msg['message'] = CGI.escapeHTML(msg['message']) unless msg['message'].nil?
        response = case(msg['type'])
                   when 'nick'
                     potential_nick = CGI.escapeHTML(msg['nick'])
                     raise ApplicationError.new("Nick is already taken.") if @names.values.include? potential_nick
                     oldname = @names[sid]
                     @names[sid] = potential_nick
                     renamed(oldname, @names[sid])
                   when 'chat' then chat(@names[sid], msg['message'])
                   when 'emote' then emote(@names[sid], msg['message'])
                   when 'ooc' then ooc(@names[sid], msg['message'])
                   when 'userlist' then userlist(@names.values)
                   else raise ApplicationError.new("Request does not contain a valid message.")
                   end
        @channel.push(response)
        rescue ApplicationError => e
          socket.send_text error_rsp(e.message);
        rescue JSON::ParserError
          socket.send_text error_rsp("Request does not contain valid JSON.")
        end
      end
      socket.onclose do
        puts "sads!"
        @channel.unsubscribe(sid)
        @channel.push leave(@names[sid])
        @names.delete sid
      end
      socket.onerror do |error|
        puts "sads"
        @channel.unsubscribe(sid)
        @channel.push leave(@names[sid])
        @names.delete sid
        if (error.kind_of?(EventMachine::WebSocket::WebSocketError))
          log(error)
        end
      end
    end
  end
end

# option to hide OOC chat
# suboption for even-your-own

class WebApp < Sinatra::Base
  get '/files' do
  end
  get '/files/:category' do
  end
  get '/files/:category/:file' do
  end
end

class Campaign
end

class CampaignSession
end
