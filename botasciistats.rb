require 'logger'
require 'readline'
require_relative 'lib/helper'
require_relative 'lib/twitter_client'
require_relative 'lib/stats'

TARGET = 'BotAscii'
STATUS_FILE_NAME = "#{__dir__}/status.txt"
ASCII_RANGE = 32..126
ASCII_REGEXP = Regexp.new("^[\\x#{ASCII_RANGE.first.to_s(16)}-\\x#{ASCII_RANGE.last.to_s(16)}]{1,20}$")

class BotAsciiStats
  attr_reader :logger, :twitter, :stats
  
  def initialize
    @logger  = Logger.new(STDOUT)
    @logger.formatter = ->(severity, datetime, progname, msg) {
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} - #{msg}\n"
    }
    @twitter = TwitterClient.new(@logger)
    @stats   = Stats.new(twitter, TARGET, ASCII_RANGE)
  end
  
  def run
    if last_handled_tweet_id
      logger.info "Checking for unhandled mentions since id #{last_handled_tweet_id}."
      twitter.get_direct_mentions_since(last_handled_tweet_id).each do |tweet|
        logger.info "Unhandled mention from @#{tweet.screen_name}: #{tweet.text}"
        respond_to(tweet)
      end
    end
    logger.info "Now listening to the Twitter stream."
    twitter.on_direct_mention do |tweet|
      logger.info "Mention from @#{tweet.screen_name}: #{tweet.text}"
      respond_to(tweet)
    end
  end
  
  def run_console
    while(input = Readline.readline('> ', true))
      puts response_for(input)
    end
  end
  
  def respond_to(tweet)
    response = "@#{tweet.screen_name} " + response_for(tweet.text)
    logger.info "Responding with: #{response}"
    twitter.tweet(response, in_reply_to_status_id: tweet.id)
    self.last_handled_tweet_id = tweet.id
  end
  
  def response_for(message)
    case message
    when /(how (fast|often|frequently)|at which speed) (is|does) @#{TARGET} (currently )?tweet(ing)?\?/i, 
         /what is @#{TARGET}'s (tweet frequency|frequency of (tweeting|tweets)|current speed)\?/i
      if (interval = stats.recent_tweet_interval) == :not_tweeting
        "Ooops, @#{TARGET} seems to have stopped tweeting :-("
      else
        "@#{TARGET} is currently tweeting once every #{interval.round} seconds."
      end

    when /how (often|many tweets|many messages) has @#{TARGET} (already )?(made|done|tweeted)\?/i
      "@#{TARGET} has now made #{stats.num_tweets} tweets."

    when /what was (@#{TARGET}'s (last|latest) tweet|the last tweet of @#{TARGET})\?/i
      "@#{TARGET}'s last tweet was: #{stats.last_tweet.text}"

    when /when will @#{TARGET} (?:reach|tweet|be tweeting) (.+)\?/i
      text = $1.strip
      return "I'm afraid @#{TARGET} will probably never tweet #{text} …" unless text.match(ASCII_REGEXP)
      if (timestamp = stats.estimated_timestamp_for(text)) == :not_tweeting
        "Hm, @#{TARGET} seems to have stopped tweeting, so I don't know when it will tweet #{text}."
      elsif timestamp == :already_tweeted
        "Oh, #{text} has already been tweeted by @#{TARGET}."
      else
        "At its current speed, @#{TARGET} will tweet #{text} #{timestamp_description_for(timestamp)}."
      end

    when /(what is|what's) the meaning of life?/i, /(what is|what's) the answer to the (ultimate )?question( of (life|everything))?\?/i
      if (timestamp = stats.estimated_timestamp_for("42")) == :already_tweeted
        "The answer to the ultimate question of life has already been tweeted by @#{TARGET}. Did you miss it?"
      elsif timestamp == :not_tweeting
        "Seems like @#{TARGET} has stopped tweeting … so we'll never know the answer to the ultimate question of life."
      else
        "@#{TARGET} will tweet the answer to the ultimate question of life #{timestamp_description_for(timestamp)}."
      end

    when /\bhelp\b/i
      [
        "Try asking me when @#{TARGET} will be tweeting a specific string.",
        "For a start, you could ask me how fast @#{TARGET} is tweeting.",
        "Maybe you'd like to ask me what @#{TARGET}'s last tweet was?",
        "I could tell you how many tweets @#{TARGET} has already made."
      ].sample

    else
      "Sorry, I don't understand your request."
    end
  end
  
  def timestamp_description_for(timestamp)
    years = (timestamp - Time.now) / (3600 * 24 * 365.24219)
    if years < 10_000
      distance_in_words = Helper.distance_of_time_in_words(Time.now, timestamp)
      "in #{distance_in_words} (at approx. #{timestamp.strftime('%H:%M on %b. %d, %Y')})"
    else
      "in about #{Helper.number_with_delimiter(years.round)} years"
    end
  end
  
  def last_handled_tweet_id
    begin
      File.read(STATUS_FILE_NAME).chomp
    rescue Errno::ENOENT
      nil
    end
  end
  
  def last_handled_tweet_id=(id)
    File.write(STATUS_FILE_NAME, id)
  end
end


if __FILE__ == $0
  instance = BotAsciiStats.new
  at_exit{ instance.logger.warn "Exiting." }
  if ARGV.first == "console"
    instance.run_console
  else
    instance.run
  end
end