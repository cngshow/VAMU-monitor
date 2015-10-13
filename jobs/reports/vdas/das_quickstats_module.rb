require 'date'
require 'cgi'
require 'json'
require 'uri'
require 'net/http'

module DasQuickstats
  QUERY = '{"uploadDate":{"$gte":"$Date(--GTE_DATE--)","$lt":"$Date(--LTE_DATE--)"}}'

  def execute_query(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    data = response.body
    JSON.parse(data)
  end

  def date_range(rpt_sym, time)
    if rpt_sym.eql?(:haims)
      #   midnight-midnight current day
      ret = [time.strftime('%Y-%m-%d') + 'T00:00:00Z', time.strftime('%Y-%m-%d') + 'T23:59:59Z']
    else
      #   processing windows 1900-0700
      ret = [time.strftime('%Y-%m-%d') + 'T05:00:00Z', Time.at((time.to_i + 24*60*60)).strftime('%Y-%m-%d') + 'T05:00:00Z']
    end
    ret
  end

  def process_rpt(query_hash, host, ecrud, days_back, rpt_date)
    reports = {}
    (1..days_back).to_a.reverse.each do |day_index|
      time = Time.at(rpt_date.to_i - 24*60*60*day_index)
      reports[time] = {}

      query_hash.each_pair do |rpt_sym, collection|
        dates = date_range(rpt_sym, time)
        esc_query = CGI::escape(QUERY).gsub!('--GTE_DATE--', dates[0]).gsub!('--LTE_DATE--', dates[1])
        url = "#{host + ecrud + collection}/count?query=#{esc_query}"
        reports[time][rpt_sym] = execute_query(url)
      end
    end
    reports
  end
end
