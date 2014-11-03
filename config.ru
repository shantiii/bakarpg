require 'sinatra/base'
require 'rack/websocket'

class SinatraApp < Sinatra::Base
  get '/' do
    haml 'index.html'
  end
end

map '/' do
  run SinatraApp
end
