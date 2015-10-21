require './jobs/helpers/report_helper'
require './jobs/helpers/job_utility'
include ReportHelper
include JobUtility

@rpt_date = format_date(ARGV[0], RPT_DATE)
@plink = ARGV[1]

def putty_call(server = 4)
  connect = "dasuser@bhiepapp#{server}.r04.med.va.gov -pw dasprod@123!"
  %{#{@plink} #{connect} \"cat ./reports/output/#{@rpt_date}/summary.#{@rpt_date}\"}
end

papp4 = backtick(putty_call)
papp5 = backtick(putty_call(5))

puts "EMAIL_RESULT_BELOW:\n"
puts "SUBJECT: DAS Daily Transactions Report for #{@rpt_date}"
puts "<pre>#{papp4}</pre>"
puts "<pre>#{papp5}</pre>"
puts 'EMAIL_RESULT_ABOVE:'
