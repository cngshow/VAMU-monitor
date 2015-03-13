class ChartingController < ApplicationController
  def show_chart
    @x_title = "Time"
    @y_title = "Count"
    @chart_hash = {}
    #keep @selection_filter in sync with @element_description
    @selection_filter= {"ALL" => "All Days",
                        "1" => "1 Day",
                        "2" => "2 Days",
                        "3" => "3 Days",
                        "4" => "4 Days",
                        "5" => "5 Days",
                        "6" => "6 Days",
                        "7" => "7 Days"}
    @element_description = {cats: "The Cats!!!", dogs: "The dogs!!!"}
    # @chart_hash[Time.now.to_i * 1000] = 5
    # @chart_hash[Time.now.to_i * 1000 + 100000] = 15
    # @chart_hash[1.hour.ago.to_i * 1000] = 10
    # @chart_hash[1.month.ago.to_i * 1000] = 18
    # @chart_hash[1.month.from_now.to_i * 1000] = 18
    past = 1.month.ago
    past_date = Time.now
    past = past_date.to_i#past.to_i- past.hour*60*60 - past.min*60 - past.sec
    (1..288*10).to_a.each do |i|
      @chart_hash[(past - 5*60*i) * 1000] = {cats: rand(100)}
      @chart_hash[(past - 5*60*i) * 1000][:dogs] = rand(100)
    end
    @title = "Sample chart "
    @time_span =  Time.at(@chart_hash.keys[-1]/1000).to_s + " -- " + Time.at(@chart_hash.keys[0]/1000).to_s
  end


  def show_chart_google
    show_chart
  end

end
