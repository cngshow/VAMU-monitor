require 'gserver'
require 'monitor'
require 'job_watcher'
require 'thread_pool'
require 'csv'
require 'java'
require "./lib/jars/shamu_quartz.jar"
require "./lib/jars/quartz-all-2.1.0.jar"
require "./lib/jars/slf4j-api-1.6.4.jar"
require "./lib/jars/slf4j-jdk14-1.6.4.jar"
require "./lib/jars/jcl-over-slf4j-1.6.4.jar"
require "./lib/jars/commons-exec-1.1.jar"
require "./lib/whenever_parser"
require "./lib/scripting_container_helper"
require "./lib/helpers"
require 'log4r'
include Log4r
include PSTConstants

java_import 'va.shamu.quartz.SHAMUScheduler' do |pkg, cls|
  'JSchedule'
  end

java_import 'va.shamu.quartz.WorkNotifier' do |pkg, cls|
  'JWorkNotifier'
end

java_import 'java.lang.System' do |pkg, cls|
  'JSystem'
end


java_import 'java.io.StringWriter' do |pkg, cls|
  'JStringWriter'
end


java_import java.util.concurrent.Executors


class JobEngine
  include java.util.Observer

  COMMAND_FILE = './config/commands.txt'

  public

  #this method is for java's Observer/Observable pattern making the Job Engine an observer of our WorkNotifier impl.
  def update(observable, request)
    run_scheduled_job(request.to_s)
  end

  def run_scheduled_job(request)

    return if !started?
    #most request will answer questions like, "What are the credentials?".
    begin
      request.chomp!()
      $logger.debug("run_scheduled_job received request #{request}...")
      jmd = JobMetadata.job_code(request)[0]
      if (jmd.nil?)
        $logger.warn("Is #{request} defined in #{COMMAND_FILE}?  Ignoring...")
        return
      end
      unless (jmd.active)
        $logger.info("Ignoring a request to run #{request}.  This job is inactive.")
        return
      end

      # check to see if this job is currently running
      if (JobLogEntry.is_named_job_running?(request))
        $logger.info("#{request} is already running. Ignoring...")
        return
      end

      #execute the request pulling the commands from the hash
      #but first make sure this request is executable:
      # return if job_suspended?(request)
      $logger.debug('Preparing to execute ' << request)
      #in execute cron job pass in jle and create it here.
      jle = start_job_log_entry(1.year.from_now, request)
      @job_pool.dispatch(execute_cron_job,"CRON JOB " + request, request, jle)
    rescue =>ex
      error = "A request thread terminated while executing " << request
      $logger.error(error)
      $logger.error(ex.to_s)
    end

  end

  def get_job_meta_datas
    jmd = []
    gather_commands(false).each_pair do
      |key, value|
      jobs = JobMetadata.job_code(key)
      raise "Too many job meta datas found!" if (jobs.size > 1)
      jmd << jobs[0] unless jobs[0].nil?
    end
    $logger.debug("******************* jmd.length = " + jmd.length.to_s + "*******************")
    jmd.sort {|x,y| x.job_code.to_s <=> y.job_code.to_s }
  end

  def get_services
    jmd = get_job_meta_datas
    jmd.delete_if do
      |jmd_local|
      !jmd_local.enabled_as_service || !jmd_local.active
    end
  end

=begin
  def get_trackable_jobs
    jmd = get_job_meta_datas
    jmd.delete_if do
      |jmd_local|
      !jmd_local.track_status_change
    end
  end
