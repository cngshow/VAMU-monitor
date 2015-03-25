require 'date'
require 'cgi'
require 'json'
require 'uri'
require 'net/http'
require './jobs/reports/vdas/das_quickstats_module'

include DasQuickstats

begin
QUERY = '{"uploadDate":{"$gte":"$Date(--GTE_DATE--)","$lt":"$Date(--LTE_DATE--)"}}'

# HOST = ARGV.shift
# QUERY_DB = 'ecrud/v1/core/'

# reporting date
@@rpt_date = Date.strptime(ARGV.shift, '%Y%m%d').to_time

# reporting days back
@@days_back = ARGV.shift.to_i

query_hash = {}
query_hash[:haims] = 'serviceTreatmentRecords'#midnight to midnight (all else use 0500 offset)
query_hash[:dbqs] = 'disabilityBenefitsQuestionnaires'
query_hash[:vbms] = 'serviceTreatmentRecords.subscriptions'
query_hash[:ecfts] = 'electronicCaseFiles'
query_hash[:immunizations] = 'immunizations'
query_hash[:direct_msg] = 'directSecureMessaging.cda'

=begin
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
=end

=begin
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

=end
=begin
def process_rpt(query_hash)
  reports = {}
  (1..@@days_back).to_a.reverse.each do |day_index|
    time = Time.at(@@rpt_date.to_i - 24*60*60*day_index)
    reports[time] = {}

    query_hash.each_pair do |rpt_sym, collection|
      dates = date_range(rpt_sym, time)
      esc_query = CGI::escape(QUERY).gsub!('--GTE_DATE--', dates[0]).gsub!('--LTE_DATE--', dates[1])
      url = "#{HOST + QUERY_DB + collection}/count?query=#{esc_query}"
      reports[time][rpt_sym] = execute_query(url)
    end
  end
  reports
end
=end

def build_rpt(date, rpt_hash)
  template = %{
<h4>#{date.strftime('%A %B %d, %Y')}</h4>
<ul>
<li>STRs: Downloaded #{rpt_hash[:haims]["count"] > 0 ? rpt_hash[:haims]["count"] : 'zero'} STR documents from HAIMS</li>
<li>STR Subscriptions: Received #{rpt_hash[:vbms]["count"] > 0 ? rpt_hash[:vbms]["count"] : 'zero'} STR subscriptions from VBMS</li>
<li>DBQs: Received #{rpt_hash[:dbqs]["count"] > 0 ? rpt_hash[:dbqs]["count"] : "zero"} DBQs from CAPRI and external vendors</li>
<li>eCFT: Received #{rpt_hash[:ecfts]["count"] > 0 ? rpt_hash[:ecfts]["count"] : "zero"} eCFT documents</li>
<li>Immunizations: Received #{rpt_hash[:immunizations]["count"] > 0 ? rpt_hash[:immunizations]["count"] : "zero"} immunizations (C32s) from Walgreens</li>
<li>Direct Secure Messaging Documents: Received #{rpt_hash[:direct_msg]["count"] > 0 ? rpt_hash[:direct_msg]["count"] : "zero"} DSM documents</li>
</ul>
  }
end

TABLE = %{
  <div class="rpt">
  <div class="rpt_display">
  <table class="display"><tr><th width="275px" style="text-align: left"><br>Document Description</th><th>DATE</th><th>DATE</th><th>DATE</th><th>DATE</th><th>DATE</th><th>DATE</th><th>DATE</th></tr>
  <tr class="odd"><td style="text-align:left">STRs Downloaded from HAIMS</td><td>_HAIMS</td><td>_HAIMS</td><td>_HAIMS</td><td>_HAIMS</td><td>_HAIMS</td><td>_HAIMS</td><td>_HAIMS</td></tr>
  <tr class="even"><td style="text-align:left">STR Subscriptions from VBMS</td><td>_VBMS</td><td>_VBMS</td><td>_VBMS</td><td>_VBMS</td><td>_VBMS</td><td>_VBMS</td><td>_VBMS</td></tr>
  <tr class="odd"><td style="text-align:left">DBQs from CAPRI and External Vendors</td><td>_DBQS</td><td>_DBQS</td><td>_DBQS</td><td>_DBQS</td><td>_DBQS</td><td>_DBQS</td><td>_DBQS</td></tr>
  <tr class="even"><td style="text-align:left">eCFTs Received</td><td>_ECFTS</td><td>_ECFTS</td><td>_ECFTS</td><td>_ECFTS</td><td>_ECFTS</td><td>_ECFTS</td><td>_ECFTS</td></tr>
  <tr class="odd"><td style="text-align:left">Immunizations (C32s) from Walgreens</td><td>_IMMUNE</td><td>_IMMUNE</td><td>_IMMUNE</td><td>_IMMUNE</td><td>_IMMUNE</td><td>_IMMUNE</td><td>_IMMUNE</td></tr>
  <tr class="even"><td style="text-align:left">Direct Secure Messaging Documents</td><td>_DSMDS</td><td>_DSMDS</td><td>_DSMDS</td><td>_DSMDS</td><td>_DSMDS</td><td>_DSMDS</td><td>_DSMDS</td></tr>
  </table>
  </div>
  </div>
}

def build_rpt_table(date, rpt_hash)
  @final_rpt.sub!(/DATE/, date.strftime('%A<br>%b %d, %Y'))
  @final_rpt.sub!(/_HAIMS/, rpt_hash[:haims]["count"].to_s)
  @final_rpt.sub!(/_VBMS/, rpt_hash[:vbms]["count"].to_s)
  @final_rpt.sub!(/_DBQS/, rpt_hash[:dbqs]["count"].to_s)
  @final_rpt.sub!(/_ECFTS/, rpt_hash[:ecfts]["count"].to_s)
  @final_rpt.sub!(/_IMMUNE/, rpt_hash[:immunizations]["count"].to_s)
  @final_rpt.sub!(/_DSMDS/, rpt_hash[:direct_msg]["count"].to_s)
end

@final_rpt = TABLE.clone
process_rpt(query_hash).each_pair do |date, rpt_hash|
  # @final_rpt << build_rpt(date, rpt_hash)
  build_rpt_table(date, rpt_hash)
end
rescue => e
  @final_rpt = e.backtrace.join("\n")
end

@final_rpt
