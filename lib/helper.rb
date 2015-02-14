class Helper
  MINUTES_IN_YEAR = 525600
  MINUTES_IN_QUARTER_YEAR = 131400
  MINUTES_IN_THREE_QUARTERS_YEAR = 394200

  def self.pluralize(count, singular, plural = nil)
    plural ||= "#{singular}s"
    count == 1 ? "1 #{singular}" : "#{count} #{plural}"
  end
  
  def self.distance_of_time_in_words(from_time, to_time = 0, options = {})
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    from_time, to_time = to_time, from_time if from_time > to_time
    distance_in_minutes = ((to_time - from_time)/60.0).round
    distance_in_seconds = (to_time - from_time).round

    case distance_in_minutes
      when 0..1
        return distance_in_minutes == 0 ?
               "less than 1 minute" :
               "about #{distance_in_minutes} minute"

      when 2...45           then "about #{distance_in_minutes} minutes"
      when 45...90          then "about 1 hour"
      # 90 mins up to 24 hours
      when 90...1440        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
      # 24 hours up to 42 hours
      when 1440...2520      then "about 1 day"
      # 42 hours up to 30 days
      when 2520...43200     then "about #{(distance_in_minutes.to_f / 1440.0).round} days"
      # 30 days up to 365 days
      when 43200...525600   then "about " + self.pluralize((distance_in_minutes.to_f / 43200.0).round, "month")
      else
        fyear = from_time.year
        fyear += 1 if from_time.month >= 3
        tyear = to_time.year
        tyear -= 1 if to_time.month < 3
        leap_years = (fyear > tyear) ? 0 : (fyear..tyear).count{|x| Date.leap?(x)}
        minute_offset_for_leap_year = leap_years * 1440
        # Discount the leap year days when calculating year distance.
        # e.g. if there are 20 leap year days between 2 dates having the same day
        # and month then the based on 365 days calculation
        # the distance in years will come out to over 80 years when in written
        # English it would read better as about 80 years.
        minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year

        remainder                   = (minutes_with_offset % MINUTES_IN_YEAR)
        distance_in_years           = (minutes_with_offset.div MINUTES_IN_YEAR)
        if remainder < MINUTES_IN_QUARTER_YEAR
          "about " + self.pluralize(distance_in_years, "year")
        elsif remainder < MINUTES_IN_THREE_QUARTERS_YEAR
          "over " + self.pluralize(distance_in_years, "year")
        else
          "almost #{distance_in_years + 1} years"
      end
    end
  end
  
  def self.number_with_delimiter(number)
    parts = number.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
    parts.join('.')
  end
end
