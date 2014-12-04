#!/u01/dev/ruby_1.8.7/bin/ruby
require 'java'
module ShamuExternal

  class JavaRunner

    def self.get_lambda
      lamb = lambda do |arguments|
puts "Pure Ruby!"
        begin
          java_classpath = arguments.shift
          java_class = arguments.shift #java_class = "gov.va.shamu.ExampleReport"
          java_import 'java.lang.String'
          java_classpath = java_classpath.split(',').map { |path| (path =~ /.*jar$/) ? path : path + "/"}
          java_classpath.each  do |path|
            $CLASSPATH<<path
          end
          clazz = java_import "#{java_class}"
          instance = clazz[0].new
          result = instance.doWork(arguments.to_java(String))
          return result.to_java
        rescue => ex
          return "Sorry run failed! " + ex.to_s+ "\n" + ex.backtrace.join("\n").to_s
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
