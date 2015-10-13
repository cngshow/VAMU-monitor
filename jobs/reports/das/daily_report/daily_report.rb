require 'json'
require './jobs/helpers/mongo_job_connector'
require './jobs/helpers/report_helper'
require './jobs/helpers/job_utility'
require './jobs/reports/das/daily_report/daily_report_helper'
require 'date'
require 'erb'
include MongoJobConnector
include ReportHelper
include JobUtility
include DailyReportHelper

rpt_date = ARGV[0]
if rpt_date =~ /(\d{4})(\d{2})(\d{2})/
  rpt_date = "#{$1}-#{$2}-#{$3}"
else
  rpt_date = nil
end

@rpt_output_html = ARGV[1]
@root_url = ARGV[2]
@jle_id = ARGV[3]
env = ARGV[4].to_sym
@plink = ARGV[5]

@rpt_link_url = "#{@root_url}/view_multiple/#{@jle_id}/"

# establish mongo connections to vamu and core
initialize_mongo env

@vamu_audit_db = get_db(:vamu_audit)
@core_db = get_db(:core)

@collection = @vamu_audit_db[:str_dbq_daily_report]

#HAIMS hour translation hash
offset = 4
HOUR_TRANSLATION_HASH = {}
(24..47).to_a.each do |i|
  HOUR_TRANSLATION_HASH[i - 24] = (i-offset)%24
end

