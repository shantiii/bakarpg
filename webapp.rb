$: << './lib'
require 'rpgchat'
require 'yaml'

config_file = File.join(File.dirname(__FILE__), "configuration.yml")
root = __FILE__

RPGChat::Application.run!(root, config_file)
