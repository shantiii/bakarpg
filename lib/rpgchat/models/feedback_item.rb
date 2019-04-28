require 'date'
require 'json'

module RPGChat
  class FeedbackItem
    attr_accessor :id # Integer - uniquely identifies this FeedbackItem
    attr_accessor :title # String - a brief, one-line description of the issue
    attr_accessor :description # String - an optional, more-detailed description of this issue
    attr_accessor :author # User - the person who authored this request
    attr_accessor :created_at # DateTime - the creation timestamp of this item
    attr_accessor :votes # Integer - the number of registered users interested in this
    attr_accessor :status # String - 'incomplete' or 'complete'

    def initialize(id = nil, title = nil, description = "No description provided", author = nil, created_at = DateTime.now, votes = 1, status = 'incomplete')
      @id = id
      @title = title
      @description = description
      @author = author
      @created_at = created_at
      @votes = votes
      @status = status
    end

    def to_json
      {
        id: @id,
        title: @title,
        description: @description,
        author: @author,
        created_at: @created_at.rfc2822,
        votes: @votes,
        status: @status
      }.to_json
    end
  end
end
