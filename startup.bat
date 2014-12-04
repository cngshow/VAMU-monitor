echo %1 > .\log\rails_port.txt
%JAVA_HOME%\jre\bin\java  -server -XX:MaxPermSize=512M -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:+HeapDumpOnOutOfMemoryError -Xmx512m -Xms256m  -jar %JRUBY_COMPLETE_JAR% ./gem_home/bin/trinidad
rem C:\languages\jruby-1.7.10\bin\jruby script/rails server trinidad -p %1 -e %2
rem C:\languages\jruby-1.7.10\bin\jruby.exe --1.9 --server -J-XX:MaxPermSize=512m -J-XX:+UseConcMarkSweepGC -e $stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift) ./bin/rails server -b 127.0.0.1 -p 3000 -e development trinidad
rem -javaagent:C:\utilities\plumbr\plumbr.jar