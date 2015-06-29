module RealTimeChartingHelper
  def add_rows
    ret = ""
    @docs.each do |doc|
      ret << "[new Date(#{doc['end_time_epoch']}),#{doc['Total_Count']}],\n"
    end
    ret.chomp!.chop!
  end
end
