require 'job_engine'

class JobController < ApplicationController
  #ssl_required :credentials


  def stop_engine
    start_engine(false)
  end

  def start_engine(start_it = true)
      JobEngine.instance().start! if start_it
      JobEngine.instance().stop! unless start_it
    redirect_to job_metadatas_list_path
    return # do I need this?  Check debugger one day
  end
end
