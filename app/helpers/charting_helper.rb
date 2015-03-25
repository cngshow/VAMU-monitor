module ChartingHelper
  def add_columns

  end
  def add_rows
    ret = ""
    @chart_hash.each_pair do |epoch, data_hash|
      ret << "[new Date(#{epoch}),#{data_hash.values.join(",")}],\n"
    end
    ret
  end
end
