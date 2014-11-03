require 'sinatra/base'

class SinatraApp < Sinatra::Base
  get '/' do
    send_file 'public/chat.html'
  end
end

map '/' do
  run SinatraApp
end
