require 'json'

class AndroidTrackableController < ApplicationController

  def list
    trackables = JobEngine.instance.get_trackable_jobs
    android_json_data = {}
    trackables.each do |job_metadata|
      entry = {}
      jle = job_metadata.get_last_completed_job_log_entry
      next if jle.nil?
      jle_jc = jle.job_code
      android_json_data[jle_jc] = entry
      #entry[:job_code] = jle_jc
      entry[:jle_id] = jle.id
      entry[:job_metadata_id] = job_metadata.id
      entry[:short_description] = job_metadata.short_desc
      entry[:long_description] = job_metadata.description
      entry[:last_completed] = jle.finish_time
      entry[:status] = jle.status
      alert_start_jle = JobLogEntry.get_last_tracked_status_change(jle_jc)
      alert_start = alert_start_jle.nil? ? '' : alert_start_jle.finish_time
      elapsed_time = alert_start_jle.nil? ? '' : convert_seconds_to_time(Time.now - alert_start) unless (!alert_start_jle.nil? && alert_start_jle.finish_time.nil?)
      elapsed_time = "Never Run" if (!alert_start_jle.nil? && alert_start_jle.finish_time.nil?)
      entry[:alert_start] = alert_start
      entry[:elapsed_time] = elapsed_time
      is_html = job_metadata.email_content_type.eql?('text/html')
      job_result = jle.job_result
      regex = Regexp.new(".*OUTPUT_BELOW:\n{0,1}(.*)OUTPUT_ABOVE:\n{0,1}.*", Regexp::MULTILINE)
      if (job_result.match(regex))
        job_result = $1
      end
      regex = Regexp.new(".*(EMAIL_RESULT_BELOW:.*EMAIL_RESULT_ABOVE:).*", Regexp::MULTILINE)
      if (job_result.match(regex))
        job_result = $1
      end
      regex = Regexp.new(".*(<[hH][tT][mM][lL]>.*<\/[hH][tT][mM][lL]>).*", Regexp::MULTILINE)
      if (job_result.match(regex))
        job_result = $1
      end
      entry[:is_html] = is_html.to_s
      entry[:job_result] = job_result
      entry[:url] = $application_properties['root_url'] + job_log_entry_path(jle.id)
      #android_json_data << entry
    end
    render :text => android_json_data.to_json
  end
end