=end


  def get_jobs(trackable = true)
    jmd = get_job_meta_datas
    jmd.delete_if do
      |jmd_local|
      !jmd_local.track_status_change.eql?(trackable)
    end
  end

  alias :get_trackable_jobs :get_jobs

  def execute_service(jmd, user, user_arguments = nil)
    raise "The user cannot be nil!" if user.nil?
    raise "The job engine is not started!" unless started?
    jle = nil
    jlh = Hash.new
    jlh[:service] = true
    jlh[:jmd] = jmd

    if (!started?)
      return "Cannot execute this service as the job engine is in the process of stopping or is stopped!"
    end

    @@service_lock.synchronize {
      $logger.info("service lock")

      if JobLogEntry.is_named_job_running?(jmd.job_code)
        @@service_hash[jmd.job_code] = Array.new unless @@service_hash.has_key?(jmd.job_code)
        @@service_hash[jmd.job_code].push(user.email) if user_arguments.nil?
        message = "Not Executing the service.  The system or another user has requested this job which is currently running. "

        if (jmd.email_result)
          message << "The result will be e-mailed to you." if user_arguments.nil?
          message << "Please attempt to re-run this job later once the currently running job is completed." unless user_arguments.nil?
        end
        return message
      else
        jle = JobLogEntry.get_last_completed(jmd.job_code)

        if ((!jle.nil? && jle.finish_time > jmd.stale_after_min.minutes.ago) && user_arguments.nil?)
          jlh[:jle] = jle
          #update e-mail list for the jle and save
          #jlh[:run_status] = jle.run_status
          jlh[:email_to] = [user.email]
          jlh[:job_result] = jle.job_result
          Thread.current[:sending_cached_result] = true
          email_job_result(jlh)
          message = "Not Executing the service.  This job was recently executed by another user."
          message << "The result will be e-mailed to you." if jmd.email_result
          return message
        end
      end
      jle = start_job_log_entry(2.year.from_now, jmd.job_code, user.login)
    }

    $logger.debug("Preparing to execute the service " << jmd.job_code)
    jlh[:jle] = jle

    lamb = lambda do
      |job_code,jle|
      jlh[:run_status] = PST_FAILURE
      @job_map[Thread.current] = jmd.max_execution_minutes.to_i.minutes.from_now
      @@thread_count = @@thread_count + 1;
      Thread.current[:name] = "SERVICE_THREAD " + jmd.job_code + " " +  @@thread_count.to_s;
      Thread.current[:watchdogged] = false
      result = nil
      begin
        jlh[:jle].run_status = PST_RUNNING
        jlh[:jle].start_time = Time.now
        jlh[:jle].save(:validate => false)
        commands = gather_commands(true, jmd.job_code, user_arguments)
        commands = commands[jmd.job_code]
        commands.each do |command|
          command.chomp!
          $logger.debug("command = #{command}")
          result = JobEngine.execute_command_to_temp(command)
          result.chomp!
          $logger.debug("the result is #{result}...")

          if (jlh[:job_result].nil?)
            jlh[:job_result] = result
          else
            jlh[:job_result] << "\n" << result
          end
        end
        @@service_lock.synchronize {
          email_list = user.email
          array_of_emails = @@service_hash[jmd.job_code]
          array_of_emails = Array.new if array_of_emails.nil?
          array_of_emails.each do
            |email|
            email_list << ',' << email
          end
          @@service_hash.delete(jmd.job_code)
          email_to_array = email_list.split(',')
          jlh[:email_to] = email_to_array
          jlh[:run_status] = PST_COMPLETED
        }
        $logger.debug("The service thread completed on #{jmd.job_code}")
      rescue => ex
        $logger.error("The service thread has died on #{jmd.job_code}!  The error is " << ex.to_s)
        jlh[:job_result] = '' if jlh[:job_result].nil?
        jlh[:job_result] << ex.to_s + "\n"
        jlh[:job_result] << ex.backtrace.join("\n")
      ensure
        unless jlh[:run_status].eql?(PST_COMPLETED)
          jlh[:job_result] = '' if jlh[:job_result].nil?
          if (Thread.current[:watchdogged])
            jlh[:job_result] << "\nKilled by the job watch dog at " + Thread.current[:watchdogged_time].to_s + "!"
          else
            jlh[:job_result] << "\nAn exceptional event occurred!"
          end
        end

        finish_job_log_entry(jlh)
      end
    end
    $logger.info("dispatching the service - start")
    @job_pool.dispatch(lamb, "SERVICE REQUEST " + jle.job_code.to_s, jle.job_code, jle)
    $logger.info("dispatching the service - end")
    message = "The service has been started!  "
    message << "The result will be e-mailed to you." if jmd.email_result
    return message
  end

  def self.instance()
    $logger.debug("in job engine instance method")
    @@instance_lock.synchronize do
      if (@@instance.nil?)
        @@instance = JobEngine.new()
      end
      @@instance
    end
    #  JobLogEntry.clean_up_log
  end

  def start!
    begin
      unless (started? || stopping?)
        $logger.info("Starting the job execution thread")
        set_state!(:running)
        #clean up any job log entries that are not finished
        JobLogEntry.delete_all(finish_time: nil)
       # @job_pool.start_cleanup

        #start the job engine
        $application_properties = PropLoader.load_properties('./pst_dashboard.properties')
        JobEngine.instance.set_schedule
        gc_interval = nil
        begin
          gc_interval = $application_properties['gc_interval'].to_i
        rescue
          gc_interval = 0
        end
        if (gc_interval > 0)
          @gc_thread = Thread.new do
             while(started?) do
               $logger.debug("Garbage collector about to be called")
               JSystem.gc
               $logger.debug("Garbage collector just completed")
               sleep(gc_interval)
             end
           end
        end
      end
    rescue => ex
      error = $!.to_s
      $logger.error("The job engine failed to start!  Error " << error)
      $logger.error(ex.backtrace.join("\n"))
      stop!
    end
  end

  def stop!
    begin
      unless (stopped? || stopping?)
        $logger.info("Stopping the job execution thread")
        set_state!(:stopping)
        # max_jobs = $application_properties['max_jobs'].to_i
        Thread.new do
          begin
            #@job_pool.shutdown#shutdown blocks unless we use executors
            while (working?) do
              $logger.debug("Sleeping will try to stop job engine in 5 seconds.")
              sleep 5
            end
            $logger.info("Stopped the job execution thread.")
          rescue => ex
            $logger.error("The job engine stop thread failed to stop nicely!  Error " << ex.to_s)
            $logger.error ex.backtrace.join("\n")
          ensure
            set_state!(:stopped)
          end
        end
      end
    rescue
      $logger.error("The job engine failed to stop.  Error " << $!.to_s)
    end
  end

  def working?
    @job_pool.working?
  end

  def started?
    get_state.eql?(:running)
  end

  def stopping?
    get_state.eql?(:stopping)
  end

  def stopped?
    get_state.eql?(:stopped)
  end

  def set_schedule
    return unless started?
    @scheduler.stop #puts quartz in standby mode
    @scheduler.clearJobs #unschedules all jobs
    @scheduler.start #calls quartz' start method
    @cron_output = JobEngine.run_whenever
    @job_data = WheneverParse.new(@cron_output)
    schedules_and_commands = @job_data.get_schedules_and_commands

    schedules_and_commands.each do |sc|
      schedule = sc[0]
      command = sc[1]
      $logger.debug("scheduling " + command + " for " + schedule)
      @scheduler.scheduleJob(schedule,command, 90)
    end
  end

  def gather_arguments(job_code)
    r_val = Hash.new
    commands_file = File.new(COMMAND_FILE,'r')
    next_line_maybe_regex = false
    variable = nil
    begin
      while (command = commands_file.readline)
        if (next_line_maybe_regex and Regexp.compile('#ARG_DEFINITION\s*\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*)').match(command))
          label = $1
          entry_note = $2
          length = $3.strip.to_i
          error_msg = $4
          regex = $5
          r_val[variable] << label
          r_val[variable] << entry_note
          r_val[variable] << length
          r_val[variable] << error_msg
          r_val[variable] << regex
          next_line_maybe_regex = false
        end
        next if Regexp.compile('^\s*#|^\s+$').match(command)
        command.chomp!
        bound_variable = Regexp.compile('\s*(\!.+?)\s*==>\s*(.+?)\s*=\s*(.*)')
        bound_match = bound_variable.match(command)
        if (bound_match)
          variable = bound_match[1]
          next unless  variable.split('').last(4).join('').upcase.eql?("_ARG")
          bindings = bound_match[2]
          executable = bound_match[3]
          bindings = bindings.split(',')
          bindings = bindings.map{|elem| elem.strip}
          if bindings.include?(job_code.strip)
            r_val[variable] = [executable]
            next_line_maybe_regex = true
            #process_variable(bound_match[1] + '=' + bound_match[3], r_val)
          end
        elsif (Regexp.compile('\s*(\!.+)=(.*)').match(command))
          variable = $1
          executable = $2
          next unless  variable.split('').last(4).join('').upcase.eql?("_ARG")
          # process_variable(command, r_val)
          next_line_maybe_regex = true
          r_val[variable] = [executable]
        end
      end
    rescue EOFError
      commands_file.close
    end
    r_val
  end

  #completely untested
  def gather_cached_argument_val(job_code,bang_variable)
    return nil if  @variable_cache.nil? #never executed a thang...
    return nil if @variable_cache[job_code].nil? #never executed this job_code
    return @variable_cache[job_code][bang_variable]
  end

  protected

  private
  @@instance = nil
  @@service_hash = {}
  @@service_lock = Monitor.new
  @@stop_lock = Monitor.new
  @@state_lock = Monitor.new
  @@file_count_lock = Monitor.new
  @@instance_lock = Monitor.new
  @@file_count = 0;
  @@thread_count = 0
  @@state = :stopped
  @@valid_states = {:stopped => :running, :stopping => :stopped, :running => :stopping}

  def set_state!(state)
    if (@@valid_states.keys.include?(state))
      $logger.info("The job engine state is set to #{state}")
      @@state_lock.synchronize {
        if(!@@valid_states[@@state].eql?(state))
          raise "Invalid state transition from #{@@state} to #{state}"
        end
        @@state = state
        @scheduler.stop if state.eql?(:stopping)
      }
    else
      raise "The only valid states are " + @@valid_states.keys.join(" ")
    end
  end

  def get_state()
    @@state_lock.synchronize {
      return @@state
    }
  end

  def initialize()
    @scheduler = JSchedule.getInstance
    gather_commands(false)
    @job_map = Hash.new
    @job_watcher = JobWatcher.new(@job_map,$application_properties['job_check_interval_seconds'].to_i)
    @job_watcher.start!
    max_jobs = $application_properties['max_jobs'].to_i
    @job_pool = ThreadPool.new(max_jobs)
    JWorkNotifier.instance.addObserver(self)
  end

  def self.safe_eval(the_code)
    $logger.debug("About to execute this  #{the_code}.")
    result = ""
    begin
      result = instance_eval(the_code)
    rescue => ex
      result = ex.to_s
    end
    $logger.debug("#{the_code} returning #{result}.")
    return result
  end

  def self.get_file_count
    @@file_count_lock.synchronize do
      @@file_count = @@file_count+1
      return $application_properties['temp_file_marker'].to_s+@@file_count.to_s
    end
  end

  #if substituting variables (such as !lookback found in commands.txt) you should provide the corresponding job_code
  #or bound variables will not be processed.

  def gather_commands(substitute_variables = true, job_code_string = nil, user_arguments = nil)
    commands = Hash.new
    variables = Hash.new
    file_line_number = 0
    commands_file = File.new(COMMAND_FILE,'r')
    begin
      while (command = commands_file.readline)
        file_line_number = file_line_number + 1
        $logger.debug("Currently processing line number #{file_line_number}")
        next if Regexp.compile('^\s*#|^\s+$').match(command)
        command.chomp!
        bound_variable = Regexp.compile('\s*(\!.+?)\s*==>\s*(.+?)\s*=\s*(.*)')
        bound_match = bound_variable.match(command)
        if (bound_match)
          if ((bound_match[2].split(',').map! { |elem| elem.strip}).include?(job_code_string))
            process_variable(bound_match[1] + '=' + bound_match[3], variables, job_code_string, user_arguments)  if (substitute_variables)
          end
          next
        elsif (Regexp.compile('\s*\!.+=.*').match(command))
          process_variable(command, variables, job_code_string, user_arguments)  if (substitute_variables)
          next
        end
         val_array = command.split(',')
         key = val_array.shift
         val = val_array.join(',')
         key.strip!
         val = substitute_variables_in_command(val,variables, job_code_string) if (substitute_variables && key.eql?(job_code_string))

        #at the end of value I appended a comma
        if (commands[key] == nil)
          #right here we see a new command we have not seen before
          #lookup to see if an active record entry exists for this
          #key.  Create it if not.
          if (JobMetadata.job_code(key).size == 0)
          	success = true
            begin
              jmd_data = {}
              jmd_data[:job_code] = key
              jmd_data[:active] = true
              #jmd_data[:escalations_attributes] = [{:color_code => 'red', :color_name => 'red' }]
              jmd = JobMetadata.new(jmd_data)
              JobMetadata.add_escalations(jmd)
              jmd.save(:validate => false)
            rescue => ex
              s = ex.to_s
              $logger.error(s)
              $logger.error(ex.backtrace.join("\n"))
              success = false
            end
            $logger.info("The JobMetadata code #{key} now has a job meta data associated with it in the database.") if success
          end
          commands[key] = []
        end
        commands[key].push(val)
        $logger.debug("added command: Execute string=" << key << " , command=" << val)
      end
    rescue EOFError

    ensure
      commands_file.close
    end
    commands
  end

