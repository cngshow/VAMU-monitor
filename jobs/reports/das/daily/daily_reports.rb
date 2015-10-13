require 'json'
require './jobs/helpers/mongo_job_connector'
require './jobs/helpers/report_helper'
require './jobs/helpers/job_utility'
require './jobs/reports/das/daily/str/str_audit_daily'
require './jobs/reports/das/daily/storage/das_storage'
require './jobs/reports/das/daily/dbq/dbq_daily'
require 'date'
require 'erb'
include MongoJobConnector
include ReportHelper
include JobUtility
include StrAuditDaily

def run_daily_report
  ret = ''
  if @run_as.eql?('AGGREGATION')
    # iterate over the dates writing the data to the local mongo reporting collection
    @agg_dates.each do |d|
      write_rpt_data(d)
    end
    ret = "Daily report aggregation ran for reporting period from #{@agg_dates[0]} to #{@agg_dates[-1]}"
  else
    # run the individual report based on the one and only agg_date
    doc = get_rpt_data(@agg_dates[0])
    write_report(doc)
    ret = get_multi_result
  end
  ret
end

def connect_to_mongo
  # establish mongo connections to vamu and core
  initialize_mongo @env
  @vamu_audit_db = get_db(:vamu_audit)
  @core_db = get_db(:core)
  @collection = @vamu_audit_db[:str_dbq_daily_report]
end

