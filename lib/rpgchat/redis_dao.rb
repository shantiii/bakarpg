require 'rpgchat/models/user'
require 'rpgchat/models/character'
require 'rpgchat/models/feedback_item'

module RPGChat
  class RedisDAO
    USER_ID_COUNTER = "counter:user-ids"
    CHARACTER_ID_COUNTER = "counter:character-ids"
    ROOM_SET = "rooms"
    def initialize(redis)
      @redis = redis
    end
    def user(id)
      user_hash = @redis.hgetall "user:#{id}"
      user = Models::User.new(id, 1, 1)
      user.login = user_hash['username']
      user
    end
    def character(id)
      #return character
    end
    def user_by_name(name)
      #return user or nil
    end
    def login(username, password)
      #return user or nil
    end
    def persist(model, options) #options : Hash of options
      # cascade: true or false => persist the children of this node as well
      case model
      when Models::User then persist_user(model, options)
      when Character then persist_charcter(model, options)
      else raise "Unknown model type!"
      end
    end
    def persist_user(model, options)
      if (model.id == nil)
        @redis.incr USER_ID_COUNTER
      end
      @redis.atomic do
        current_user = user(model.id)
        if current_user.nil?
          raise "user we are attempting to save doesn't exist"
          # something bad happened
        end
        if current_user.version != model.version
          # attempt to auto-handle old versions?
        end
        if current_user.revision != model.revision
          # someone/something else updated the model before us! error?
        end
        if current_user == model
          next # do nothing; we are done
        end
        @redis.hmset "user:#{model.id}", "version", model.version, "revision", model.revision+1, "login", model.login, "visibility", model.visibility.to_s, "characters", model.characters.map(&:id).join(',')
        if (options[:cascade])
          model.characters.each do |character|
            persist_character(character, options.merge(atomic:false))
          end 
        end
      end
    end

    def add_feedback(feedback)
      feedback.id = @redis.incr "counter:feedback-ids"
      @redis.multi do 
        @redis.zadd "feedback-rankings", 1, feedback.id
        @redis.sadd "feedback-votes:#{feedback.id}", "user:#{feedback.author.id}"
        @redis.hmset "feedback:#{feedback.id}", 'title', feedback.title, 'description', feedback.description, 'author', feedback.author.id, 'created_at', feedback.created_at, 'status', feedback.status
      end
      feedback
    end

    def upvote(feedback_id, user_id)
      @redis.multi do
        vote_successful = @redis.sadd "feedback-votes:#{feedback_id}", "user:#{user_id}"
        @redis.zincrby "feedback-rankings", vote_successful, feedback_id
      end
    end

    def unupvote(feedback_id, user_id)
      @redis.multi do
        unvote_successful = @redis.srem "feedback-votes:#{feedback_id}", "user:#{user_id}"
        @redis.zincrby "feedback-rankings", -unvote_successful.value, feedback_id
      end
    end

    def complete(feedback_id)
      @redis.hset "feedback#{feedback_id}", 'status', 'complete'
    end

    def voted_for?(feedback_id, user_id)
      @redis.sismember "feedback-votes:#{feedback_id}", "user:#{user_id}"
    end

    def popular_feedback(count, offset=0)
      end_index = -offset - 1
      start_index = end_index - count
      id_array = @redis.zrange("feedback-rankings", start_index, end_index, with_scores: true)
      feedback = id_array.map do |id_str, score|
        item = FeedbackItem.new(id_str.to_i)
        item_hash = @redis.hgetall "feedback:#{id_str}"
        item.title = item_hash['title']
        item.description = item_hash['description']
        item.author = user(item_hash['author'])
        item.created_at = DateTime.parse(item_hash['created_at'])
        item.votes = score
        item.status = item_hash['status']
        item
      end
    end

    def recent_feedback(count, offset=0)
      num_ids = @redis.get('counter:feedback-ids')
      return [] unless num_ids
      end_index = [num_ids-1-offset, 0].max
      start_index = [end_index - count, 0].max
      id_array = start_index.upto(end_index).map do |index|
        id_str = "feedback:#{index}"
        [id_str, @redis.zscore('feedback-rankings', id_str)]
      end
      feedback = id_array.map do |id_str, score|
        item = FeedbackItem.new(id_str.to_i)
        item_hash = @redis.hgetall "feedback:#{id_str}"
        item.title = item_hash['title']
        item.description = item_hash['description']
        item.author = user(item_hash['author'])
        item.created_at = DateTime.parse(item_hash['created_at'])
        item.votes = score
        item.status = item_hash['status']
        item
      end
    end

  end
end
