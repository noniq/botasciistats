class Stats
  attr_reader :twitter, :username, :ascii_range
  
  def initialize(twitter, username, ascii_range)
    @twitter     = twitter
    @username    = username
    @ascii_range = ascii_range
  end
  
  # Returns: tweet interval in seconds, or :not_tweeting if tweeting seems to have stopped
  def recent_tweet_interval(tweets_to_consider: 10)
    recent_tweets = twitter.get_recent_tweets_from(username, count: tweets_to_consider)
    timestamps = recent_tweets.map(&:created_at)
    intervals = timestamps[0..-2].zip(timestamps[1..-1]).map{|t2, t1| t2 - t1}
    mean_interval = intervals.sort[intervals.length / 2]
    time_since_last_tweet = Time.now - recent_tweets.first.created_at
    if time_since_last_tweet <= mean_interval * 5
      mean_interval
    else
      :not_tweeting
    end
  end
  
  def num_tweets
    twitter.get_tweet_count_for(username)
  end
  
  def last_tweet
    twitter.get_latest_tweet_from(username)
  end
  
  # Returns Time, or :not_tweeting, or :already_tweeted if `text` has already been tweeted
  def estimated_timestamp_for(text)
    tweet_interval = recent_tweet_interval
    tweet = last_tweet
    current_sequence_nr = sequence_nr_for(tweet.text)
    expected_sequence_nr = sequence_nr_for(text)
    if (nr_of_tweets = expected_sequence_nr - current_sequence_nr) <= 0
      :already_tweeted
    elsif tweet_interval == :not_tweeting
      :not_tweeting
    else
      tweet.created_at + (nr_of_tweets * tweet_interval)
    end
  end
  
  def sequence_nr_for(string)
    total_nr_of_shorter_strings = 1.upto(string.length - 1).to_a.map{ |n| magic_formula(n) }.inject(0, :+)

    position_within_strings_of_same_length = string.reverse.chars.
      map{|c| c.ord - ascii_range.first}.
      map.with_index{|c, i| c * (ascii_range.size ** i)}.
      inject(:+)
    
    total_nr_of_shorter_strings + position_within_strings_of_same_length - 
      (ascii_range.size ** (string.length - 1)).floor -
      position_within_strings_of_same_length / ascii_range.size +
      (ascii_range.size ** (string.length - 2)).ceil
  end
  
  def magic_formula(length)
    n = ascii_range.size
    n ** length - 2 * (n ** (length - 1)).ceil + (n ** (length - 2)).ceil
  end
end
