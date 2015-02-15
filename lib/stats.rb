class Stats
  attr_reader :twitter, :username, :ascii_range
  
  def initialize(twitter, username, ascii_range)
    @twitter     = twitter
    @username    = username
    @ascii_range = ascii_range
  end
  
  # Returns: tweet interval in seconds
  def recent_tweet_interval(tweets_to_consider: 10)
    recent_tweets = twitter.get_recent_tweets_from(username, count: tweets_to_consider)
    timestamps = recent_tweets.map(&:created_at)
    intervals = timestamps[0..-2].zip(timestamps[1..-1]).map{|t2, t1| t2 - t1}
    intervals.sort[intervals.length / 2]
  end
  
  def num_tweets
    twitter.get_tweet_count_for(username)
  end
  
  def last_tweet
    twitter.get_latest_tweet_from(username)
  end
  
  # Returns Time, or nil if `text` has already been tweeted
  def estimated_timestamp_for(text)
    tweet = last_tweet
    current_sequence_nr = sequence_nr_for(tweet.text)
    expected_sequence_nr = sequence_nr_for(text)
    if (nr_of_tweets = expected_sequence_nr - current_sequence_nr) <= 0
      return nil
    else
      tweet.created_at + (nr_of_tweets * recent_tweet_interval)
    end
  end
  
  def sequence_nr_for(string)
    string.reverse.chars.
      map{|c| c.ord - ascii_range.first}.
      map.with_index{|c, i| c * (ascii_range.size ** i)}.
      inject(:+)
  end
end
