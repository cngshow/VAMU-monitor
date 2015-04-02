module ScriptingContainerHelper

  require 'java'
  require './lib/jars/child-first.jar'
  require 'thread'
  java_import 'gov.va.shamu.classloaders.ChildFirstURLClassLoader' do |pkg, cls|
    'JChildFirstURLClassLoader'
  end
  java_import 'java.net.URL' do |pkg, cls|
    'JURL'
  end
  java_import 'java.io.File' do |pkg, cls|
    'JFile'
  end
  java_import 'java.lang.Thread' do |pkg, cls|
    'JThread'
  end

  java_import 'java.util.HashMap' do |pkg, cls|
    'JHashMap'
  end

  $SCRIPTING_CONTAINER_CLASSLOADERS={}
  @@container_mutex = Mutex.new

  #returns a scripting container in its own class loader
  #the class loader will be child first and will ensure any scripts executed cannot
  #monkey with SHAMU's memory space
  #The script returns an array where element 1 is the scripting container and element 2 is the connection
  #to be returned to the pool.
  #if this is called with inject_connection = false then this method returns just a scripting container
  #This method should only be invoked by a job thread.
  def self.get_secluded_scripting_container(class_loader_tag="VANILLA")
    @@container_mutex.synchronize do
      child_first_clazz_loader = nil
      if ($SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag].nil?)
        $logger.info("**************** Instantiating a new child first classloader for--->#{class_loader_tag}<----")
        jruby_jar = JFile.new(Rails.root.to_s + "/" + $application_properties['jruby_jar_complete']) #try me w/o the rails root.  Should work
        child_first_clazz_loader = JChildFirstURLClassLoader.new([jruby_jar.toURL].to_java(JURL), nil)
        child_first_clazz_loader.setCurrentWorkingDirectory(Rails.root.to_s)
        local_context_enum = child_first_clazz_loader.loadClass("org.jruby.embed.LocalContextScope")
        methods = local_context_enum.getDeclaredMethods
        method = nil
        methods.each do |m|
          method = m if m.getName.eql?("valueOf")
        end #only one so this is safe!
        local_context_scope_thread_safe = method.invoke(local_context_enum, "THREADSAFE")
        clazz = child_first_clazz_loader.loadClass("org.jruby.embed.ScriptingContainer")
        constructor = clazz.getConstructor([local_context_enum].to_java Java::java.lang.Class)
        container = constructor.newInstance(local_context_scope_thread_safe)
        $logger.debug("built a new container #{container.to_s}")
        container.setClassLoader(child_first_clazz_loader)
        container.setCurrentDirectory(Rails.root.to_s)
        $SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag] = [child_first_clazz_loader, local_context_scope_thread_safe, local_context_enum, clazz, constructor]
      else
        $logger.info("Reusing a child first classloader for #{class_loader_tag}")
        child_first_clazz_loader = $SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag][0]
        local_context_scope_thread_safe = $SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag][1]
        local_context_enum = $SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag][2]
        constructor = $SCRIPTING_CONTAINER_CLASSLOADERS[class_loader_tag][4]
      end
      Thread.current[:initial_context_class_loader] = JThread.currentThread.getContextClassLoader
      Thread.current[:job_class_loader] = child_first_clazz_loader
      container = constructor.newInstance(local_context_scope_thread_safe)
      container.setClassLoader(child_first_clazz_loader)
      container.setCurrentDirectory(Rails.root.to_s)
      unless $application_properties['GEM_HOME'].nil?
        environment = JHashMap.new(container.getEnvironment)
        environment.put('GEM_HOME', $application_properties['GEM_HOME'])
        container.setEnvironment(environment)
      end
      Thread.current[:scripting_container] = container
      Thread.current[:java_current_thread] = JThread.currentThread
      $logger.debug("------------returning container #{container.to_s}")
      return container
    end
  end
end