def write_rpt_data(rpt_date)
  if rpt_date.is_a?(Time.class)
    rpt_date = format_date(rpt_date, RPT_DATE)
  end

  eastern_offset = Time.parse(rpt_date).dst? ? 4 : 5
  putty = %{#{@plink} dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123! \"cd audit && python ./dailyReports-vamu.py '#{rpt_date}' #{eastern_offset.to_s}\"}
  # putty = %{#{@plink} dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123! \"cd audit && python ./dailyReports-gpb.py '#{rpt_date}'\"}
  str = backtick(putty)
  str = str.split("\n")

  data_hash = {}
  dt = Date.parse(rpt_date)
  data_hash[:_id] = Time.gm(dt.year, dt.month, dt.day)
  data_hash[:job_code] = "dailyReport"
  data_hash[:rpt_date_string] = rpt_date
  data_hash[:create_ts] = Time.now
  data_hash[:str] = {}
  data_hash[:dbq] = {}
  data_hash[:storage] = {}
  str_hourly_hash = {}

  str.each do |line|
    if (line =~ /Total size of fs.files:\s+(\d+)/)
      data_hash[:dbq][:fs_size] = $1.to_i
    elsif (line =~ /Total Subscriptions:\s+(\d+)/)
      data_hash[:str][:tot_subscriptions] = $1.to_i
    elsif (line =~ /Total size of STR attachments:\s+(\d+)/)
      data_hash[:str][:tot_str_attachments] = $1.to_i
    elsif (line =~ /Total STRs:\s+(\d+)\s+STR Documents for.*?(\d+)/)
      data_hash[:str][:tot_str_count] = $1.to_i
      data_hash[:str][:tot_str_vet_count] = $2.to_i
    elsif (line =~ /Yesterday's STRs:\s+(\d+)\s+STR documents.*?(\d+)/)
      data_hash[:str][:yesterday_count] = $1.to_i
      data_hash[:str][:yesterday_vet_count] = $2.to_i
    elsif (line =~ /^Administrative - STR AHLTA.pdf.*?(\d+).*?(\d+)/)
      data_hash[:str][:ahlta_pdf_tot] = $1.to_i
      data_hash[:str][:ahlta_pdf_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Administrative.*?(\d+).*?(\d+)/)
      data_hash[:str][:admin_doc_tot] = $1.to_i
      data_hash[:str][:admin_doc_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Dental Record Part 1.*?(\d+).*?(\d+)/)
      data_hash[:str][:dental_part1_tot] = $1.to_i
      data_hash[:str][:dental_part1_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Dental Record Part 2.*?(\d+).*?(\d+)/)
      data_hash[:str][:dental_part2_tot] = $1.to_i
      data_hash[:str][:dental_part2_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Dental Record Part 3.*?(\d+).*?(\d+)/)
      data_hash[:str][:dental_part3_tot] = $1.to_i
      data_hash[:str][:dental_part3_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Dental Record Part 4.*?(\d+).*?(\d+)/)
      data_hash[:str][:dental_part4_tot] = $1.to_i
      data_hash[:str][:dental_part4_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR HRR.*?(\d+).*?(\d+)/)
      data_hash[:str][:hrr_tot] = $1.to_i
      data_hash[:str][:hrr_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Medical Record Part 1.*?(\d+).*?(\d+)/)
      data_hash[:str][:medical_part1_tot] = $1.to_i
      data_hash[:str][:medical_part1_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Medical Record Part 2.*?(\d+).*?(\d+)/)
      data_hash[:str][:medical_part2_tot] = $1.to_i
      data_hash[:str][:medical_part2_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Medical Record Part 3.*?(\d+).*?(\d+)/)
      data_hash[:str][:medical_part3_tot] = $1.to_i
      data_hash[:str][:medical_part3_vet] = $2.to_i
    elsif (line =~ /^Administrative - STR Medical Record Part 4.*?(\d+).*?(\d+)/)
      data_hash[:str][:medical_part4_tot] = $1.to_i
      data_hash[:str][:medical_part4_vet] = $2.to_i
    elsif (line =~ /^Completed.*?(\d+)\sfor\s(\d+).*/)
      data_hash[:dbq][:completed_count] = $1.to_s.to_i(0)
      data_hash[:dbq][:vet_count] = $2.to_i
    elsif (line =~ /^DAS received\s+(\d+)/)
      data_hash[:dbq][:das_count] = $1.to_i
      data_hash[:dbq][:das_line] = line
    elsif (line =~ /^CAPRI submitted\s+(\d+)/)
      data_hash[:dbq][:capri_count] = $1.to_i
      data_hash[:dbq][:capri_line] = line
    elsif (line =~ /^External Vendors submitted\s+(No submissions|\d+)/)
      val = $1
      val = val.eql?("No submissions") ? 0 : val.to_i
      data_hash[:dbq][:external_count] = val
      data_hash[:dbq][:external_vendor_line] = line
    elsif (line =~ /\s*(\d{1,2})\s*:\s*(\d+)/)
      hour = $1.to_i
      cnt = $2.to_i
      k = HOUR_TRANSLATION_HASH[hour]
      str_hourly_hash[k] = cnt
    end
  end

  putty = %{#{@plink} dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123! \"cd audit && python ./storageSizeLogStat.py '#{rpt_date}'\"}
  str = backtick(putty)
  str = str.split("\n")

  storage_data = []
  str.each do |line|
    if (line =~ /^(\d+)/)
      storage_data.push($1.to_i)
    end
  end

  data_hash[:storage] = {}
  data_hash[:storage][:core_used] = storage_data[0]
  data_hash[:storage][:grid_used] = storage_data[1]
  data_hash[:storage][:audit_used] = storage_data[2]

  # get the audit data hourly breakdown for first and second passes
  audit_hash = get_str_audit_hash(rpt_date, data_hash[:str][:yesterday_count])
  audit_hash[:str_docs_saved_hourly] = str_hourly_hash
  data_hash[:audit] = {}
  data_hash[:audit][:breakdown] = audit_hash

  # write the hash to mongo
  @collection.find({_id: data_hash[:_id]}).upsert(data_hash)
end

def write_report(doc)
  @doc = doc
  render_erb('./jobs/reports/das/daily_report/daily_report3.html.erb', {multi_result: true, email_subject: "STR & DBQ Status for: #{@doc[:rpt_date_string]}"})
  @show_charts = true
  rpt_result = render_erb('./jobs/reports/das/daily_report/daily_report.html.erb', {multi_result: true})
  File.open(@rpt_output_html, 'w') { |file| file.write(rpt_result) }
  render_erb('./jobs/reports/das/daily_report/daily_report2.html.erb', {multi_result: true})
  render_erb('./jobs/reports/das/daily_report/daily_report3.html.erb', {multi_result: true})
end

def get_rpt_data(rpt_date)
  d = get_gmt(rpt_date)

  count = @collection.find({_id: d}).count
  write_rpt_data(rpt_date) unless count == 1

  # retrieve and return the report data for the date specified
  @collection.find({_id: d}).limit(1).first
end

def init_load_collection(lookback_days)
  # get the current date and using the lookback days, load the array with strings for each day
  # that needs to have results data saved in YYYY-MM-DD format
  ret = []
  current = Time.now.to_i
  (1..lookback_days).each do |t|
    ret << current - (60*60*24*t)
  end

  # reverse the dates to begin loading the collection from oldest to most current
  ret.reverse!
  ret.map! do |epoch|
    t = Time.at(epoch)
    "#{t.year}-#{'%02d' % t.month}-#{'%02d' % t.day}"
  end

  # iterate over the dates writing the data to the local mongo reporting collection
  ret.each do |d|
    write_rpt_data(d)
  end
end

def call_init_collection?
  @collection.find({}).count == 0
end

def get_last_rpt_doc
  @collection.find({}).sort({_id: -1}).limit(1).first
end

def get_str_daily_count
  @collection.find.select(id: 1, 'str.yesterday_count' => 1).sort({_id: 1})
end

def load_current_data
  # get the last day in the collection and load report data up until yesterday
  doc = get_last_rpt_doc

  # get the current date and stop adding the date to the array once we reach today in UTC
  start = doc[:_id]
  curr_utc = nil

  if (Time.now.to_s =~ /^(\d{4}-\d{2}-\d{2})\s.*/)
    curr_utc = get_gmt($1.to_s)
  end

  # build an array of dates as strings that we need to fill in with
  ret = []
  iter = ((curr_utc - start) /(60*60*24)).to_i - 1

  (1..iter).each do |i|
    d = (start + (60*60*24*i)).to_s
    if (d =~ /^(\d{4}-\d{2}-\d{2})\s.*/)
      ret << $1
    end
  end

  # write out the missing data to mongo for each of the missing dates always including yesterday in case we need an upsert
  yesterday = format_date(curr_utc - (60*60*24), RPT_DATE)
  ret << yesterday if ret.empty?
  ret.each do |rpt_date|
    write_rpt_data(rpt_date)
  end
end

def charting_data_points(sym_chart, rpt_doc)
  case sym_chart
    when :storage_chart
      rpt_date = rpt_doc[:_id]
      prev_day = rpt_date - (60*60*24)
      prev_doc = @collection.find({_id: prev_day}).first
      prev_pts = disk_space_points(prev_doc)
      curr_pts = disk_space_points(rpt_doc)
      return [prev_pts, curr_pts]
  end
end

def disk_space_points(doc)
  ret = {core: {:avail => nil, :used => nil},
         audit: {:avail => nil, :used => nil}}

  core = (doc[:storage][:core_used])/(1024.0**4)#G
  grid = (doc[:storage][:grid_used])/(1024.0**4)#H
  used = core + grid#C
  avail = 20.0 - used#D
  ret[:core][:avail] = avail
  ret[:core][:used] = used

  # get the audit data
  audit_used = (doc[:storage][:audit_used])/(1024.0**4)#L
  audit_avail = 5.1 - audit_used#M
  ret[:audit][:avail] = audit_avail
  ret[:audit][:used] = audit_used
  ret
end

def dbq_chart_points(doc)
  ret = {rpt_date: doc[:_id], dbq_tot_size: 0, dbqs_submitted: 0, capri_count: 0, external_count: 0}
  o = 78851166512+59125820796
  n = doc[:str][:tot_str_attachments]
  m = doc[:dbq][:fs_size]
  q = 42991214320
  p = m - (n + o)
  r = (p + q) / 1024.0**3
  ret[:dbq_tot_size] = r.round(2)
  ret[:dbqs_submitted] = doc[:dbq][:completed_count] + 16447
  ret[:capri_count] = doc[:dbq][:capri_count]
  ret[:external_count] = doc[:dbq][:external_count]
  ret
end

def dbq_data
  ret = []
  @collection.find({}).sort({_id: 1}).each do |doc|
    ret << doc
    break if doc[:_id].eql?(@doc[:_id])
  end
  ret
end

def run_report(rpt_date = nil)
  init_load_collection(85) if call_init_collection?

  if rpt_date
    doc = get_rpt_data(rpt_date)
  else
    load_current_data

    # get the last report data in order to write the current daily report
    doc = get_last_rpt_doc
  end

  write_report(doc)
end

# http://mongoid.org/en/mongoid/docs/querying.html
def str_scatter_plot_query(rpt_date, limit = 1500)
  @core_db["serviceTreatmentRecords"]
      .find(uploadDate: {"$gte" => get_gmt(rpt_date)})
      .select("_id" => 0, "str:ServiceTreatmentRecord.str:Attachments.nc:Attachment.nc:BinarySizeValue" => 1)
      .sort(uploadDate: 1)
      .limit(limit)
end
#mongoimport --vamu_audit_db job_data_development --collection audit_pass --fields dt, status, response, size, pass --type csv --file "C:\Users\VHAISPBOWMAG\Desktop\DAS-reports\STR DQB Daily Reports\STR Audit Daily Master\STR Daily Audit Logs\STR_daily_audit-2015-05-13.txt"

current = Time.now
if rpt_date && get_gmt(rpt_date) >= Time.gm(current.year, current.month, current.day)
  puts "Illegal report date entered. You cannot run this report for today or a future date."
  return
end

run_report(rpt_date)
puts get_multi_result

disconnect_all
