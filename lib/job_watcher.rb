require 'monitor'

class JobWatcher

  def initialize(job_map, interval)
    @job_map        = job_map
    @watch_interval = interval
    @start          = false
  end

  def start!()
    return if @start
    @start        = true
    @watch_thread = Thread.new do
      begin
        while (@start) do
          sleep(@watch_interval)
          @job_map.each_pair do |key, value| #I hope iterators are thread safe in ruby....
            unless (key.alive?)
              @job_map.delete(key)
              next
            end
            overdue = Time.now - value
            if (overdue > 0)
              #kill the thread!
              now = Time.now
              $logger.debug("Time.now " + now.to_s)
              $logger.debug("value " + value.to_s)
              key[:watchdogged]      = true
              key[:watchdogged_time] = now
              message                = "JobWatcher:  Killing the thread " + key[:name] + ".  It was overdue to die by " + overdue.to_s + " seconds."
              $logger.warn(message)
                       #key.raise(message)
              key.kill #kills the thread but ensure blocks get to run.
              unless key[:scripting_container].nil?
                key[:scripting_container].clear
                key[:scripting_container].getProvider.getRuntime.getThreadService.getMainThread.kill
                key[:scripting_container].getProvider.getRuntime.tearDown(true)
                #ScriptingContainerHelper::clear_thread_locals(key)
                $logger.info("container terminated by job watch dog")
              end

              @job_map.delete(key)
            end
          end
        end
      rescue => ex
        $logger.error("The job watch thread has died. " + ex.to_s)
        $logger.error(ex.backtrace.join("\n"))
      ensure
        @start = false
      end
    end
  end

  def stop!()
    #cannot find a version of wait (or notify) so no thread locking on reads / writes
    @start= false
  end

  private
  @job_map
  @watch_thread
  @watch_interval
  @job_lock
  @start
end