class Command
  include Comparable

  attr :name
  attr :regex
  attr :tags
  def self(name, tags = [], regex = //, &blk = nil)
    Comparable.new(name, regex, &blk)
  end
  def initialize(name, tags = [], regex = //, &blk = nil)
    @name = name
    @regex = regex
    @oninvoke = blk
  end
  def <=> (other)
    @name <=> other.name
  end
  def matches?(string)
    string.start_with?(@name) and not @regex.match(string).nil?
  end
  def invoke(string)
    raise "Command definition missing" if @oninvoke.nil?
    @oninvoke.call(string, @regex.match(string))
  end
end

class CommandContext
  attr :
  attr :match_data
  attr :room_topic
  attr :room_desc
  attr :user_nick
end

#command block returns [response, newstate]

class CommandDictionary
  def initialize
    @commands = []
    @name_to_command = {}
  end
  def add(command)
    @name_to_command.merge!(command.name => command)
    @commands << command
    self
  end
  def match(string)
    @commands.each do |cmd|
      next unless cmd.matches?(string)
      yield cmd.invoke(string)
    end
  end
end

default_commands = 
