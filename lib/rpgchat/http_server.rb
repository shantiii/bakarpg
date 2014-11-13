require 'sinatra/base'
require 'redis'
require 'scrypt'
require 'json'

module RPGChat
  class HttpServer < Sinatra::Base

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
      @config = config
      @redis = Redis.new(@config.redis.opts)
      super(config.http.opts)
    end
    # Store login state in sessions

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
      send_file 'public/chat.html'
    end

    post '/register' do
      username = request[:username]
      password = request[:password]
      return 400, "Bad Input" if false #TODO: validate username and password here
      username_valid = @redis.sadd "usernames", username
      return 409, "Username Exists" unless username_valid # If we can't insert this valid username into the set of usernames...
      user_id = @redis.incr "user-ids"
      scrypted_pass = SCrypt::Password.create(password)
      @redis.hmset "user-login:#{username}", "user-id", user_id, "password-hash", scrypted_pass
      @redis.hmset "user:#{user_id}", "username", username
      return 200, "Registered"
    end

    post '/login' do
      #TODO validate username/password here
      username = request[:username]
      user_id, pass_hash = @redis.hmget "username:#{username}", "user-id", "password-hash"
      scrypted_pass = SCrypt::Password.new(pass_hash)
      return 401, "Invalid Data" if user_id == nil? or scrypted_pass != params[:password]
      session[:user] = {id:user_id, name:username}
      return 200, "Authenticated"
    end

    post '/logout' do
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