def putty_call(script_and_args)
  connect = 'dasuser@bhiepapp4.r04.med.va.gov -pw dasprod@123!'
  %{#{@plink} #{connect} \"cd audit && python #{script_and_args}\"}
end

# write the aggregated daily report data to vamu_daily_report collection
def write_rpt_data(rpt_date)
  if rpt_date.is_a?(Time.class)
    rpt_date = format_date(rpt_date, RPT_DATE)
  end

  putty = putty_call("./dailyReports-vamu.py '#{rpt_date}'") #%{#{@plink} #{PUTTY_CONNECT} \"cd audit && python ./dailyReports-vamu.py '#{rpt_date}'\"}
  str = backtick(putty)
  str = str.split("\n")

  data_hash = {}
  dt = Date.parse(rpt_date)
  data_hash[:_id] = Time.gm(dt.year, dt.month, dt.day)
  data_hash[:job_code] = "dailyReport" #todo remove this?
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
      # k = HOUR_TRANSLATION_HASH[hour] was for key - we are not adjusting the time
      str_hourly_hash['%02d' % hour] = cnt
    end
  end

  putty = putty_call("./storageSizeLogStat.py '#{rpt_date}'")
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
  data_hash[:str][:audit] = {}
  data_hash[:str][:audit][:breakdown] = audit_hash

  # write the hash to vamu mongo reporting collection
  @collection.find({_id: data_hash[:_id]}).upsert(data_hash)
end

def write_report(doc)
  @doc = doc
  @show_charts = false

  case @run_as
    when :STR
      render_erb('./jobs/reports/das/daily/str/str_daily.html.erb', {multi_result: true, email_subject: "Daily Service Treatment Record (STR) Report for: #{@doc[:rpt_date_string]}"})
      @show_charts = true
      render_erb('./jobs/reports/das/daily/str/str_daily.html.erb', {multi_result: true})
    when :DBQ
      render_erb('./jobs/reports/das/daily/dbq/dbq_daily.html.erb', {multi_result: true, email_subject: "Daily Disability Benefits Questionnaire (DBQ) Report for: #{@doc[:rpt_date_string]}"})
      @show_charts = true
      render_erb('./jobs/reports/das/daily/dbq/dbq_daily.html.erb', {multi_result: true})
    when :STORAGE
      render_erb('./jobs/reports/das/daily/storage/das_storage.html.erb', {multi_result: true, email_subject: "Daily Storage Utilization Report for: #{@doc[:rpt_date_string]}"})
      @show_charts = true
      render_erb('./jobs/reports/das/daily/storage/das_storage.html.erb', {multi_result: true})
    when :HAIMS
      render_erb('./jobs/reports/das/daily/str/str_daily.html.erb', {multi_result: true, email_subject: "Daily Service Treatment Record (STR) Report - HAIMS Daily for: #{@doc[:rpt_date_string]}"})
      @show_charts = true

      # write the output html for emailing as an attachment
      File.open(@rpt_output_html, 'w') do |file|
        rpt_result = render_erb('./jobs/reports/das/daily/str/str_daily.html.erb')
        file.write(rpt_result)
      end
    else
      raise "Invalid configuration. The run_types for daily reports should include STR, DBQ, STORAGE, and HAIMS. #{@run_as} is not supported."
  end
end

def rpt_date_exists?(rpt_date)
  @collection.find({_id: get_gmt(rpt_date)}).count == 1
end

def get_rpt_data(rpt_date)
  # retrieve and return the report data for the date specified
  @collection.find({_id: get_gmt(rpt_date)}).limit(1).first if rpt_date_exists?(rpt_date)
end

def get_init_load_dates(lookback_days)
  current = Time.now.to_date
  start = current - lookback_days
  get_rpt_date_args(start, current, true, false)
end

def call_init_collection?
  @collection.find({}).count == 0
end

def get_last_rpt_doc
  @collection.find({}).sort({_id: -1}).limit(1).first
end

def get_rpt_date_args(start, enddt, includeStart = true, includeEnd = true)
  start = Date.parse(start) if start.is_a?(String)
  enddt = Date.parse(enddt) if enddt.is_a?(String)

  # build an array of dates as strings that we need to fill in with
  ret = []
  iter = (enddt - start).to_i - (includeEnd ? 0 : 1)
  st = includeStart ? 0 : 1

  (st..iter).each do |i|
    d = format_date((start + i).to_s, RPT_DATE).strip
    if (d =~ /^(\d{4}-\d{2}-\d{2})/)
      ret << $1
    end
  end
  ret
end

def get_current_load_dates
  # get the last day in the collection and load report data up until yesterday
  doc = get_last_rpt_doc

  # get the current date and stop adding the date to the array once we reach today in UTC
  start = doc[:_id]
  curr_utc = nil

  if Time.now.to_s =~ /^(\d{4}-\d{2}-\d{2})\s.*/
    curr_utc = get_gmt($1.to_s)
  end
  get_rpt_date_args(start.to_s, curr_utc.to_s, false, false)
end

@env = ARGV[0].to_sym
@run_as = ARGV[1].to_sym
@agg_dates = []

begin
  connect_to_mongo

  #mongoimport --vamu_audit_db job_data_development --collection audit_pass --fields dt, status, response, size, pass --type csv --file "C:\Users\VHAISPBOWMAG\Desktop\DAS-reports\STR DQB Daily Reports\STR Audit Daily Master\STR Daily Audit Logs\STR_daily_audit-2015-05-13.txt"

  if @run_as.eql?(:AGGREGATION)
    agg_range = ARGV[2]
    @plink = ARGV[3]

    if agg_range.eql? 'AGGREGATE_RANGE'
      if call_init_collection?
        @agg_dates = get_init_load_dates(100)
      else
        @agg_dates = get_current_load_dates
      end
    else
      dates = agg_range.split('-')
      start = dates[0]
      enddt = dates[1]
      raise "Invalid report date range. The start date #{start} cannot be greater than the end date #{enddt}." if Date.parse(start) > Date.parse(enddt)
      raise "Invalid report date range. The start date #{start} cannot be today or in the future." if invalid_rpt_date?(start)
      raise "Invalid report date range. The end date #{start} cannot be today or in the future." if invalid_rpt_date?(enddt)
      @agg_dates = get_rpt_date_args(start, enddt)
    end
    # write the aggregate data for each entry in the agg_dates array
    @agg_dates.each {|d| write_rpt_data(d)}
  else
    rpt_date = format_date(ARGV[2], RPT_DATE)
    raise "Invalid report date entered. The reporting date #{rpt_date} cannot be today or in the future." if invalid_rpt_date?(rpt_date)

    if rpt_date_exists?(rpt_date)
      @agg_dates << rpt_date
      @root_url = ARGV[3]
      @jle_id = ARGV[4]
      @rpt_link_url = "#{@root_url}/view_multiple/#{@jle_id}/"
      @rpt_output_html = ARGV[5]
    else
      raise "The aggregated data does not exist for the reporting date #{rpt_date}. Please contact the VAMU administrator to have the data gathererd for this report date."
    end

    # run the daily report writing the output to standard out to be captured as the job result
    puts run_daily_report
  end
rescue RuntimeError => ex
    puts ex.to_s
ensure
  # disconnect all mongo connections
  disconnect_all
end
