require 'json'
require './jobs/helpers/mongo_job_connector'
require './jobs/helpers/report_helper'
# require './jobs/helpers/job_utility'
# require './jobs/reports/das/daily_report/daily_report_helper'
require 'date'
require 'erb'
include MongoJobConnector
include ReportHelper
# include JobUtility
# include DailyReportHelper

@rpt_date = ARGV[0]
@root_url = ARGV[1]
@jle_id = ARGV[2]
env = ARGV[3].to_sym
@rpt_link_url = "#{@root_url}/view_multiple/#{@jle_id}/1"

# establish mongo connections to vamu and core
initialize_mongo env

@vamu_audit_db = get_db(:vamu_audit)
@core_db = get_db(:core)

def load_rpt_data
  # match everything up until midnight of the day after the report date
  match = {"$match" => {:uploadDate => {"$lte" => get_gmt(@rpt_date)}}} # todo add one to rpt date so it is midnight
  project = {"$project" => {"year" => { "$year" => "$uploadDate"}, "month" => { "$month" => "$uploadDate"}, "day" => { "$dayOfMonth" => "$uploadDate"}}}
  group = {"$group" => {"_id" => {"year" => "$year", "month" => "$month", "day" => "$day"}, "daily_count" => { "$sum" => 1 }}}
  sort = {"$sort" => {"_id" => 1}}

  query = @core_db["immunizations"].aggregate([match, project, group, sort])

  last = query.last
  first = query.first
  last = Date.new(last[:_id][:year],last[:_id][:month],last[:_id][:day])
  first = Date.new(first[:_id][:year],first[:_id][:month],first[:_id][:day])
  days_btw = (last - first).to_i

  #fill in all dates between the first date returned and the report date with zeros
  ret = {}
  (0..days_btw).each do |i|
    ret[first + i] = 0
  end

  # iterate the results setting the counts into the hash
  yearly_totals = {}
  query.each do |doc|
    dt = Date.new(doc[:_id][:year],doc[:_id][:month],doc[:_id][:day])
    count = doc[:daily_count].to_i
    ret[dt] = count
    yearly_totals[doc[:_id][:year]] = 0 unless yearly_totals.has_key?(doc[:_id][:year])
    yearly_totals[doc[:_id][:year]] += count
  end
  # return the hash which includes the total size and counts
  ret[:yearly_summary] = yearly_totals
  ret
end

def get_chart_data(data)
  ret = "[ \n"
  data.each_pair do |k,v|
    break if k.eql?(:yearly_summary)
    dt = "new Date('#{k.strftime('%m/%d/%Y')}')"
    ret << "[#{dt},#{v}],"
  end
  ret.chomp!(",\n")
  ret << "]"
  ret
end

def get_summary_data(data)
  data[:yearly_summary]
end

begin
  @rpt_date = "20140917"
  data = load_rpt_data
  chart = get_chart_data(data)
  summary = get_summary_data(data)
ensure
  disconnect_all
end
