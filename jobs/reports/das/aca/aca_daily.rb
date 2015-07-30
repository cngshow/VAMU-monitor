require 'date'
require 'pathname'
# require 'json'
# require './jobs/helpers/mongo_job_connector'
require './jobs/helpers/job_utility'
require './jobs/helpers/report_helper'
require 'erb'
# include MongoJobConnector
include ReportHelper
include JobUtility

def gather_counts(file_path, ret = {})
  idx = 0
  regex = /^\[(.*)\sINFO.*SoapProcessor\s-\s(.*):\s(.*)$/
  req_regex = /.*request.*/
  resp_regex = /.*response.*/

# [2014-10-06T14:02:40,428-0400 INFO ]: PROXY gov.va.das.proxy.util.SoapProcessor - f67a8802-4d82-11e4-a086-e7ea76e1c0f3: sending request...
# [2014-10-06T14:02:41,121-0400 INFO ]: PROXY gov.va.das.proxy.util.SoapProcessor - f67a8802-4d82-11e4-a086-e7ea76e1c0f3: got response......
  File.open(file_path, 'r').each_line do |line|
    idx += 1
    if line =~ regex
      dt = $1
      id = $2
      action = $3

      dt = DateTime.parse(dt)
      key = dt.to_date

      if ret[key].nil?
        ret[key] = {}
        ret[key][:req_count] = 0
        ret[key][:resp_count] = 0
      end
      ret[key][:req_count] += 1 if action =~ req_regex
      ret[key][:resp_count]+= 1 if action =~ resp_regex
    end
  end
  ret
end

def get_chart_data
  ret = "[ \n"
  @aca_data.each_pair do |k,v|
    dt = "new Date('#{k.strftime('%m/%d/%Y')}')"
    ret << "[#{dt},#{v[:req_count]}, #{v[:resp_count]}],\n"
  end
  ret.chomp!(",\n")
  ret << "]"
  ret
end

logpaths = []
(1..2).each do |i| # change to 5
  (1..10).each do |log_num| # change to 10
    logpaths << "logs/ms2.0#{i}/das/proxy.log.#{log_num}"
  end
end

@plink = 'c:\\putty\\plink'
@aca_data = {}

(4..4).each do |i| #change to 4..5 for papp5 logs
  logpaths.each do |log|
    putty = %{#{@plink} dasuser@bhiepapp#{i}.r04.med.va.gov -pw dasprod@123! cat #{log} > c:\\temp\\temp.log}
    `#{putty}`#todo can't use backtick because it reads the file as a string
    @aca_data = gather_counts('c:\\temp\\temp.log', @aca_data)
    puts putty + "\n"
  end
  @aca_data
end


# ret = gather_counts('c:\temp\proxy.log.10')
# @aca_data = gather_counts('c:\temp\proxy.log.9', ret)

# puts get_chart_data

puts render_erb('./jobs/reports/das/aca/aca_daily.html.erb')
