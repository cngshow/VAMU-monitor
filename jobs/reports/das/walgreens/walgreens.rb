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
  rpt_date_gmt = Date.parse(@rpt_date) + 1
  match = {"$match" => {:uploadDate => {"$lte" => rpt_date_gmt}}} # todo add one to rpt date so it is midnight
  project = {"$project" => {"year" => { "$year" => "$uploadDate"}, "month" => { "$month" => "$uploadDate"}, "day" => { "$dayOfMonth" => "$uploadDate"}}}
  group = {"$group" => {"_id" => {"year" => "$year", "month" => "$month", "day" => "$day"}, "daily_count" => { "$sum" => 1 }}}
  sort = {"$sort" => {"_id" => 1}}

  query = @core_db["immunizations"].aggregate([match, project, group, sort])

  first = query.first
  last = Date.parse(@rpt_date)
  first = Date.new(first[:_id][:year],first[:_id][:month],first[:_id][:day])
  days_btw = (last - first).to_i

  #fill in all dates between the first date returned and the report date with zeros
  ret = {}
  (0..days_btw).each do |i|
    ret[first + i] = 0
  end

  # iterate the results setting the counts into the hash
  rpt_summary = {}
  query.each do |doc|
    dt = Date.new(doc[:_id][:year],doc[:_id][:month],doc[:_id][:day])
    count = doc[:daily_count].to_i
    ret[dt] = count
    rpt_summary[doc[:_id][:year]] = 0 unless rpt_summary.has_key?(doc[:_id][:year])
    rpt_summary[doc[:_id][:year]] += count
  end
  # return the hash which includes the total size and counts
  rpt_summary[:total] = rpt_summary.values.inject {|sum, yearly_total| sum + yearly_total }
  rpt_summary[:rpt_date_count] = ret.values.last
  ret[:summary] = rpt_summary
  ret
end

def get_chart_data
  ret = "[ \n"
  @walgreens_data.each_pair do |k,v|
    break if k.eql?(:summary)
    dt = "new Date('#{k.strftime('%m/%d/%Y')}')"
    ret << "[#{dt},#{v}],\n"
  end
  ret.chomp!(",\n")
  ret << "]"
  ret
end

def get_summary_data
  @walgreens_data[:summary]
end

begin
  @rpt_date = "20150622"
  @walgreens_data = load_rpt_data
  render_erb('./jobs/reports/das/walgreens/walgreens.html.erb', {multi_result: true, email_subject: "Walgreens Immunization Report for: #{@rpt_date}"})
  @include_chart = true
  render_erb('./jobs/reports/das/walgreens/walgreens.html.erb', {multi_result: true})
  puts get_multi_result
ensure
  disconnect_all
end
