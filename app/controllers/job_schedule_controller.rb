require 'file_editor'
require 'job_engine'
require 'java'
require "./lib/jars/shamu_quartz.jar"
require "./lib/jars/quartz-all-2.1.0.jar"
require "./lib/jars/slf4j-api-1.6.4.jar"
require "./lib/jars/slf4j-jdk14-1.6.4.jar"
require "./lib/jars/jcl-over-slf4j-1.6.4.jar"
require "./lib/jars/commons-exec-1.1.jar"
require "./lib/whenever_parser"

java_import 'va.shamu.quartz.SHAMUScheduler' do |pkg, cls|
  'JSchedule'
end

class JobScheduleController < ApplicationController
  @schedule
  @checked_out_by

  def initialize
    @schedule_file = $application_properties['ruby_cron']
    @editor = FileEditor.instance(@schedule_file)
    @editor.revertable = @@backup_cron_test
    @editor.valid_file = @@cron_test
    super
  end


  def view
    setup
    @page_hdr << " - View Schedule"
    @page_nav = [{:label => 'Edit Schedule', :route => job_schedule_edit_path}] if @available
  end

  def cancel
    @editor.check_in!(current_user)
    redirect_to(job_schedule_view_path)
  end
  
  def edit
    setup
    @page_hdr << " - Edit Schedule"
    @page_nav = [{:label => 'Cancel', :route => job_schedule_cancel_path}]
    @page_nav.push({:label => 'Update', :submit_form_name => 'job_scheduler_form'}) if @available
    @page_nav.push({:label => 'Revert', :route => job_schedule_revert_path}) unless is_schedule_valid?

    @successful_check_out = @editor.check_out!(current_user)
    
    if (! @successful_check_out)
      redirect_to(job_schedule_view_path)
      return
    end
    @valid_schedule = is_schedule_valid?
  end
  
  def revert
    setup
    @successful_check_out = @editor.check_out!(current_user)
    
    if (@successful_check_out)
      if ! @editor.revert(current_user)
        flash[:error] = 'Reversion Failed. The schedule file must be updated and fixed manually to get the scheduled jobs back into a good state.'
      end
    end
    redirect_to(job_schedule_view_path)
  end
  
  def update
    setup
    fileText = params[:schedule]
    $logger.info("in update")
    $logger.info(params.to_s)
    $logger.info(fileText)
    $logger.info(@schedule)
    if (fileText.eql?(@schedule))
      flash[:notice] = 'No changes made to the Job Schedule listing.'
      redirect_to(job_schedule_view_path)
      return
    end
    
    begin
      valid = @editor.write_file(current_user,fileText,@@crontab_update_proc)
      @valid_cron_update = valid[0]
      @editor.check_in!(current_user) if @valid_cron_update
      flash[:notice]= "Job Engine Schedule Updated!" if @valid_cron_update
      flash[:error] = valid[1] unless @valid_cron_update
    rescue => ex
      flash[:error] = ex.to_s
    end
    if (@valid_cron_update)
      JobEngine.instance.set_schedule
      redirect_to(job_schedule_view_path)
    else
      redirect_to(job_schedule_edit_path)
    end
  end
  

  private
  
  @@crontab_update_proc = Proc.new do
    success = $application_properties['whenever_success']
    result = JobEngine.run_whenever()
    valid = result.split(/\n/)[-2].eql?(success)

    if (valid)
      @scheduler = JSchedule.getInstance
      @scheduler.start #call from the job engine!
      $job_schedule = WheneverParse.new(result)
    end

    result.gsub!(/\r\n/,'<br>')
    result.gsub!(/\n/,'<br>')
    [valid, result]
  end
  
  @@backup_cron_test = Proc.new do
    success = true
    begin
     JobEngine.run_whenever(true)
    rescue => ex
      $logger.error "#{@schedule_file}.bak fails!" << ex.to_s
      success = false
    end
    success
  end
  
  @@cron_test = Proc.new do
    success = true
    begin
      JobEngine.run_whenever()
    rescue => ex
      $logger.error "#{@schedule_file} fails!" << ex.to_s
      success = false
    end
    success
  end

  def is_schedule_valid?
    @@cron_test.call
  end
  
  def setup
    #is_available will clean up the resource if need be (in the event that the last user saved the resource with shizzle)
    @editor.is_available?(current_user)
    @schedule = @editor.get_file
    $logger.info("In setup and schedule is - " + @schedule)
    @checked_out_by = @editor.get_current_user
    @available = @editor.is_available?(current_user)
    @page_hdr = "Job Schedule Maintenance"
  end
end
