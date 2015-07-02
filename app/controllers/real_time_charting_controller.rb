class RealTimeChartingController < ApplicationController
  skip_before_filter :login_required, :only => [:real_time_data]

  @@db = nil
  @@collection = nil

  def self.initialize_collection
    return unless (@@db.nil?)
    @@db = Mongoid::Sessions::Factory.create($application_properties['real_time_session'].to_sym)
    @@collection = @@db[$application_properties['real_time_collection'].to_sym]
  end

  def real_time_chart
    @json_data_hash = {}
    RealTimeChartingController.initialize_collection
    @json_data_hash[:chart_title] = $application_properties['chart_title']
    @json_data_hash[:x_title] = $application_properties['x_title']
    @json_data_hash[:y_title] = $application_properties['y_title']
    @json_data_hash[:time_span] = $application_properties['time_span']
    @json_data_hash[:refresh_interval] = $application_properties['real_time_refresh_interval_secs'].to_i
    @json_data_hash[:element_description] = $application_properties['element_description'].split(',')

    begin
      docs = @@collection.find({}).entries
      @json_data_hash[:real_time_data] = docs
    rescue => ex
      $logger.error("Something went wrong in the real time charting controller the exception trace is:")
      $logger.error ex.backtrace.join("\n")
      $logger.error("Resetting the mongo data connection")
      @@db = nil
    end

    respond_to do |format|
      format.html
      format.json { render :json => @json_data_hash[:real_time_data].to_json }
    end
  end
end
