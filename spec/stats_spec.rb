require_relative "../botasciistats"
require_relative "../lib/stats"

describe Stats do
  def generator_for(ascii_range)
    Enumerator.new do |y|
      chars = [ascii_range.first]
      loop do
        y << chars.map(&:chr).join
        i = chars.size - 1
        chars[i] += 1
        while (chars[i] > ascii_range.max)
          chars[i] = ascii_range.first
          if i > 0
            i -= 1
            chars[i] += 1
          else
            chars.unshift(ascii_range.min)
            break
          end
        end
      end
    end
  end
  
  # test the tests :)
  describe 'the generator used in the specs' do
    it 'produces the same strings as the real BotAscii' do
      real_tweets = File.readlines("#{__dir__}/botascii_tweets.txt").map(&:chomp)
      generator   = generator_for(ASCII_RANGE)
      real_tweets.each_with_index do |tweet, i|
        generated = generator.next
        expect(tweet).to eql(generated), "expected tweet #{i + 1} to be \"#{tweet}\", got \"#{generated}\"."
      end
    end
  end
  
  describe '#sequence_nr' do
    
    it 'generates the correct sequence number' do
      range     = 32..42 # Use a small range for testing, so we get to longer strings more quickly
      generator = generator_for(range)
      stats     = Stats.new(nil, nil, range)
      1.upto(10_000).each do |nr|
        string = generator.next
        seq_nr = stats.sequence_nr_for(string)
        expect(seq_nr).to eq(nr), "Expected \"#{string}\" to have sequence nr #{nr}, got #{seq_nr}."
      end
    end
  end
end