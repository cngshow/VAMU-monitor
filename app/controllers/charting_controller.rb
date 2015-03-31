require 'time'
require './jobs/reports/vdas/das_quickstats_module.rb'

class ChartingController < ApplicationController
  include DasQuickstats
  extend PropHashBuilder

  @@charting_properties = ChartingController.get_prop_hash("./das_charting.properties", $logger)

  def show_chart
    @chart_hash = {}
    @element_description = {}
    data = get_quickstats

    data.each_pair do |time, count_hash|
      time = time.to_i * 1000
      @chart_hash[time] = {}

      count_hash.each_pair do |type, count_hash|
        @element_description[type] = type.to_s.upcase unless @element_description.has_key?(type)
        @chart_hash[time][type] = count_hash["count"]
      end
    end

    @x_title = "Date Range"
    @y_title = "Count"
    @selection_filter= {"ALL" => "All Days",
                        "1" => "1 Day",
                        "2" => "2 Days",
                        "3" => "3 Days",
                        "4" => "4 Days",
                        "5" => "5 Days",
                        "6" => "6 Days",
                        "7" => "7 Days"}

    @title = "Quickstats Rolling Report"
    @time_span =  Time.at(@chart_hash.keys[0]/1000).strftime('%m/%-d/%Y') + " thru " + Time.at(@chart_hash.keys[-1]/1000).strftime('%m/%-d/%Y')
  end

  def get_quickstats
    raise "error getting the charting properties" if @@charting_properties.nil?
    $logger.info 'in charting props'
    host = @@charting_properties['host']
    ecrud = @@charting_properties['ecrud']
    query_hash = {}
    query_hash[:haims] = 'serviceTreatmentRecords'#midnight to midnight (all else use 0500 offset)
    query_hash[:dbqs] = 'disabilityBenefitsQuestionnaires'
    query_hash[:vbms] = 'serviceTreatmentRecords.subscriptions'
    query_hash[:ecfts] = 'electronicCaseFiles'
    query_hash[:immunizations] = 'immunizations'
    query_hash[:direct_msg] = 'directSecureMessaging.cda'
    days_back = @@charting_properties['days_back'].to_i
    rpt_date = Time.now.strftime('%Y%m%d')
    a = Date.strptime(rpt_date, '%Y%m%d').to_time
    data = process_rpt(query_hash, host, ecrud, days_back, a)
    data
  end

  def show_chart_google
    show_chart
  end
end
