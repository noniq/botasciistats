require 'twitter'

class TwitterClient
  MAX_RETRIES = 8
  RETRY_DELAY = 10

  attr_reader :rest_client, :streaming_client, :logger
  
  def initialize(logger)
    @logger = logger
    @rest_client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
    end
    @streaming_client = Twitter::Streaming::Client.new do |config|
      config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
      config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
      config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
      config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
    end
  end

  def on_direct_mention
    streaming_client.user do |object|
      case object
      when Twitter::Tweet
        yield(Tweet.new(object)) if direct_mention?(object)
      end
    end
  end

  def get_direct_mentions_since(last_handled_tweet_id)
    mentions = rest_client.mentions_timeline(since_id: last_handled_tweet_id, count: 200)
    mentions.select{ |t| direct_mention?(t) }.map{ |t| Tweet.new(t) }
  end
  
  def get_recent_tweets_from(username, count: 10)
    with_retries{ rest_client.user_timeline(username, count: count).map{|t| Tweet.new(t) } }
  end
  
  def get_latest_tweet_from(username)
    get_recent_tweets_from(username, count: 1).first
  end
  
  def get_tweet_count_for(username)
    with_retries{ rest_client.user(username).tweets_count }
  end
  
  def tweet(message, options = {})
    message = message[0, 140] # make sure we're not overflowing twitter …
    with_retries{ rest_client.update(message, options) }
  end
  
  private
  
  def with_retries
    num_tries = 0
    begin
      num_tries += 1
      yield
    rescue Twitter::Error::ServerError, Twitter::Error::TooManyRequests => err
      if num_tries < MAX_RETRIES
        delay = err.rate_limit.reset_in || RETRY_DELAY * num_tries
        location = caller[1].gsub("#{__dir__}/", "")
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        logger.warn "#{timestamp} ERROR: \"#{err}\", retry ##{num_tries} in #{delay} seconds (#{location})"
        sleep(delay)
        retry
      else
        logger.error "Retried #{MAX_RETRIES} times, giving up."
        raise
      end
    end
  end

  def direct_mention?(tweet)
    tweet.user_mentions.map(&:id).include?(my_id) && 
      tweet.text.match(/^(dear |hey )?@#{my_screen_name}/i) &&
      tweet.user.id != my_id
  end
  
  def my_id
    @my_id ||= with_retries{ rest_client.user.id }
  end
  
  def my_screen_name
    @my_screen_name ||= with_retries{ rest_client.user.screen_name }
  end
  
  
  class Tweet
    attr_reader :id, :text, :created_at, :screen_name
    
    def initialize(twitter_gem_tweet)
      @id          = twitter_gem_tweet.id
      @text        = CGI.unescapeHTML(twitter_gem_tweet.text)
      @created_at  = twitter_gem_tweet.created_at
      @screen_name = twitter_gem_tweet.user.screen_name
    end
  end
end