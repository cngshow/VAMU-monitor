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
    RealTimeChartingController.initialize_collection
    @title = 'DAS Documents - Mocked Real Time Transactions.'
    @x_title = 'Time'
    @y_title = 'Transaction Count'
    @time_span= ''
    @update_interval = 10*1000
    @element_description = ["DAS Documents"]
      begin
        @docs = @@collection.find({}).entries
      rescue => ex
        $logger.error("Something went wrong in the real time charting controller the exception trace is:")
        $logger.error ex.backtrace.join("\n")
        $logger.error("Resetting the mongo data connection")
        @@db = nil
      end

    respond_to do |format|
      format.html
      format.json { render :json => @docs.to_json }
    end
  end

end