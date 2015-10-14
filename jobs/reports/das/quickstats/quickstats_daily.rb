require './jobs/helpers/mongo_job_connector'
require './jobs/helpers/report_helper'
require './jobs/reports/das/daily/affordable_care_act'
require 'date'
require 'erb'
include MongoJobConnector
include ReportHelper
include AffordableCareAct

@rpt_date = ARGV[0]
lookback = ARGV[1].to_i
env = ARGV[2].to_sym
plink = ARGV[3]

# establish mongo connections das core
initialize_mongo env
@core_db = get_db(:core)

def load_rpt_data(startdate, enddate, collection)
  match = {"$match" => {:uploadDate => {"$gte" => startdate, "$lt" => enddate}}}
  project = {"$project" => {"year" => { "$year" => "$uploadDate"}, "month" => { "$month" => "$uploadDate"}, "day" => { "$dayOfMonth" => "$uploadDate"}}}
  group = {"$group" => {"_id" => {"year" => "$year", "month" => "$month", "day" => "$day"}, "daily_count" => { "$sum" => 1 }}}
  sort = {"$sort" => {"_id" => 1}}

  query = @core_db[collection].aggregate([match, project, group, sort])

  # iterate the results setting the counts into the hash
  query.each do |doc|
    dt = Date.new(doc[:_id][:year],doc[:_id][:month],doc[:_id][:day])
    count = doc[:daily_count].to_i
    @data[dt][collection] = count if @data.has_key?(dt)
  end
end

rpt_date = Date.parse(@rpt_date)
dates = []

(0...lookback).each do |i|
  dates << rpt_date - i
end

dates.reverse!
@collections = [
    :serviceTreatmentRecords,
    :"serviceTreatmentRecords.subscriptions",
    :disabilityBenefitsQuestionnaires,
    :electronicCaseFiles,
    :immunizations,
    :"directSecureMessaging.cda"
]

@data = {}
dates.each do |d|
  @data[d] = {}
  @collections.each do |col|
    @data[d][col] = 0
    @data[d][:aca] = AffordableCareAct.get_aca_daily_count(plink, d.to_s)
  end
end

@collections.each do |col|
  load_rpt_data(dates[0], dates[-1] + 1, col)
end

# print out the report results
puts "EMAIL_RESULT_BELOW:\n"
puts "SUBJECT: Rolling Week DAS Quickstats Summary - #{format_date(@rpt_date, RPT_DATE)}"
puts render_erb('./jobs/reports/das/quickstats/quickstats.html.erb')
puts "EMAIL_RESULT_ABOVE:\n"

# disconnect all data sources
disconnect_all