=begin
  def job_suspended?(job)
    suspended = JobMetadata.job_code(job)[0].is_suspended?
    $logger.debug("suspend state for job: #{job} = #{suspended}")
    suspended
  end
=end

  def get_email_list(job)
    jm = JobMetadata.job_code(job)[0]
    to_array = jm.email_to.to_s.split().uniq
    cc_array = jm.email_cc.to_s.split().uniq
    $logger.debug("get_email_list called for #{job}.")
    {:email_to => to_array, :email_cc => cc_array}
  end

  def substitute_variables_in_command(command, variables, job_code)
    pattern = Regexp.compile('.*?(\!\w+).*')
    match = pattern.match(command)
    while (match) do
      variable = match[1]
      value = variables[variable]
      $logger.debug("Substituting #{variable} with #{value} for command=#{command}")
      raise "Commands.txt invalid.  Please define #{variable}." if (value.nil?)
      command.gsub!(variable){|match| value}
      match = pattern.match(command)
    end
    command
  end

  def process_variable(command, variables, job_code = nil, user_arguments = nil)
    @variable_cache = {} if @variable_cache.nil?
    if (command =~ /^\s*(\!.+?)\s*=\s*(.*)/)
      variable = $1
      executable = $2
      result = nil
      if (!user_arguments.nil? and !user_arguments[variable].nil?)
        result = user_arguments[variable]
      else
        executable = process_nested_variables(executable,variables, command) if (executable =~ /!\w+/)
        result = JobEngine.execute_command_to_temp(executable)
      end
      result.chomp!
      variables[variable] = result
      unless (job_code.nil?)
        @variable_cache[job_code] = {} if @variable_cache[job_code].nil?
        @variable_cache[job_code][variable] = result
      end
    end
    $logger.debug('we need to process this line ' << command)
    variables
  end

  def process_nested_variables(executable, variables, command)
    begin
    $logger.debug("process_nested_variables = #{executable}")
    if (executable =~ /(!\w+)/)
      the_sub = variables[$1]
      raise "#{$1} was not defined.  Please define it in commands.txt -- for command #{command}" if the_sub.nil?
      $logger.debug("Executable is currently #{executable}")
      #executable.sub!($1,the_sub)
      executable.sub!($1){|match| the_sub}
      $logger.debug("Substituting #{$1} with #{the_sub}")
      $logger.debug("Executable is now #{executable}")
      executable = process_nested_variables(executable,variables, command) if (executable =~ /!\w+/)
    end
    rescue => ex
        $logger.debug(ex.to_s)
        raise ex
    end

    $logger.debug("process_nested_variables now is = #{executable}")
    executable
  end

  #The output of the script must look something like: (CASE MATTERS!)
  #EMAIL_RESULT_BELOW:
  #SUBJECT: This is some subject
  #The body is here
  #EMAIL_RESULT_ABOVE:
  #note any data above EMAIL_RESULT_BELOW or beneath EMAIL_RESULT_ABOVE
  #is ignored
  def email_job_result(jlh)
    # return unless
    jmd = jlh[:jmd]
    jle = jlh[:jle]
    return unless email_result?(jlh) || (jlh.has_key?(:service) && jmd.email_result)
    email_expression = Regexp.new('EMAIL_RESULT_BELOW:(.*)EMAIL_RESULT_ABOVE',Regexp::MULTILINE)
    match = email_expression.match(jlh[:job_result])

    if (match.nil?)
      $logger.debug("The output for job_code #{jmd.job_code} does not have valid e-mail output!")
      return
    end
    $logger.error("The output for job_code #{jmd.job_code} does have valid e-mail output!  See the rails log for details")
    body = match[1]
    #get the subject from the body
    match = Regexp.new('SUBJECT:(.*)').match(body)
    subject = match[1] unless match.nil?
    body.sub!("SUBJECT:#{subject}",'')#append on subject
    subject = $application_properties['service_subject'] + " " + subject if jlh.has_key?(:service)
    subject = subject + ' -- REMINDER ' + @reminder_hash[jmd.job_code].to_s  if (jlh[:reminder_email])
    body.chomp!.reverse!.chomp!.reverse! unless jmd.email_content_type.eql?('text/html')
    from = $application_properties['PST_Team']
    content_type = jmd.email_content_type
    recipients = []
    cc = []# or should it be ''?
    #banana slug
    #integrate with escalation levels to get additional e-mails out of the escalation
    recipients = jlh[:email_to] if jlh.has_key?(:email_to)
    cc = jlh[:email_cc] if jlh.has_key?(:email_cc)

    $logger.info "Thread.current escalation change is ->#{Thread.current[:escalation_change].to_s}<-"
    $logger.info "Thread.current status change is ->#{Thread.current[:status_change].to_s}<-"

    if (jmd.track_status_change && jmd.email_on_status_change_only && (Thread.current[:escalation_change] || Thread.current[:status_change]))
      esc = jle.get_escalation
      esc = JobLogEntry.before(jle).status_not(PST_UNKNOWN).limit(1).first.get_escalation if esc.nil? #if this is nil this jle is green

      if ! esc.nil? #this is added in the event that the alert has never been red and we are in this method because we are executing as a service
        esc_emails = esc.get_escalation_based_emails
        recipients = recipients | esc_emails[0]
        cc = cc | esc_emails[1]
      end
    end

    recipients = recipients.uniq.join(',')
    cc = cc.uniq.join(',')
    email_hash = {:request => jmd.job_code, :content_type => content_type, :subject=>subject,
                  :recipients=>recipients, :from=>from, :cc=>cc,:body=>body,
                  :incl_attachment=>jmd.incl_attachment,:attachment_path=>jmd.attachment_path,
                  :jmd => jmd, :jle => jle}

    JobMailer.job_result(email_hash).deliver
  end

  def email_result?(jlh)
    jmd = jlh[:jmd]
    return false unless jmd.email_result
    return false if jlh[:current_status].eql?(PST_UNKNOWN)
    return true unless jmd.track_status_change
    return true unless jmd.email_on_status_change_only

    jle = jlh[:jle]
    escalation = jle.get_escalation #will be nil if jle is green
    $logger.info("For job code " + jle.job_code.to_s + " the returned escalation is: " + escalation.to_s)
    $logger.info("The current status is " + jlh[:current_status].to_s + " and the last status is " + jlh[:last_status].to_s)
    return false if (!escalation.nil? && escalation.suppress_email)
    $logger.info("Beginning escalation analysis")
    status_change_red = !jlh[:current_status].eql?(jlh[:last_status]) && jlh[:current_status].eql?(PST_RED)
    status_change_green = !jlh[:current_status].eql?(jlh[:last_status]) && jlh[:current_status].eql?(PST_GREEN)
    status_change = !jlh[:current_status].eql?(jlh[:last_status])
    Thread.current[:status_change] = status_change
    $logger.info("status_change_red= " + status_change_red.to_s + " : status_change_green= " + status_change_green.to_s + " : status_change= " + status_change.to_s)
    currently_red = jle.status.eql?(PST_RED)

    if (currently_red)
      $logger.info("Currently red")
      if (status_change_red)
        #I am the first status change
        return ! escalation.suppress_email
      else
        #not a status change red
         return false if escalation.suppress_email
         first_status_change_jle = JobLogEntry.get_jle_in_sequence(jle, :before, true)
         last_email_sent_jle_array = JobLogEntry.after_inclusive(first_status_change_jle).email_sent(true)
         last_email_sent_jle = last_email_sent_jle_array.last
         escalation_change = last_email_sent_jle.nil? || (!last_email_sent_jle.get_escalation.color_name.eql?(escalation.color_name))
         Thread.current[:escalation_change] = escalation_change
         return true if escalation_change
      end
    else
      #I am currently green
      return false unless status_change
      #status change green
      first_status_change_jle = JobLogEntry.get_jle_in_sequence(jle, :before, true)
      $logger.info("The first_status_change_jle has ID " + first_status_change_jle.id.to_s + " with finish time of " + first_status_change_jle.finish_time.to_s)
      $logger.info( "jle's id is " + jle.id.to_s+ " with finish time of " + jle.finish_time.to_s)
      last_email_sent_jle_array = JobLogEntry.after_inclusive(first_status_change_jle).email_sent(true)
      last_email_exists = (!last_email_sent_jle_array.nil? && !last_email_sent_jle_array.empty?)
      $logger.info("First = " + last_email_sent_jle_array.first.finish_time.to_s) if last_email_exists
      $logger.info("Last = " + last_email_sent_jle_array.last.finish_time.to_s) if last_email_exists
      $logger.info("An e-mail has never been sent for this Job Code " + jmd.job_code) unless last_email_exists
      last_email_sent_jle = last_email_sent_jle_array.last
      $logger.info("last_email_sent_jle's id is " + last_email_sent_jle.id.to_s+ " with finish time of " + last_email_sent_jle.finish_time.to_s) if last_email_exists
      return !last_email_sent_jle.nil?
    end

