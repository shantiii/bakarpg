require 'sinatra/base'
require 'yaml'
require 'json'

config_file = File.join(File.dirname(__FILE__), "configuration.yml")
$config = YAML.load_file(config_file)

def authenticate(username, passphrase)
  
end

class SinatraApp < Sinatra::Base
  enable :sessions
  get '/' do
    send_file 'public/chat.html'
  end
  get '/js/server-config.js' do
    content_type "application/javascript"
    server_defines = {socketUri: "ws://#{$config['websocket_host']}:#{$config['websocket_port']}/chat/socket"}
    "function getServerConfig() { return #{server_defines.to_json}; }"
  end
end

map '/' do
  run SinatraApp
end
