require 'date'
require 'time'
require 'cgi'
require 'json'
require 'uri'
require 'net/http'
require './jobs/reports/vdas/das_quickstats_module'
require './jobs/ruby/helpers/logger_helper'
require './lib/prop_loader'

include JobLogging
include DasQuickstats
extend PropHashBuilder

begin
  QUERY = '{"uploadDate":{"$gte":"$Date(--GTE_DATE--)","$lt":"$Date(--LTE_DATE--)"}}'

  @log_path = "./log/quickstats.log"
  $logger = get_logger(@log_path, "VDAS_QUICKSTATS", :DEBUG, true)

# reporting date
  @@rpt_date = Date.strptime(ARGV.shift, '%Y%m%d').to_time

# reporting days back
  @@days_back = ARGV.shift.to_i

  query_hash = {}
  query_hash[:haims] = 'serviceTreatmentRecords' #midnight to midnight (all else use 0500 offset)
  query_hash[:dbqs] = 'disabilityBenefitsQuestionnaires'
  query_hash[:vbms] = 'serviceTreatmentRecords.subscriptions'
  query_hash[:ecfts] = 'electronicCaseFiles'
  query_hash[:immunizations] = 'immunizations'
  query_hash[:direct_msg] = 'directSecureMessaging.cda'

  def build_rpt(date, rpt_hash)
 %{
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

  prop_hash = get_prop_hash("./das_charting.properties", $logger)
  @final_rpt = TABLE.clone
  host = prop_hash["host"] #https://bhiepapp4.r04.med.va.gov/"
  ecrud = prop_hash["ecrud"] #"ecrud/v1/core/"

  process_rpt(query_hash, host, ecrud, @@days_back, @@rpt_date).each_pair do |date, rpt_hash|
    build_rpt_table(date, rpt_hash)
  end
rescue => e
  @final_rpt = e.backtrace.join("\n")
end

@final_rpt
