#!/u01/dev/ruby_1.8.7/bin/ruby
require 'java'
module ShamuExternal

  java_import 'java.lang.Thread' do |pkg, cls|
    'JThread'
  end

  class JavaRunner

    def self.get_lambda
      lamb = lambda do |arguments|
        puts "Part Java!"
        begin
          java_classpath = arguments.shift
          java_class = arguments.shift #java_class = "gov.va.shamu.ExampleReport"
          java_import 'java.net.URL'
          java_import 'java.io.File'
          java_import 'java.lang.String'
          java_classpath = java_classpath.split(',').map { |path| File.new(path).toURL }
          my_jar_urls = java_classpath.to_java(URL)
          url_clazz_loader =  JThread.currentThread.getContextClassLoader
          url_clazz_loader.addURL(my_jar_urls)
          clazz = url_clazz_loader.loadClass(java_class)
          instance = clazz.newInstance
          result = instance.doWork(arguments.to_java(String))
          return result.to_java
        rescue => ex
          return "Sorry run failed! " + ex.backtrace.join("\n").to_s
        ensure
          begin
            #not currently needed...
          rescue => ex
            puts ("Error in job's ensure block! " + ex.to_s)
          end
        end
      end
      lamb
    end
  end
end
ShamuExternal::JavaRunner.get_lambda.call(ARGV)