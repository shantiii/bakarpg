require 'sinatra/base'
require 'redis'
require 'scrypt'
require 'json'

module RPGChat
  class HttpServer < Sinatra::Base
    enable :logging

    helpers do 
      def logged_in?
        not session[:user].nil?
      end
      def username
        if logged_in? then session[:user][:name]
        else nil end
      end
    end

    def initialize(appfile, config)
      puts "HELLO"
      settings.app_file = appfile
      settings.protection = {origin_whitelist: ['http://localhost:8080','http://127.0.0.1:8080']} #TODO: replace with whitelist
      @config = config
      @redis = Redis.new(@config.redis.opts)
      super(config.http.opts)
    end

    get '/bleeb' do
      erb :chat, locals: {title: "Bleeb!!"}
    end

    get '/authorization' do
      out_headers = {}
      if session[:user].nil?
        out_headers.merge!( "X-Logged-In" => "no")
        return [200, out_headers, ""]
      end
      out_headers.merge!({
        "X-Logged-In" => "yes",
        "X-User-Id" => session[:user][:id],
        "X-User-Name" => session[:user][:name]})
      [200, out_headers, ""]
    end

    get '/' do
      send_file 'public/chat.html'
    end

    get '/chat' do
      erb :chat, locals:{title: "Chat Page!"}
    end

    post '/register' do
      USERNAME_REGEX = /^\w{3,128}$/
      PASSWORD_MIN = 8
      PASSWORD_MAX = 4096
      return 403, "Already logged in!" if logged_in?
      json = JSON.parse(request.body.read)
      username = json['username']
      password = json['password']
      return 400, "Bad Input" unless USERNAME_REGEX.match(username)
      return 400, "Bad Input" unless password.size.between?(PASSWORD_MIN, PASSWORD_MAX)
      username_valid = @redis.sadd "usernames", username
      return 409, "Username Exists" unless username_valid # If we can't insert this valid username into the set of usernames...
      user_id = @redis.incr "user-ids"
      scrypted_pass = SCrypt::Password.create(password)
      @redis.hmset "user-login:#{username}", "user-id", user_id, "password-hash", scrypted_pass
      @redis.hmset "user:#{user_id}", "username", username
      return 200, "Registered"
    end

    post '/login' do
      return 403, "Already logged in!" if logged_in?
      json = JSON.parse(request.body.read)
      username = json['username']
      password = json['password']
      user_id, pass_hash = @redis.hmget "username:#{username}", "user-id", "password-hash"
      if pass_hash.nil?
        SCrypt::Password.create("timing attacks are fun") == "timing attacks are fun"
        return 401, "Invalid data"
      end
      scrypted_pass = SCrypt::Password.new(pass_hash)
      return 401, "Invalid Data" if user_id == nil? or scrypted_pass != password
      session[:user] = {id:user_id, name:username}
      return 200, "Authenticated"
    end

    post '/logout' do
      return 403, "Not logged in!" unless logged_in?
      session[:user] = nil
      return 200, "Logged out"
    end

    get "/who" do
      return "YOU ARE NO ONE" if session[:user].nil?
      session[:user][:name] 
    end

    get '/js/server-config.js' do
      content_type "application/javascript"
      server_defines = {socketUri: @config.websocket.uri}
      "function getServerConfig() { return #{server_defines.to_json}; }"
    end
  end
end