#    total_emails_sent= JobLogEntry.find(:select => "count(*) as total_emails_sent",
#        :conditions => ["id >= ? and job_code = ? and email_sent = true", first_status_change_jle.id, first_status_change_jle.job_code])

    num_emails_sent = get_num_emails_for_highest_escalation(last_email_sent_jle_array)
    if (@reminder_hash.nil?)
      @reminder_hash = {}
    end
    @reminder_hash[jmd.job_code] = num_emails_sent
    #banana slug
    #reminder alerting starts below.  Integrate with escalation levels.
    #if I am down here my escalation level has not short circuited me out of the method so straight time based reminders
    #works for reminder e-mails
    sec_between = jmd.minutes_between_status_alert*60
    last_time = jmd.last_email_sent.nil? ? (Time.now - sec_between) : jmd.last_email_sent
    elapsed = Time.now - last_time
    $logger.debug("elapsed time=" + elapsed.to_s)
    $logger.debug("seconds b/t alerts=" + (sec_between).to_s)

    #at this point the statuses are the same so send and email if the status is red and the reminder period has elapsed
    jlh[:reminder_email] = jlh[:current_status].eql?(PST_RED) && (elapsed >= sec_between)
    # if (jlh[:reminder_email])
      # reminder_tracking(jmd.job_code, true)
    # end
    return jlh[:reminder_email]
  end

  def get_num_emails_for_highest_escalation(emailed_jle_array)
    esc_tracker = {}
    emailed_jle_array.each do |jle|
      esc = jle.get_escalation
      if (esc_tracker[esc.priority].nil?)
        esc_tracker[esc.priority] = 1
      else
        esc_tracker[esc.priority] = esc_tracker[esc.priority]+1
      end
    end
    return esc_tracker[esc_tracker.keys.sort.last]
  end


  def start_job_log_entry (start_time, job_code, user=PST_SYSTEM)
    jle = nil #do I have to do this to scope in ruby?
    begin
      jle = JobLogEntry.new
      jle.job_code = job_code
      jle.start_time = start_time
      jle._id = job_code + "_" + Time.now.strftime('%Y%m%d-%H:%M:%S-%L-%Z')
      jle.run_by = user
      jle.save(:validate => false)
    rescue => ex
      $logger.error("Could not create a job log entry for #{job_code} : " << ex.to_s)
    end
    jle
  end

  def finish_job_log_entry(jlh)
    jle = jlh[:jle]
    begin
      return if jle.nil?
      jlh[:finish_time] = Time.now if jlh[:finish_time].nil?
      jle.finish_time = jlh[:finish_time]
      jle.job_result  = jlh[:job_result]
      jle.run_status  = jlh[:run_status]

      status_changed = false
      if (jlh[:jmd].track_status_change)
        jlh.merge!(track_status(jlh))
        status_changed = (jlh[:current_status].eql?(PST_UNKNOWN) ? false : !jlh[:current_status].eql?(jlh[:last_status]))
      end

      #set the email columns based on whether this was called from the service or cron
      service_to = jlh[:email_to] if (jlh[:service])
      if (jlh[:service].nil? || status_changed)
        jlh.merge!(get_email_list(jle.job_code))
      end
      jlh[:email_to] = Array.new if (jlh[:email_to].nil? && !service_to.nil?)
      jlh[:email_to] = jlh[:email_to] | service_to unless service_to.nil? #pipe merges arrays with no duplicates

      #save the job log entry
      jle.status_cnt     = jlh[:status_cnt]
      jle.status         = jlh[:current_status]
      jle.status_changed = status_changed
      jle.save(:validate => false)

      #get the job metadata and update the last jle id and finish time
      jmd = jlh[:jmd]
      jmd.last_jle_id = jle._id
      jmd.last_jle_finish_time = jle.finish_time
      jmd.save(:validate => false)

      #email the job result if applicable
      email_job_result(jlh)
    rescue => ex
      $logger.error("Finish_job_log_entry could not complete for " << jle.job_code)
      $logger.error(ex.backtrace.join("\n"))
    end
  end

  #track status tracks whether a job is red or green.  It also grabs any metadata the job might output and squirrels it away into the JLE.
  def track_status(jlh)
    jmd = jlh[:jmd]
    jle = jlh[:jle]
    result = jle.job_result
    red = $application_properties['red']
    green = $application_properties['green']
    red_expression = Regexp.new(red,Regexp::MULTILINE)
    green_expression = Regexp.new(green,Regexp::MULTILINE)
    run_data_expression = Regexp.new($application_properties['run_data'],Regexp::MULTILINE)
    introscope_data_expression = Regexp.new($application_properties['introscope_data'],Regexp::MULTILINE)
    result_no_carriage = result.gsub("\n",'')
    result_no_carriage = result.gsub("\r\n",'')
    match = green_expression.match(result)
    run_data_match = run_data_expression.match(result_no_carriage)
    if (run_data_match)
      state = run_data_match[1]
      jle.run_data = state
      $logger.debug("The current run of #{jmd.job_code} is storing the following run data state: #{state}")
    end
    introscope_data_match = introscope_data_expression.match(result_no_carriage)
    if (introscope_data_match)
      state = introscope_data_match[1]
      jle.introscope_data = state
      $logger.debug("The current run of #{jmd.job_code} is storing the following introscope state: #{state}")
    end

    if match
      cur_status = PST_GREEN
    else
      match = red_expression.match(result)

      if match
        cur_status = PST_RED
      else
        cur_status = PST_UNKNOWN
        $logger.debug("The output for job_code #{jmd.job_code} does not have valid status output!")
      end
    end

    #look up the last successfully completed job log entry to see what the previous status was
    #last_log = JobLogEntry.job_log_by_jc_desc(jmd.job_code).finished(true).status_completed(true).limit(1)
    last_log = JobLogEntry.get_last_tracked_status(jmd.job_code,true)
    #if we have a last log entry to compare against then increment the status_cnt if it is the same
    #as the current run. Otherwise, the count will default to 1 as the status just changed
    #if we kill the job engine during a save or the job was never run assume green.
    last_status = last_log.nil? ? PST_GREEN : last_log.status

    status_cnt = 1
    unless last_log.nil?
      if (cur_status.eql?(last_status))
        #if the last job was abandoned (reboot mongrel during execution) we might still have a null
        if (last_log.status_cnt.nil?)
          last_log.status_cnt = 0
        end
        status_cnt = last_log.status_cnt + 1
      end
    end
    #return the current status and the last log status
    {:current_status => cur_status, :last_status => last_status, :status_cnt => status_cnt}
  end

  #under the MRI version of ruby we had problems with different threads losing the results of a backtick operation (``)
  #I suspect jruby (with true java threading) will not suffer this problem so we will be trying this directly from here on out.
  #but that is why this method has all the commented out code.
  def self.execute_command_to_temp(executable)
    if (Thread.current[:watchdogged] == true)
      $logger.warn("#{executable} is not being executed as the watchdog has ceased this thread!")
      return ""
    end

    begin

      job_start = Time.now

      if (Rails.env.development? && executable =~ /^\s*echo\s+(.*)/)
        #on windows boxes dropping to the shell can take 1 second per echo, so to make life less bad...
        #things like echo $GEM_HOME will not work however.
        val = $1
        $logger.debug("Echo found: #{val}")
        return val unless val =~/\s*(-[neE])\s+.*/ #this is a performance enhancement.  We will no longer drop to the shell for
                                                 # for echo commands, however for echo -n, echo -E or echo -e we still will.
        $logger.debug("found the following flags: #{$1} so we will execute at the shell.")
      end

      if (executable =~ /^\s*SECLUDED_RUBY_EVAL_CODE_(\w+)\s+(.*)/)
        $logger.debug("SECLUDED_RUBY_EVAL_CODE #{$1} is the classloader and we run " + $2)#change to debug before checkin
        container = ScriptingContainerHelper::get_secluded_scripting_container($1)
        Thread.current[:java_current_thread].setContextClassLoader(Thread.current[:job_class_loader])
        r_val = container.runScriptlet($2)
        Thread.current[:java_current_thread].setContextClassLoader(Thread.current[:initial_context_class_loader])
       # ScriptingContainerHelper::clear_thread_locals()
        $logger.debug("secluded run returning #{r_val}")
        return r_val
        #return JobEngine.safe_eval($1)  DELETE THIS METHOD
      end

      if (executable =~ /^\s*RUBY_EVAL_CODE\s+(.*)/)
        $logger.debug("RUBY_EVAL_CODE #{$1}")
        return JobEngine.safe_eval($1)
      end

      if (executable =~ /^\s*RUBY_EVAL_FILE_(\w+)\s+(.*)/)
        $logger.debug("About to execute ruby internally.")
        begin
          class_loader_tag = $1
          val = $2
          $logger.debug("executing:  #{val}")
          val_array = CSV::parse_line(val, :col_sep => ' ').reject do |e| e.nil? end
          $logger.debug("Val array is:")
          $logger.debug(val_array.inspect)
          if (val_array.empty?)
            $logger.error("The val array is empty!  The argument list needs repair for:")
            $logger.error(val)
            return "The argument list appears broken for:\n #{val}"
          end
          ruby_code = val_array.shift
          script = Utilities::FileHelper.file_as_string(ruby_code)
          $logger.debug("Executing #{script}")
          container = ScriptingContainerHelper::get_secluded_scripting_container(class_loader_tag)
          #container.setArgv(val_array.to_java :String)#no worky... Why?
          args = val_array.to_java :String
          container.put("ARGV",args)# this worky!
          output = nil
          begin
            Thread.current[:java_current_thread].setContextClassLoader(Thread.current[:job_class_loader])
            output = container.runScriptlet(script).to_s
            Thread.current[:java_current_thread].setContextClassLoader(Thread.current[:initial_context_class_loader])
            #ScriptingContainerHelper::clear_thread_locals()
            $logger.debug("The output is:")
            $logger.debug(output)
          ensure
            #nothing in the ensure block for now!
          end
          return output
        rescue => ex
          return ex.to_s
        end
      end
      result = `#{executable}`
    rescue => ex
      $logger.error("Cannot execute #{executable} reason:")
      $logger.error(ex.to_s)
      return ex.to_s
    ensure
      job_end = Time.now
      delta = job_end - job_start
      $logger.debug("#{delta} seconds to execute: #{executable}")
    end
    result
  end

  def self.run_whenever(process_backup = false)
    begin
    container = ScriptingContainerHelper::get_secluded_scripting_container()
    script = Utilities::FileHelper.file_as_string(ENV['GEM_HOME']+'/bin/whenever')#whenever_location = ./gem_home/bin/whenever
    args = nil
    if (process_backup)
      backup_schedule_file = $application_properties['whenever_backup_file']
      args = ["--load-file", backup_schedule_file].to_java :String
    else
      schedule_file = $application_properties['ruby_cron']
      args = ["--load-file",schedule_file].to_java :String
    end
    container.setArgv(args)
    writerSTD = JStringWriter.new()
    writerERR = JStringWriter.new()
    container.setOutput(writerSTD)
    container.setError(writerERR)
    #container.java_send(:setOutput,[java.io.Writer],writerSTD)
    #container.java_send(:setError,[java.io.Writer],writerERR)
    container.resetWriter
    container.resetErrorWriter
    container.runScriptlet(script)
    output = writerSTD.getBuffer.toString
    error  = writerERR.getBuffer.toString
    if (!error.nil? && !error.empty?)
      $logger.error("Whenever stderr failure!\n" + error)
      raise error
    end
    output
    rescue =>ex
      $logger.error("Whenever failure is " + ex.to_s)
      raise ex
  end
  end

  #now called by quartz
  def execute_cron_job
    lambda do
      |request, jle|
      jle.run_status = PST_RUNNING
      jle.start_time = Time.now
      begin
        jle.save(:validate => false)
        jlh = Hash.new
        jlh[:run_status] = PST_FAILURE
        @@thread_count = @@thread_count + 1;
        Thread.current[:name] = "JOB_THREAD " + request.to_s + ' ' + @@thread_count.to_s;
        Thread.current[:watchdogged] = false
        jmd = JobMetadata.job_code(request)[0]
        @job_map[Thread.current] = jmd.max_execution_minutes.to_i.minutes.from_now

        jlh[:jmd] = jmd
        jlh[:jle] = jle
        commands = gather_commands(true, request)
        commands = commands[request]
        if (commands.nil? || commands.empty?)
          $logger.error("There are no commands for request #{request}.  Exiting...")
          return
        end
        $logger.debug("The size of commands is " << commands.length.to_s)
        commands.each do |command|
          command.chomp!
          $logger.debug("command = #{command}")
          #$stderr.puts("executing #{command}")
          #result = `#{command}`  There seems to be a bug in ruby where backticks hang in multi threaded situations
          result = JobEngine.execute_command_to_temp(command)
          #$stderr.puts("executed #{command}")
          result.chomp!

          if (jlh[:job_result].nil?)
            jlh[:job_result] = result
          else
            jlh[:job_result] << "\n" << result
          end
          $logger.debug("the result is #{result}...")
          #check to see if the command is in
        end
        jlh[:run_status] = PST_COMPLETED


      rescue =>ex
        error = "An execution thread terminated while executing " << request
        $logger.error(error)
        $logger.error(ex.to_s)
        jlh[:job_result] = '' if jlh[:job_result].nil?
        jlh[:job_result] << ex.to_s + "\n\n"
        jlh[:job_result] << ex.backtrace.join("\n")
      ensure
        unless jlh[:run_status].eql?(PST_COMPLETED)
          jlh[:job_result] = '' if jlh[:job_result].nil?
          if (Thread.current[:watchdogged])
            jlh[:job_result] << "\nKilled by the job watch dog at " + Thread.current[:watchdogged_time].to_s + "!"
          else
            jlh[:job_result] << "\nAn exceptional event occurred!"
          end
        end
        finish_job_log_entry(jlh)
      end
    end
  end
end