require 'erb'
require 'date'
require 'cgi'
require 'json'
require 'uri'
require 'net/http'

module ReportHelper
  SHORT_DATE = '%-m/%-d'
  LONG_DATE = '%A, %B %d, %Y'
  NORMAL_DATE = '%m/%d/%Y'
  RPT_DATE = '%Y-%m-%d'
  REPORT_HELPER_MULTI_RESULTS = {}
  REPORT_HELPER_MULTI_RESULTS[:multi_result] = []
  REPORT_HELPER_MULTI_RESULTS[:email_result] = nil

  def render_erb(filepath, options = {})
    ret = ERB.new(File.open(filepath,'r') {|file| file.read })
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
end
