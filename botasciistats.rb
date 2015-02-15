require 'logger'
require 'readline'
require_relative 'lib/helper'
require_relative 'lib/twitter_client'
require_relative 'lib/stats'

TARGET = 'BotAscii'
ASCII_RANGE = 32..126
ASCII_REGEXP = Regexp.new("^[\\x#{ASCII_RANGE.first.to_s(16)}-\\x#{ASCII_RANGE.last.to_s(16)}]{1,16}$")

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
    twitter.on_mention do |tweet|
      logger.info "Incoming mention: #{tweet.text}"
      response = response_for(tweet.text)
      logger.info "Responding with: #{response}"
      respond_to(tweet, response)
    end
  end
  
  def run_console
    while(input = Readline.readline('> ', true))
      puts response_for(input)
    end
  end
  
  def respond_to(tweet, response)
    twitter.tweet("@#{tweet.screen_name} #{response}", in_reply_to_status_id: tweet.id)
  end
  
  def response_for(message)
    case message
    when /\bhelp\b/i
      [
        "Try asking me when @#{TARGET} will be tweeting a specific string.",
        "For a start, you could ask me how fast @#{TARGET} is tweeting.",
        "Maybe you'd like to ask me what @#{TARGET}'s last tweet was?",
        "I could tell you how many tweets @#{TARGET} has already made."
      ].sample

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
      text = $1
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
end


if __FILE__ == $0
  instance = BotAsciiStats.new
  if ARGV.first == "console"
    instance.run_console
  else
    instance.run
  end
end