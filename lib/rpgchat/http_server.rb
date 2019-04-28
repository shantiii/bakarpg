require 'sinatra/base'
require 'redis'
require 'scrypt'
require 'json'
require 'rpgchat/redis_dao'

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
      def user
        usr = Struct.new(:name, :motto, :bio, :chars, :visible?).
          new("simon_belmont", "Good things come on those who wait.",
             " My god, it's full of stars. And crap. Mostly crap. It's better to have love and lost than never to have loved at all, but it still fuckin smarts.", [], true)
        haracter = Struct.new(:name, :id, :title, :img)
        usr.chars << haracter.new("Phage, the Untouchable", 13, "Blackhearted Planeswalking Goddess", "http://lorempixel.com/output/cats-q-c-128-128-1.jpg")
        usr.chars << haracter.new("Jaina Proudmore", 97, "Sorceress Apprentice, Heiress to the Throne", "http://lorempixel.com/output/cats-q-c-128-128-1.jpg")
        usr
      end
      def title
        "TODO: Fix Titles" #TODO: Fix Titles
      end
    end

    def initialize(appfile, config)
      puts "HELLO"
      settings.app_file = appfile
      settings.protection = {origin_whitelist: ['http://localhost:8080','http://127.0.0.1:8080']}
      @config = config
      @redis = Redis.new(@config.redis.opts)
      @dao = RedisDAO.new(@redis)
      super()
    end

    get '/' do
      erb :index
    end

    get '/about' do
      erb :about
    end

    get '/privacy' do
      erb :privacy
    end

    get '/contact' do
      erb :feedback
    end

    get '/feedback' do
      halt 403 if not logged_in?
      erb :feedback, locals: {dao: @dao}
    end

    post '/feedback/:item/complete' do
      halt 403 if not logged_in?
      halt 403 unless session[:user][:id] == 0
      @dao.complete params[:item]
    end

    post '/feedback/:item/unlike' do
      halt 403 if not logged_in?
      @dao.unupvote(params[:item], session[:user][:id])
      [200, '{}']
    end

    post '/feedback/:item/like' do
      halt 403 if not logged_in?
      @dao.unupvote(params[:item], session[:user][:id])
      [200, '{}']
    end

    post '/feedback' do
      halt 403, "Must be logged in to post a comment." if not logged_in?
      new_item_id = @redis.incr "counter:feedback-items"
      # request body should be JSON object with 'title' and 'description'
      obj = JSON.parse(request.body.read) 
      item = FeedbackItem.new(nil, obj['title'], obj['description'], @dao.user(session[:user][:id]))
      completed_item = @dao.add_feedback(item)
      [200, completed_item.to_json]
    end

    get '/me' do
      redirect '/' unless logged_in?
      redirect "/users/#{username}"
    end

    error 400..500 do
      erb :error
    end

    put '/users/:username' do
      raise "Not Implemented"
    end

    get '/users/:username' do
      # TODO: load user model here, if allowed
      erb :user
    end

    get '/rooms/:room' do
      # TODO: set up room model here
      erb :chat, locals:{title: "Chat Page!", my_room: params[:room], my_room_desc: "Some more text"}
    end

    get '/logout' do
      session[:user] = nil
      erb :logout
    end

    post '/register' do
      USERNAME_REGEX = /^\w{3,40}$/
      PASSWORD_MIN = 8
      PASSWORD_MAX = 500
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
      user_id, pass_hash = @redis.hmget "user-login:#{username}", "user-id", "password-hash"
      if pass_hash.nil?
        SCrypt::Password.create("timing attacks are fun") == "timing attacks are fun"
        return 401, "Invalid data"
      end
      scrypted_pass = SCrypt::Password.new(pass_hash)
      return 401, "Invalid Data" if user_id.nil? or scrypted_pass != password
      session[:user] = {id:user_id, name:username}
      return 200, "Authenticated"
    end

    before do
      pp session
    end

    post '/logout' do
      return 403, "Not logged in!" unless logged_in?
      session[:user] = nil
      return 200, "Logged out"
    end

  end
end
