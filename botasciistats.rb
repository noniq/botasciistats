require 'readline'
require_relative 'lib/helper'
require_relative 'lib/twitter_client'
require_relative 'lib/stats'

TARGET = 'BotAscii'
ASCII_RANGE = 32..126
ASCII_REGEXP = Regexp.new("^[\\x#{ASCII_RANGE.first.to_s(16)}-\\x#{ASCII_RANGE.last.to_s(16)}]{1,16}$")

class BotAsciiStats
  attr_reader :twitter, :stats
  
  def initialize
    @twitter = TwitterClient.new
    @stats   = Stats.new(twitter, TARGET, ASCII_RANGE)
  end
  
  def run
    twitter.on_mention do |tweet|
      text = CGI.unescapeHTML(tweet.text)
      puts "Incoming mention: #{text}"
      response = response_for(text)
      puts "Responding with: #{response}"
      respond_to(tweet, response)
    end
  end
  
  def run_console
    while(input = Readline.readline('> ', true))
      puts response_for(input)
    end
  end
  
  def respond_to(tweet, response)
    twitter.tweet("@#{tweet.user.screen_name} #{response}", in_reply_to_status: tweet)
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

    when /(how (fast|often|frequently)|at which speed) (is|does) @#{TARGET} tweet(ing)?\?/i, 
         /what is @#{TARGET}'s (tweet frequency|frequency of (tweeting|tweets)|current speed)\?/i
      "@#{TARGET} is currently tweeting once every #{stats.recent_tweet_interval.round} seconds."

    when /how (often|many tweets|many messages) has @#{TARGET} (already )?(made|done|tweeted)\?/i
      "@#{TARGET} has now made #{stats.num_tweets} tweets."

    when /what was (@#{TARGET}'s (last|latest) tweet|the last tweet of @#{TARGET})\?/i
      "@#{TARGET}'s last tweet was: #{CGI.unescapeHTML(stats.last_tweet_text)}"

    when /when will @#{TARGET} (?:reach|tweet|be tweeting) (.+)\?/i
      text = $1
      return "I'm afraid @#{TARGET} will probably never tweet #{text} …" unless text.match(ASCII_REGEXP)
      if (timestamp = stats.estimated_timestamp_for(text))
        "At its current speed, @#{TARGET} will tweet #{text} #{timestamp_description_for(timestamp)}."
      else
        "Oh, #{text} has already been tweeted by @#{TARGET}."
      end

    when /(what is|what's) the meaning of life?/i, /(what is|what's) the answer to the (ultimate )?question( of (life|everything))?\?/i
      if (timestamp = stats.estimated_timestamp_for("42"))
        "@#{TARGET} will tweet the answer to the ultimate question of life #{timestamp_description_for(timestamp)}."
      else
        "The answer to the ultimate question of life has already been tweeted by @#{TARGET}. Did you miss it?"
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