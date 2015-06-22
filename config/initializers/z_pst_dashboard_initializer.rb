require 'PST_logger'
require 'monitor'
require 'prop_loader'
require './lib/jars/ojdbc6.jar'
require 'american_date'
require "trinidad"

Trinidad::CommandLineParser.parse(ARGV)
$trinidad_config = Trinidad.configuration

$application_properties = nil
begin
  File.open("./log/pid.txt", 'w') { |f| f.write($$) }
end

begin
  if $logger.nil?
    $logger = PSTLogger.new('./log/pst_log.log')
  end

rescue => ex
  $stderr.puts "Failed to load to create ./log/pst_log.log " + ex.message
  $stderr.puts "Terminating mongrel!"
  Process.exit
end

require 'java'
java.lang.System.getProperties['user.dir'] = Rails.root.to_s


begin
  if $application_properties.nil?
    $application_properties = PropLoader.load_properties_from_erb
    $logger.debug("Application properties loaded successfully.")
  end
rescue
  $logger.error "Failed to load ./pst_dashboard.properties.erb "<< $!.to_s
  $logger.error "Terminating Application server!"
  Process.exit
end

ENV['GEM_HOME'] = $application_properties['GEM_HOME'] unless $application_properties['GEM_HOME'].nil?

return unless ENV['RUNNER_TASK'].nil?

#the job engine cannot be loaded into memory until the logger and application properties are initialized
require 'job_engine'

begin
  Thread.new do
    if $application_properties['start_job_engine_on_deployment'].upcase.eql?('TRUE')
      $logger.info("Attempting the initial start of the job engine!")
      max_job_engine_start_attempts           =$application_properties['max_job_engine_start_attempts'].to_i
      seconds_between_start_job_engine_attempt=$application_properties['seconds_between_start_job_engine_attempt'].to_i
      attempts_to_start                       = 0
      while (!JobEngine.instance().started? and (attempts_to_start <= max_job_engine_start_attempts))
        attempts_to_start += 1
        $logger.info("Attempt number #{attempts_to_start.to_s} to start the job_engine!")

        $logger.info("Attempting to start job engine")
        JobEngine.instance().start!#this method should trap exceptions
        $logger.info("About to sleep for #{seconds_between_start_job_engine_attempt.to_s} seconds")
        sleep seconds_between_start_job_engine_attempt
      end
      started = JobEngine.instance.started?
      $logger.info("Auto start thread terminating!  Is the job engine started? " + started.to_s)
    end
  end
rescue => ex
  $logger.error("Error while attempting to launch thread that starts job engine upon application startup.")
  $logger.error(ex.to_s)
end
