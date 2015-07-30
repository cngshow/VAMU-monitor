module RealTimeChartingHelper
  def add_rows
    ret = ""
    @json_data_hash[:real_time_data].each do |doc|
      ret << "[new Date(#{doc['end_time_epoch']}),#{doc['Total_Count']}],\n"
    end
    ret.chomp!.chop!
  end
end
