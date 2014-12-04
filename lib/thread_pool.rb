require 'thread'
#require 'java'
#java_import java.util.concurrent.Executors
#        JobLogEntry.delete_all(finish_time: nil)

class ThreadPool
  def initialize(max_size)
    @pool = []
    @max_size = max_size
    @pool_mutex = Mutex.new
    @pool_cv = ConditionVariable.new
    @job_log_cleaner = nil
    @job_log_cleaner_running = false
    #@executor = Executors.newFixedThreadPool(max_size)
  end

  def start_cleanup #Currently unused
    @job_log_cleaner_running = true

    @job_log_cleaner = Thread.new do
      while (@job_log_cleaner_running) do
        begin
          @pool_mutex.synchronize do
           # JobLogEntry.delete_all(finish_time: nil) unless working?
          end
        rescue => ex
          $logger.error("Threadpool cleanup thread failed to clean! " + ex.to_s)
        end
        sleep $application_properties['jle_cleanup'].to_i
      end
    end
  end

  def working?
    @pool_mutex.synchronize do
      return !(@pool.size == 0)
    end
    #@executor.isTerminated
  end

  def dispatch(the_lambda, tag, job_code, jle)
    #@executor.submit do
    #  begin
    #    $logger.info("Thread pool has submitted  " + tag)
    #    the_lambda.call(job_code,jle)
    #  rescue =>e
    #    exception(self, e, *[tag,job_code,jle])
    #  end
    #end
    Thread.new do
      Thread.current[:job_code] = job_code
      # Wait for space in the pool.
      @pool_mutex.synchronize do
        while @pool.size >= @max_size
          $logger.info("Pool is full; waiting to run #{[the_lambda,tag,job_code,jle].join(',')}...")
          # Sleep until some other thread calls @pool_cv.signal.
          @pool_cv.wait(@pool_mutex)
        end
      end
      @pool_mutex.synchronize do
        @pool << Thread.current
      end

      begin
        $logger.info("Thread pool is starting to execute " + tag)
        the_lambda.call(job_code,jle)

      rescue => e
        exception(self, e, *[tag,job_code,jle])
      ensure
        @pool_mutex.synchronize do
          # Remove the thread from the pool.
          @pool.delete(Thread.current)
          # Signal the next waiting thread that there's a space in the pool.
          @pool_cv.signal
        end
      end
    end
  end

  def shutdown
    @pool_mutex.synchronize { @pool_cv.wait(@pool_mutex) until @pool.empty? }
    @job_log_cleaner_running = false
    #@executor.shutdown
  end

  def exception(thread, exception, *original_args)
    # Subclass this method to handle an exception within a thread.
    $logger.error("Exception in thread #{thread}: #{exception}")
    $logger.error(exception.backtrace.join("\n"))
  end
end