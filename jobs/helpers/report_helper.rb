require 'erb'
require 'date'
require 'cgi'
require 'json'
require 'uri'
require 'net/http'
require './gem_home/gems/activesupport-4.0.8/lib/active_support/core_ext/time'

module ReportHelper
  SHORT_DATE = '%-m/%-d'
  LONG_DATE = '%A %B %d, %Y'
  LONG_DATE_TIME_ET = '%l %p EST on %A %B %e, %Y'
  NORMAL_DATE = '%m/%d/%Y'
  RPT_DATE = '%Y-%m-%d'
  REPORT_HELPER_MULTI_RESULTS = {}
  REPORT_HELPER_MULTI_RESULTS[:multi_result] = []
  REPORT_HELPER_MULTI_RESULTS[:email_result] = nil

  def render_erb(filepath, options = {})
    ret = ERB.new(File.open(filepath, 'r') { |file| file.read })
    raw_result = ret.result
    decorated_result = raw_result

    if options[:email_subject]
      decorated_result.chomp!
      decorated_result = "EMAIL_RESULT_BELOW:\nSUBJECT: #{options[:email_subject]}\n#{decorated_result}\nEMAIL_RESULT_ABOVE:"
      raise "You can only have one call to :email_subject for a job run!" if REPORT_HELPER_MULTI_RESULTS[:email_result]
      REPORT_HELPER_MULTI_RESULTS[:email_result] = decorated_result
    end

    if options[:multi_result]
      decorated_result.chomp!
      decorated_result = "__BEGIN_MULTIPLE_JOB_RESULT__\n#{decorated_result}\n__END_MULTIPLE_JOB_RESULT__"
      REPORT_HELPER_MULTI_RESULTS[:multi_result] << decorated_result
    end
    raw_result
  end

  def get_email_result
    REPORT_HELPER_MULTI_RESULTS[:email_result]
  end

  def get_multi_result
    REPORT_HELPER_MULTI_RESULTS[:multi_result].join("\n")
  end

  # add comma as a thousandths separator to all numbers in the parameter passed
  def format_number(number)
    number = 0 if number.nil?
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def get_gmt(rpt_date)
    dt = Date.parse(rpt_date)
    Time.gm(dt.year, dt.month, dt.day)
  end

  def eastern_date_time_label(utc_date_time, add_days = 0)
    ret = nil
    if utc_date_time.is_a?(String)
      unless utc_date_time =~ /.*T\d{2}:\d{2}:\d{2}Z$/
        utc_date_time.concat('T00:00:00Z')
      end
      begin
        ret = Time.parse(utc_date_time).utc + (24*60*60*add_days)
      rescue => ex
        raise "Invalid date string passed to format date!"
      end
    elsif utc_date_time.is_a?(Numeric)
      ret = Time.at(utc_date_time).utc + (24*60*60*add_days)
    elsif utc_date_time.is_a?(Time)
      ret = utc_date_time.utc + (24*60*60*add_days)
    else
      raise "Invalid utc_date_time argument passed to eastern_date_time method. This should be either a Time object, a string or a number (epoch time) in UTC."
    end
    s = ret.in_time_zone("America/New_York").strftime(LONG_DATE_TIME_ET)
    s.sub!('EST', 'EDT') if Time.parse(s).dst?
    s
  end

  def invalid_rpt_date?(d)
    ret = false
    current = Time.now
    if get_gmt(d) >= Time.gm(current.year, current.month, current.day)
      puts "Illegal report date entered (#{d}). You cannot run this report for today or a future date."
      ret = true
    end
    ret
  end


  def gmt_to_et_time(gmt)
    et = (gmt.utc? ? gmt.clone : gmt.clone.utc).in_time_zone("America/New_York")
    et
  end

  def format_date(rpt_date, mask = NORMAL_DATE)
    #Date as a string
    if rpt_date.is_a?(String)
      begin
        rpt_date = Date.parse(rpt_date)
      rescue => ex
        raise "Invalid date string passed to format date!"
      end
    end

    #if the rpt_date is a number then time is in epoch
    rpt_date = Time.at(rpt_date) if rpt_date.is_a?(Numeric)
    rpt_date.strftime(mask)
  end

  def format_time_h_m_s(time_string)
    ret = time_string
    if time_string =~ /\d{2}:\d{2}:\d{2}/
      ret = time_string.sub(':', 'h ').sub(':', 'm ')
      ret << 's'
    end
    ret
  end

  def convert_seconds_to_time(time)
    #    time = time.to_i
    #    time_string = [time/3600, time/60 % 60, time % 60].map{|t| t.to_s.rjust(2,'0')}.join(':')
    #    time_string.sub!(':','h ').sub!(':','m ').concat('s')
    #    time_string.sub!('00h 00m ','')
    #    time_string.sub!('00h ','')
    #    time_string
    time_string = "%02dd %02dh %02dm %02ds"% [
        time.to_i/ (60*60*24),
        time.to_i/ (60*60) % 24,
        time.to_i/ 60 % 60,
        time.to_i % 60
    ]
    time_string.sub!('00d 00h 00m ', '')
    time_string.sub!('00d 00h ', '')
    time_string.sub!('00d ', '')
    time_string
  end

end

class Time
  class << self
    def next_dst_change(t = Time.now)
      the_time = t - t.min*60 - t.sec
      dst = the_time.dst?
      dst_change = !dst
      while (dst_change != dst)
        the_time = the_time + 60*60
        dst = the_time.dst?
      end
      # [the_time, the_time.month, the_time.day, the_time.dst?]
      the_time
    end
  end
end
