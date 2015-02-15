require 'twitter'

class TwitterClient
  MAX_RETRIES = 8
  RETRY_DELAY = 10

  attr_reader :rest_client, :streaming_client
  
  def initialize
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

  def on_mention
    streaming_client.user do |object|
      case object
      when Twitter::Tweet
        if object.user_mentions.map(&:id).include?(my_id) && 
           object.text.match(/^(dear |hey )?@#{my_screen_name}/i) &&
           object.user.id != my_id
        then
          yield(object)
        end 
      end
    end
  end
  
  def get_recent_tweets_from(username, count: 10)
    with_retries{ rest_client.user_timeline(username, count: count) }
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
        puts "#{timestamp} ERROR: \"#{err}\", retry ##{num_tries} in #{delay} seconds (#{location})"
        sleep(delay)
        retry
      else
        puts "Retried #{MAX_RETRIES} times, giving up."
        raise
      end
    end
  end

  def my_id
    @my_id ||= with_retries{ rest_client.user.id }
  end
  
  def my_screen_name
    @my_screen_name ||= with_retries{ rest_client.user.screen_name }
  end
end