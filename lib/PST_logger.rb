require 'log4r'
include Log4r
#require 'fileutils'

class PSTLogger

  public
  def initialize(log_file_string, to_stdout = false)
    #FileUtils.touch(log_file_string)
    # log_file = File.new(log_file_string)
    @mylog = Logger.new log_file_string
    #@mylog.outputters = log_file_string
    #Log4r::FileOutputter.new(log_file_string) 
    @mylog.level= 0
    @to_stdout = to_stdout
  end

  def self.setup_mail_logging
    mylog = Logger.new "./log/mail_log.log"
    $application_properties['mail_log_level']
    if ($application_properties != nil)
      mylog.level = level_number($application_properties['mail_log_level'])
    end
    ActionMailer::Base.logger = mylog
  end

  #setup_mail_logging

  def debug(log)
    level
    babble(log)
    @mylog.debug log
  end

  def info (log)
    level
    babble(log)
    @mylog.info log
  end

  def warn(log)
    out = time  << log
    babble(log)
    @mylog.warn log
  end

  def error(log)
    level
    babble(log)
    @mylog.error log
  end

  def fatal(log)
    level
    babble(log)
    @mylog.fatal log
  end

  private
  @to_stdout

  def babble(log)
    puts log if @to_stdout
  end

  def time
    level
    Time.now.to_s << ": "
  end

  def level
    if ($application_properties != nil)
      @mylog.level = PSTLogger.level_number($application_properties['log_level'])
    end
  end

  def self.level_number(level_string)
    rVal = 3
    return rVal if level_string.nil?
    case level_string.upcase
      when 'DEBUG'
        rVal = 0 #Log4r::DEBUG
      when 'INFO'
        rVal = 1 #Log4r::INFO
      when 'WARN'
        rVal = 2 #Log4r::WARN
      when 'ERROR'
        rVal = 3 #Log4r::ERROR
      when 'FATAL'
        rVal = 4 #Log4r::FATAL
    end
  end

end