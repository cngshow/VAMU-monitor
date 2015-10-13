require './jobs/helpers/report_helper'
require './jobs/helpers/job_utility'
include ReportHelper
include JobUtility

module AffordableCareAct
  def self.get_aca_daily_count(plink, rpt_date)
    dt = format_date(rpt_date, RPT_DATE)
    cms_to_das = 0
    (4..5).each do |i|
      connect = "dasuser@bhiepapp#{i.to_s}.r04.med.va.gov -pw dasprod@123!"
      putty = %{#{plink} #{connect} \"cat ./reports/output/#{dt}/summary.#{dt}\"}
      str = backtick(putty)
      str =~ /^ACA - CMS to DAS: Transactions\s+(\d+)$/
      cms_to_das += $1.to_i
    end
    {cms_to_das: cms_to_das}
  end
end

# puts AffordableCareAct.get_aca_daily_count('c:\putty\plink', '20150921')
