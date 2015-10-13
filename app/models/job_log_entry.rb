require 'monitor'
require 'helpers'

class JobLogEntry
  include PSTConstants
  include Mongoid::Document
  include Mongoid::Timestamps
  store_in :collection => "job_log_entries"

  field :job_code
  field :run_by, :default => PST_SYSTEM
  field :start_time, :type => Time
  field :finish_time, :type => Time, :default => nil
  field :job_result, :default => nil
  field :email_to, :default => nil
  field :email_cc, :default => nil
  field :email_sent, :type => Boolean, :default => false
  field :run_status, :default => PST_PENDING
  field :status_changed, :type => Boolean, :default => false
  field :run_data, :default => nil
  field :introscope_data, :default => nil
  field :status, :default => nil
  field :status_cnt, :type => Integer, :default => nil

  index({finish_time: -1})
  index({finish_time: -1, job_code: 1})
  index({finish_time: -1, run_status: 1})
  index({finish_time: -1, run_status: 1, job_code: 1})
  index({start_time: -1})
  index({run_status: 1})
  index({status_changed: 1})
  index({job_code: 1})
  JobLogEntry.create_indexes
  alias_attribute :id, :_id

  # named scopes building blocks
  scope :job_code, -> job_code {where(job_code: job_code)}
  scope :status_completed, -> bool {where(bool ? {:run_status => PST_COMPLETED} : {:run_status.ne => PST_COMPLETED}) }
  scope :finished, -> bool {where(:finish_time.exists => bool)}
  scope :status_changed, -> bool {where(:status_changed => bool) }
  scope :status_not, -> status {where(:status.ne => status) }
  scope :email_sent, -> bool {where(:email_sent => bool)}
  scope :user_jobs, -> jc {job_code(jc).where(:run_by.ne => PST_SYSTEM)}
  scope :system_jobs, -> {where(:run_by => PST_SYSTEM)}
  scope :started_after, -> time {where(:start_time.gt => time) }
  scope :created_after, -> time {where(:created_at.gt => time) }
  scope :before, -> jle {where(:_id.lt => jle._id, :job_code => jle.job_code).order_by(:_id => :desc) }
  scope :after, -> jle {where(:_id.gt => jle._id, :job_code => jle.job_code).order_by(:_id => :asc) }
  scope :after_inclusive, -> jle {where(:_id.gte => jle._id, :job_code => jle.job_code, :status.ne => PST_UNKNOWN).order_by(:_id => :asc) }
  scope :tracked, -> bool { where(bool ? {:status.in => [PST_RED,PST_GREEN]} : {:status.in => [nil,PST_UNKNOWN]}) }
  scope :youngest, -> {order_by(:finish_time => :desc).limit(1)}
  scope :quick_link_jle, -> job_code {system_jobs(job_code).finished(true).youngest}

  # scopes using building block scopes
  scope :last_tracked_status_change, -> jc, status_known { job_code(jc).finished(true).tracked(status_known).status_changed(true).order_by(:finish_time => :desc).limit(1) }
  scope :job_log_by_jc_desc, -> jc {job_code(jc).order_by(:start_time => :desc) }
  scope :max_finish_for_job_code, -> jc {job_code(jc).finished(true).order_by(:finish_time => :desc) }
  scope :last_tracked_status, -> jc, status_known { job_code(jc).finished(true).tracked(status_known).order_by(:finish_time => :desc).limit(1) }

  @@xml_template = Utilities::FileHelper.file_as_string('./config/IntroscopeAlerts.xml.template')


  #zero based
  def job_result(result_index = 0)
    multiple_regex = $application_properties['job_result_multiple']
    results = []
    true_jobs_result = read_attribute(:job_result)
    if (true_jobs_result =~ /#{multiple_regex}/m)
      results = true_jobs_result.scan(/#{multiple_regex}/m)
      return results[result_index][0]
    end

    return true_jobs_result
  end

  def true_job_result
    read_attribute(:job_result)
  end

  #return nil if jle has a status of green
  def get_escalation
    escalations = JobMetadata.job_code(job_code)[0].escalations

    if finish_time.nil?
      $logger.error("JobLogEntry.get_escalation called on a running job!")
      raise "Illegal to call this method on a running job!" if finish_time.nil?
    end

    return nil unless (status.eql?(PST_RED))
    first_red_jle = JobLogEntry.get_jle_in_sequence(self, :before, true)
    start = self.finish_time
    start = first_red_jle.finish_time unless (first_red_jle.nil? || !first_red_jle.status.eql?(PST_RED))
    finish = self.finish_time
    elapsed_seconds = finish - start
    escalations.each do |esc|
      return esc if (esc.end_min.nil?) #handle red
      return esc if (esc.enabled && ((esc.end_min*60) - elapsed_seconds) >= 0)
    end
    $logger.error("No escalation was found for this red job #{jle.job_code}")
  end

  def self.delete_jles(job_code)
    num = JobLogEntry.delete_all({job_code: job_code})
    num = num.to_s
    puts "#{num} job log entries deleted!"
  end

  def get_email_hash
    body = ''
    subject = ''
    hash = {}
    if (self.job_result =~ /.*EMAIL_RESULT_BELOW:(.*)EMAIL_RESULT_ABOVE:.*/m)
      body = $1
      body =~ /SUBJECT:(.*)/
      subject = $1
      body.sub!("SUBJECT:#{subject}",'')
      hash[:body] = body
      hash[:subject] = subject << " -- (cached result)" unless subject.nil?
      hash[:subject] = "NO subject -- (cached result)" if subject.nil?
    else
      return nil
    end
    hash[:jmd] = JobMetadata.job_code(self.job_code)[0]
    hash[:content_type] = hash[:jmd].email_content_type
    hash[:sending_cached_result] = true
    hash
  end

  def self.is_named_job_running?(jc)
    jl = JobLogEntry.job_code(jc).finished(false).created_after($application_properties['job_runaway_after'].to_i.minutes.ago)
    return !jl.empty?
  end

  def self.get_last_tracked_status(job_code, status_known)
    jl = JobLogEntry.last_tracked_status(job_code,status_known)
    jl[0]
  end

  def self.search(criteria_hash, date_range, page)
    job_code = criteria_hash[:filter_by_job_code]
    job_code = '' if (job_code.nil? || job_code.eql?(PST_ALL))
    arg_array = []
    arg_scope = {}

    if (! job_code.eql?(''))
      arg_array << "this.job_code === jc"
      arg_scope[:jc] = job_code
    end

    job_status = criteria_hash[:filter_by_job_status].to_sym

    if (job_status.eql?(:LAST_JOB_RUN))
      #look up all of the JMDs and get the last run JLE ids
      jmds = JobEngine.instance.get_job_meta_datas
      jles = jmds.map{|jmd|
        jle_id = jmd.last_jle_id
        (jle_id.nil? || jle_id.empty?) ? nil : JobLogEntry.where(_id: jle_id)[0]
      }.reject {|j| j.nil? || (! job_code.eql?("") && ! j.job_code.eql?(job_code)) }

      return jles
    else
      if (date_range[0].nil? && date_range[1].nil?)
        # do nothing
        return []
      elsif (date_range[0].nil? && ! date_range[1].nil?)
        arg_array << "this.finish_time < dr1"
        arg_scope[:dr1] = date_range[1]
      elsif (! date_range[0].nil? && date_range[1].nil?)
        arg_array << "(this.finish_time > dr0 || this.finish_time === undefined)"
        arg_scope[:dr0] = date_range[0]
      else
        arg_array << "(this.finish_time >= dr0 && this.finish_time <= dr1)"
        arg_scope[:dr0] = date_range[0]
        arg_scope[:dr1] = date_range[1]
      end
    end

    condition_no_criteria = arg_array.clone
    args_no_criteria = arg_scope.clone

    unless job_status.eql?(:NO_FILTER)
      case job_status
        when :STATUS_CHANGE_ONLY, :ESCALATION_CHANGE_ONLY then
          arg_array << "this.run_status === rs && this.status_changed === sc"
          arg_scope[:rs] = PST_COMPLETED
          arg_scope[:sc] = true
        when :RUNNING_JOBS_ONLY then
          arg_array << "(this.run_status === running || this.run_status === pending)"
          arg_scope[:running] = PST_RUNNING
          arg_scope[:pending] = PST_PENDING
        when :EMAILED_JOBS_ONLY then
          arg_array << "this.email_sent === email_sent"
          arg_scope[:email_sent] = true
        when :ALERTS_ONLY,:NON_ALERTS_ONLY then
          if (job_code.eql?(''))
            jcs = job_status.eql?(:ALERTS_ONLY) ? criteria_hash[:alert_only_in] : criteria_hash[:non_alert_only_in]
            jc_string = jcs.map{|elem| "this.job_code === '#{elem}'"}.join(" || ")
            arg_array << "( #{jc_string} )"
          end
        else
          #run by the current user
          arg_array << "this.run_by === user"
          arg_scope[:user] = job_status.to_s
      end
    end

    if (job_status.eql?(:ESCALATION_CHANGE_ONLY))
      status_changes = JobLogEntry.for_js(arg_array.join(" && "), arg_scope).order_by(:start_time => :desc).reject{ |e| e.nil?}
      no_filter_results = JobLogEntry.for_js(condition_no_criteria.join(" && "), args_no_criteria).order_by(:start_time => :desc).reject{ |e| e.nil?}
      return [status_changes,no_filter_results]
    end

    js = arg_array.join(" && ")
    JobLogEntry.for_js(js, arg_scope).limit(criteria_hash[:filter_limit]).order_by(:start_time => :desc).reject{ |e| e.nil?}
  end

  def self.get_last_completed(job_code)
    @jle = JobLogEntry.job_code(job_code).status_completed(true).order_by(:finish_time => :desc).limit(1)
    @jle[0]
  end

  def self.set_old_status_changes
    puts "In set old status change..."
    trackables=JobEngine.instance.get_trackable_jobs
    trackables.each do |trackable|
      jles = JobLogEntry.job_code(trackable.job_code).reverse
      last_status = nil
      current_status = nil
      jles.each do |jle|
        current_status = jle.status
        next if current_status.eql?(PST_UNKNOWN)
        if (!last_status.nil? && !current_status.eql?(last_status))
          jle.status_changed = true
          jle.save(:validate => false)
          puts "Status change on job -- #{jle.inspect}"
        end
        last_status = current_status
      end
    end
  end

  def self.clean_up_log(days_old=90)
    num = JobLogEntry.delete_all({finish_time.lt => (Time.now - days_old.to_i.days)})
    num.to_s
  end

  def self.clean_up_log_for_user
    puts "Trim everything older than how many days?  Enter for the default of 90."
    days_back = $stdin.gets
    days_back.chomp!
    days_back = "90" if days_back.eql? ""
    days_back = days_back.to_i
    return if (days_back == 0)
    puts "About to trim the database"
    trimmed = JobLogEntry.clean_up_log days_back
    puts "Done!  I trimmed #{trimmed} records from the database!"
  end

  def self.destroy_log()
    JobLogEntry.delete_all({})
  end

  def self.introscope_alerts()
    xml_result = ""
    color_codes = $application_properties['introscope_colors'].split(',')
    color_to_code = {}
    color_codes.each do
    |cc|
      color, code = cc.split("=>")
      color_to_code[color.strip.upcase] = code.strip
    end

    @trackables = JobEngine.instance.get_trackable_jobs
    return "" if (@trackables.nil? or @trackables.length == 0)
    @trackables.each do |trackable|
      if (trackable.introscope_enabled)
        xml = @@xml_template.clone
        status_change_jle = JobLogEntry.get_last_tracked_status_change(trackable.job_code)[0]
        next if status_change_jle.nil? #this job has never run
        epoch_time = status_change_jle.finish_time.to_i * 1000
        xml.gsub!('START_TIME_DATE',epoch_time.to_s)
        xml.gsub!('JOB_CODE', trackable.use_introscope_job_code ? trackable.introscope_job_code : trackable.job_code)
        short_desc = trackable.use_introscope_short_desc ? trackable.introscope_short_desc : trackable.short_desc
        long_desc = trackable.use_introscope_long_desc ? trackable.introscope_long_desc : trackable.description
        xml.gsub!('SHORT_DESCRIPTION',short_desc.nil? ? '' : short_desc)
        xml.gsub!('LONG_DESCRIPTION',long_desc.nil? ? '' : long_desc )
        xml.gsub!('IS_ACTIVE',trackable.active ? "1" : "0") #active will be 1 inactive will be 0
        jle = trackable.get_last_completed_job_log_entry
        escalation = jle.get_escalation
        status = nil
        if (jle.status.eql?(PST_UNKNOWN))
          status = color_to_code[PST_UNKNOWN]
        else
          if (escalation.nil?)
            status = '1' #green
          else
            status = color_to_code[escalation.color_name]#jle.status.eql?('GREEN') ? 1 : jle.status.eql?("RED") ? 2 : 3 #green is 1 red is 2 unknown is three
            status = '0' if status.nil? # catch all in case the administrator is mildly retarded and neglects to properly define 'introscope_colors' in our application properties file.
          end
        end
        xml.gsub!('STATUS_RED_GREEN',status.to_s)
        epoch_time = jle.finish_time.to_i * 1000
        xml.gsub!('LAST_COMPLETED_DATE',epoch_time.to_s)#convert to a format java.util.Date.parse can handle (required by introscope)
        xml.gsub!('TRACKABLES_PAGE',$application_properties['root_url'] + $application_properties['trackables_path'])
        xml.gsub!('JOB_LOG_ENTRY_PAGE',$application_properties['root_url'] + $application_properties['job_log_entry_path'] + '/' + jle.id.to_s)
        xml.gsub!('EVENT_ID',jle.id.to_s)
        xml.gsub!(/EVENT_PROPERTIES_EXPANSION(.*)EVENT_PROPERTIES_EXPANSION/) {
            |the_string|
          match = $1
          if jle.introscope_data.nil?
            ""
          else
            the_string = ''
            data_array = jle.introscope_data.split(';')
            data_array.each { |elem|
              match_l = match.clone
              key_values = elem.split('=')
              match_l.gsub!('EVENT_KEY',key_values[0])
              match_l.gsub!('EVENT_VALUE',key_values[1])
              the_string << match_l << "\n"
            }
            the_string
          end
        }
        xml_result << xml
      end
    end
    #iterate over introscope trackables and gsub appropriately...
    xml_result
  end

  #    JobLogEntry.job_code(job_code).finished(true).last_tracked_status(status_known).limit(1)
  def self.get_last_tracked_status_change(job_code)
    return nil unless  JobMetadata.job_code(job_code)[0].track_status_change
    jle = JobLogEntry.last_tracked_status_change(job_code,true)[0]
    jle = JobLogEntry.job_log_by_jc_desc(job_code).tracked(true).last if jle.nil?
    jle
  end

  #let scope = :before or :after
  def self.get_jle_in_sequence(jle, scope, status_change_only = false)
#    return nil unless JobMetadata.job_code(jle.job_code)[0].track_status_change
    begin
      jmd = JobMetadata.job_code(jle.job_code)[0]

      if (jmd.track_status_change)
        if (status_change_only)
          initial_jle = JobLogEntry.send(scope,jle).status_not(PST_UNKNOWN).finished(true).status_changed(true).limit(1)
        else
          initial_jle = JobLogEntry.send(scope,jle).status_not(PST_UNKNOWN).finished(true).limit(1)
        end
      else
        initial_jle = JobLogEntry.send(scope,jle).finished(true).limit(1)
      end
      initial_jle = initial_jle[0]
    rescue => ex
      return nil
    end
    initial_jle
  end

  def self.get_last_email_sent_jle(job_code)
    emails = JobLogEntry.job_code(job_code).email_sent(true)
    no_emails = JobLogEntry.job_code(job_code).email_sent(false).status_changed(true)
    puts "We have found " + emails.length.to_s + " entries!"
    puts "We have found (no_emails status changes) " + no_emails.length.to_s + " entries!"
    puts "The first finished at " + no_emails.first.finish_time.to_s
    puts "The last finished at " + no_emails.last.finish_time.to_s
    last_email_sent_jle = JobLogEntry.after(emails.first).email_sent(true)
    puts "last_email_sent_jle = " + last_email_sent_jle[0].finish_time.to_s
  end
end
#/home/t192zcs/Aptana_Studio_Workspace/PSTDashboard/script/runner -e development "JobLogEntry.destroy_log"
#/home/t192zcs/Aptana_Studio_Workspace/PSTDashboard/script/runner -e development "app/models/job_log_entry.rb"
#JobLogEntry.destroy_log
