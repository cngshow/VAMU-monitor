set RUNNER_TASK=true
java -server -XX:MaxPermSize=256M -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:+HeapDumpOnOutOfMemoryError -Xmx512m -Xms256m -jar %JRUBY_COMPLETE_JAR% ./script/rails console %1
